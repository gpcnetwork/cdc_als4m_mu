select * from PAT_TABLE1;
select * from ALS_CASE_TABLE1;
select * from DM_TABLE1;
select * from GLP1_EVENT_LONG;

CREATE OR REPLACE TABLE PAT_YEAR_ALL AS
    WITH RECURSIVE pat_year_expansion AS 
    (
        SELECT patid, 
               index_year AS year, 
               censor_year
        FROM PAT_TABLE1
        where partd_ind = 1 or ehr_ind = 1

        UNION ALL

        SELECT patid,
               year + 1,
               censor_year
        FROM pat_year_expansion
        WHERE year < censor_year
    )
    select patid, year 
    from pat_year_expansion
    where year between 2011 and 2020
    order by patid, year
;

CREATE OR REPLACE TABLE EHR_YEAR_ALL AS
    WITH RECURSIVE pat_year_expansion AS 
    (
        SELECT patid, 
               year(ehr_start_date) AS year, 
               year(ehr_end_date) as censor_year
        FROM PAT_TABLE1
        where ehr_ind = 1

        UNION ALL

        SELECT patid,
               year + 1,
               censor_year
        FROM pat_year_expansion
        WHERE year < censor_year
    )
    select patid, year 
    from pat_year_expansion
    where year between 2011 and 2020
    order by patid, year
;

CREATE OR REPLACE TABLE PARTD_YEAR_ALL AS
    WITH RECURSIVE pat_year_expansion AS 
    (
        SELECT patid, 
               year(partd_start_date) AS year, 
               year(partd_end_date) as censor_year
        FROM PAT_TABLE1
        where partd_ind = 1

        UNION ALL

        SELECT patid,
               year + 1,
               censor_year
        FROM pat_year_expansion
        WHERE year < censor_year
    )
    select patid, year 
    from pat_year_expansion
    where year between 2011 and 2020
    order by patid, year
;

CREATE OR REPLACE TABLE XWALK_YEAR_ALL AS
    WITH RECURSIVE pat_year_expansion AS 
    (
        SELECT patid, 
               index_year AS year, 
               censor_year
        FROM PAT_TABLE1
        WHERE xwalk_ind = 1 and partd_ind = 1

        UNION ALL

        SELECT patid,
               year + 1,
               censor_year
        FROM pat_year_expansion
        WHERE year < censor_year
    )
    select patid, year 
    from pat_year_expansion
    where year between 2011 and 2020
    order by patid, year
;




/* collect annual summaries - per-source*/

create or replace table patcnt_long (
    CALYR int, 
    DATA_SRC varchar(4),
    PAT_CNT_TYPE varchar(30),
    PAT_CNT int
)
;

-- denominators
insert into patcnt_long
select year, 'MIX', 'ALL', count(distinct patid)
from PAT_YEAR_ALL
group by year
union 
select 9999, 'MIX', 'ALL', count(distinct patid)
from PAT_YEAR_ALL
union 
select year, 'MIX', 'XWALK', count(distinct patid)
from XWALK_YEAR_ALL
group by year
union 
select 9999, 'MIX', 'XWALK', count(distinct patid)
from XWALK_YEAR_ALL
union
select year, 'EHR', 'ALL', count(distinct patid) 
from EHR_YEAR_ALL
group by year
union 
select 9999, 'EHR', 'ALL', count(distinct patid)
from EHR_YEAR_ALL
union 
select year, 'CMS', 'ALL', count(distinct patid)
from PARTD_YEAR_ALL
group by year
union 
select 9999, 'CMS', 'ALL', count(distinct patid)
from PARTD_YEAR_ALL
;

-- DM, non-DM, T1DM, T2DM
insert into patcnt_long
select a.year, 'MIX', 'DM', count(distinct a.patid)
from PAT_YEAR_ALL a 
where exists (select 1 from DM_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year)
group by a.year
union 
select 9999, 'MIX', 'DM',  count(distinct a.patid)
from PAT_YEAR_ALL a 
where exists (select 1 from DM_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year)
union
select a.year, 'MIX', 'T2DM', count(distinct a.patid)
from PAT_YEAR_ALL a 
where exists (select 1 from DM_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year and b.t1dm_ind = 0)
group by a.year
union 
select 9999, 'MIX', 'T2DM', count(distinct a.patid) 
from PAT_YEAR_ALL a 
where exists (select 1 from DM_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year and b.t1dm_ind = 0)
union 
select a.year, 'MIX', 'T1DM', count(distinct a.patid) 
from PAT_YEAR_ALL a 
where exists (select 1 from DM_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year and b.t1dm_ind = 1)
group by a.year
union 
select 9999, 'MIX', 'T1DM', count(distinct a.patid) 
from PAT_YEAR_ALL a 
where exists (select 1 from DM_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year and b.t1dm_ind = 1)
union 
select a.year, 'EHR','DM', count(distinct a.patid) 
from EHR_YEAR_ALL a 
where exists (select 1 from DM_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year)
group by a.year
union 
select 9999, 'EHR','DM', count(distinct a.patid)
from EHR_YEAR_ALL a 
where exists (select 1 from DM_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year)
union
select a.year, 'EHR', 'T2DM', count(distinct a.patid)
from EHR_YEAR_ALL a 
where exists (select 1 from DM_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year and b.t1dm_ind = 0)
group by a.year
union 
select 9999, 'EHR', 'T2DM', count(distinct a.patid) 
from EHR_YEAR_ALL a 
where exists (select 1 from DM_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year and b.t1dm_ind = 0)
union 
select a.year, 'EHR', 'T1DM', count(distinct a.patid) 
from EHR_YEAR_ALL a 
where exists (select 1 from DM_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year and b.t1dm_ind = 1)
group by a.year
union 
select 9999, 'EHR', 'T1DM', count(distinct a.patid) 
from EHR_YEAR_ALL a 
where exists (select 1 from DM_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year and b.t1dm_ind = 1)
union
select a.year, 'CMS', 'DM', count(distinct a.patid) as pat_cnt 
from PARTD_YEAR_ALL a 
where exists (select 1 from DM_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year)
group by a.year
union 
select 9999, 'CMS', 'DM', count(distinct a.patid) as pat_cnt 
from PARTD_YEAR_ALL a 
where exists (select 1 from DM_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year)
union
select a.year, 'CMS', 'T2DM', count(distinct a.patid)
from PARTD_YEAR_ALL a 
where exists (select 1 from DM_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year and b.t1dm_ind = 0)
group by a.year
union 
select 9999, 'CMS', 'T2DM', count(distinct a.patid) 
from PARTD_YEAR_ALL a 
where exists (select 1 from DM_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year and b.t1dm_ind = 0)
union 
select a.year, 'CMS', 'T1DM', count(distinct a.patid) 
from PARTD_YEAR_ALL a 
where exists (select 1 from DM_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year and b.t1dm_ind = 1)
group by a.year
union 
select 9999, 'CMS', 'T1DM', count(distinct a.patid) 
from PARTD_YEAR_ALL a 
where exists (select 1 from DM_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year and b.t1dm_ind = 1)
;


-- ALS, new ALS
insert into patcnt_long
select a.year, 'MIX', 'ALS', count(distinct a.patid)
from PAT_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year)
group by a.year
union 
select 9999, 'MIX', 'ALS', count(distinct a.patid)
from PAT_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year)
union 
select a.year, 'MIX', 'newALS', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year)
group by a.year
union 
select 9999, 'MIX', 'newALS', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year)
union
select a.year, 'EHR', 'ALS', count(distinct a.patid)
from EHR_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year)
group by a.year
union 
select 9999, 'EHR', 'ALS', count(distinct a.patid)
from EHR_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year)
union
select a.year, 'EHR', 'newALS', count(distinct a.patid) as pat_cnt 
from EHR_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year)
group by a.year
union 
select 9999, 'EHR', 'newALS', count(distinct a.patid) as pat_cnt 
from EHR_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year)
union
select a.year, 'CMS', 'ALS', count(distinct a.patid)
from PARTD_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year)
group by a.year
union 
select 9999, 'CMS', 'ALS', count(distinct a.patid)
from PARTD_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year)
union
select a.year, 'CMS', 'newALS', count(distinct a.patid) as pat_cnt 
from PARTD_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year)
group by a.year
union 
select 9999, 'CMS', 'newALS', count(distinct a.patid) as pat_cnt 
from PARTD_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year)
;

-- ALS+DM, ALS+T2DM, ALS+T1DM, newALS+DM, newALS+T2DM, newALS+T1DM
insert into patcnt_long
select a.year, 'MIX','ALS_DM', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
group by a.year
union 
select 9999, 'MIX','ALS_DM', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
union
select a.year, 'MIX','ALS_T2DM', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 0)
group by a.year
union 
select 9999, 'MIX','ALS_T2DM', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 0)
union 
select a.year, 'MIX','ALS_T1DM', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 1)
group by a.year
union 
select 9999, 'MIX','ALS_T1DM', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 1)
union
select a.year, 'EHR', 'ALS_DM', count(distinct a.patid) as pat_cnt 
from EHR_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_EHR d where a.patid = d.patid and year(d.index_date)<=a.year)
group by a.year
union 
select 9999, 'EHR', 'ALS_DM', count(distinct a.patid) as pat_cnt 
from EHR_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_EHR d where a.patid = d.patid and year(d.index_date)<=a.year)
union
select a.year, 'EHR','ALS_T2DM', count(distinct a.patid) as pat_cnt 
from EHR_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_EHR d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 0)
group by a.year
union 
select 9999, 'EHR','ALS_T2DM', count(distinct a.patid) as pat_cnt 
from EHR_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_EHR d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 0)
union 
select a.year, 'EHR','ALS_T1DM', count(distinct a.patid) as pat_cnt 
from EHR_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_EHR d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 1)
group by a.year
union 
select 9999, 'EHR','ALS_T1DM', count(distinct a.patid) as pat_cnt 
from EHR_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_EHR d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 1)
union
select a.year, 'CMS', 'ALS_DM', count(distinct a.patid) as pat_cnt 
from PARTD_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_CMS d where a.patid = d.patid and year(d.index_date)<=a.year)
group by a.year
union 
select 9999, 'CMS', 'ALS_DM', count(distinct a.patid) as pat_cnt 
from PARTD_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_CMS d where a.patid = d.patid and year(d.index_date)<=a.year)
union
select a.year, 'CMS','ALS_T2DM', count(distinct a.patid) as pat_cnt 
from PARTD_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_CMS d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 0)
group by a.year
union 
select 9999, 'CMS','ALS_T2DM', count(distinct a.patid) as pat_cnt 
from PARTD_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_CMS d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 0)
union 
select a.year, 'CMS','ALS_T1DM', count(distinct a.patid) as pat_cnt 
from PARTD_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_CMS d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 1)
group by a.year
union 
select 9999, 'CMS','ALS_T1DM', count(distinct a.patid) as pat_cnt 
from PARTD_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_CMS d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 1)
union
select a.year, 'MIX', 'newALS_DM', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
group by a.year
union 
select 9999, 'MIX', 'newALS_DM', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
union
select a.year, 'MIX','newALS_T2DM', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 0)
group by a.year
union 
select 9999, 'MIX','newALS_T2DM', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 0)
union 
select a.year, 'MIX','newALS_T1DM', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 1)
group by a.year
union 
select 9999, 'MIX','newALS_T1DM', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1 b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 1)
union
select a.year, 'EHR', 'newALS_DM', count(distinct a.patid) as pat_cnt 
from EHR_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_EHR d where a.patid = d.patid and year(d.index_date)<=a.year)
group by a.year
union 
select 9999, 'EHR', 'newALS_DM', count(distinct a.patid) as pat_cnt 
from EHR_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_EHR d where a.patid = d.patid and year(d.index_date)<=a.year)
union
select a.year, 'EHR','newALS_T2DM', count(distinct a.patid) as pat_cnt 
from EHR_YEAR_ALL a 
where exists (select 1 from ALS_CASE_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_EHR d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 0)
group by a.year
union 
select 9999, 'EHR','newALS_T2DM', count(distinct a.patid) as pat_cnt 
from EHR_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_EHR d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 0)
union 
select a.year, 'EHR','newALS_T1DM', count(distinct a.patid) as pat_cnt 
from EHR_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_EHR d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 1)
group by a.year
union 
select 9999, 'EHR','newALS_T1DM', count(distinct a.patid) as pat_cnt 
from EHR_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1_EHR b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_EHR d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 1)
union
select a.year, 'CMS', 'newALS_DM', count(distinct a.patid) as pat_cnt 
from PARTD_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_CMS d where a.patid = d.patid and year(d.index_date)<=a.year)
group by a.year
union 
select 9999, 'CMS', 'newALS_DM', count(distinct a.patid) as pat_cnt 
from PARTD_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_CMS d where a.patid = d.patid and year(d.index_date)<=a.year)
union
select a.year, 'CMS','newALS_T2DM', count(distinct a.patid) as pat_cnt 
from PARTD_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_CMS d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 0)
group by a.year
union 
select 9999, 'CMS','newALS_T2DM', count(distinct a.patid) as pat_cnt 
from PARTD_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_CMS d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 0)
union 
select a.year, 'CMS','newALS_T1DM', count(distinct a.patid) as pat_cnt 
from PARTD_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_CMS d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 1)
group by a.year
union 
select 9999, 'CMS','newALS_T1DM', count(distinct a.patid) as pat_cnt 
from PARTD_YEAR_ALL a 
where exists (select 1 from ALS_INC_CASE_TABLE1_CMS b where a.patid = b.patid and year(b.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1_CMS d where a.patid = d.patid and year(d.index_date)<=a.year and d.t1dm_ind = 1)
;

-- DM + GLP1
insert into patcnt_long
select a.year, 'MIX', 'DM_GLP1', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid and b.glp1_start_date is not null)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
group by a.year
union 
select 9999, 'MIX', 'DM_GLP1', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid and b.glp1_start_date is not null)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
union 
select a.year, 'MIX', 'DM_DPP4', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid and b.dpp4_start_date is not null)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
group by a.year
union 
select 9999, 'MIX', 'DM_DPP4', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid and b.dpp4_start_date is not null)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
union 
select a.year, 'MIX', 'DM_GLP1_DPP4', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
group by a.year
union 
select 9999, 'MIX', 'DM_GLP1_DPP4', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
union 
--
select a.year, 'EHR', 'DM_GLP1', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid and b.glp1_start_date is not null)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
group by a.year
union 
select 9999, 'MIX', 'DM_GLP1', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid and b.glp1_start_date is not null)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
union 
select a.year, 'MIX', 'DM_DPP4', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid and b.dpp4_start_date is not null)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
group by a.year
union 
select 9999, 'MIX', 'DM_DPP4', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid and b.dpp4_start_date is not null)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
union 
select a.year, 'MIX', 'DM_GLP1_DPP4', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
group by a.year
union 
select 9999, 'MIX', 'DM_GLP1_DPP4', count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
union 
;

select * from patcnt_long limit 5;

/* standardized population: census */
select * from REF_ACS_SEXBYAGE;

create or replace table adj_wt (
    CALYR int, 
    DATA_SRC varchar(4),
    WT_TYPE varchar(10),
    WT number
)
;

insert into adj_wt (calyr, data_src, wt_type, wt)
with denom_cte as (
    select  distinct
            a.patid, 
            a.year, 
            c.sex, 
            a.year - year(c.birth_date) as age,
            round(r.wt,6) as wt
        from PAT_YEAR_ALL a 
        join PAT_TABLE1 c on a.patid = c.patid
        join REF_ACS_SEXBYAGE r on a.year = r.yr and c.sex = r.sex and a.year - year(c.birth_date) between r.age_lb and r.age_ub
), num_cte as (
    select a.*
    from denom_cte a 
    join ALS_CASE_TABLE1 c on a.patid = c.patid    
), num_yr_cte as (
    select  year, 
            round(sum(wt)) as num,
            count(distinct patid)
    from num_cte 
    group by year
    union 
    select 9999,
           round(sum(wt)) as num,
           count(distinct patid)
    from num_cte 
    order by year
), denom_yr_cte as (
    select  year,
            round(sum(wt)) as denom
    from denom_cte 
    group by year
    union 
    select 9999,
           round(sum(wt)) as denom
    from denom_cte 
)
select n.year,
       'MIX',
       ''
       CAST(n.num/d.denom AS NUMBER(20,15)) as prev_adj
from num_yr_cte n
join denom_yr_cte d 
on n.year = d.year 
order by year
;


create or replace table 
select * 
from patcnt_long
pivot 
(
    max(pat_cnt) for 
    pat_cnt_type in (any order by pat_cnt_type)
)
order by calyr
;










/* table 2 - DM+GLP1  */

order by year
;

/* table 2 - DM+DPP4  */

order by year
;

/* table 2 - DM+either  */

order by year
;

/* table 2 - ALS+GLP1  */
select a.year, count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid and b.glp1_start_date is not null)
    and exists (select 1 from ALS_CASE_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
group by a.year
union 
select 9999, count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid and b.glp1_start_date is not null)
    and exists (select 1 from ALS_CASE_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
order by year
;

/* table 2 - ALS+DPP4  */
select a.year, count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid and b.dpp4_start_date is not null)
    and exists (select 1 from ALS_CASE_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
group by a.year
union 
select 9999, count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid and b.dpp4_start_date is not null)
    and exists (select 1 from ALS_CASE_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
order by year
;

/* table 2 - ALS+either  */
select a.year, count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid)
    and exists (select 1 from ALS_CASE_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
group by a.year
union 
select 9999, count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid)
    and exists (select 1 from ALS_CASE_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
order by year
;


/* table 2 - DM+ALS+GLP1  */
select a.year, count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid and b.glp1_start_date is not null)
    and exists (select 1 from ALS_CASE_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
group by a.year
union 
select 9999, count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid and b.glp1_start_date is not null)
    and exists (select 1 from ALS_CASE_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
order by year
;

/* table 2 - DM+ALS+DPP4  */
select a.year, count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid and b.dpp4_start_date is not null)
    and exists (select 1 from ALS_CASE_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
group by a.year
union 
select 9999, count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid and b.dpp4_start_date is not null)
    and exists (select 1 from ALS_CASE_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
order by year
;

/* table 2 - T2DM+ALS+either  */
select a.year, count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid)
    and exists (select 1 from ALS_CASE_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
group by a.year
union 
select 9999, count(distinct a.patid) as pat_cnt 
from PAT_YEAR_ALL a 
where exists (select 1 from GLP1_DPP4_TABLE1 b where a.patid = b.patid)
    and exists (select 1 from ALS_CASE_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
    and exists (select 1 from DM_TABLE1 d where a.patid = d.patid and year(d.index_date)<=a.year)
order by year
;

/* standardized population: DM */
select * from PAT_YEAR_ALL limit 5;
create or replace temporary table DM_SEX_AGE_DIST as 
with cte as (
    select  distinct
            a.patid, 
            a.year, 
            b.sex, 
            a.year - year(b.birth_date) as age
        from PAT_YEAR_ALL a 
        join DM_TABLE1 b 
        on a.patid = b.patid
        where year(b.index_date) <= a.year and 
              a.year - year(b.birth_date) >= 0
), denom_yr_cte as (
    select year, count(distinct patid) as denom
    from cte 
    group by year
), num_yr_cte as (
    select year, sex, age, count(distinct patid) as num
    from cte 
    group by year, sex, age
), denom_cte as (
    select count(distinct patid) as denom
    from cte 
    where year = 2016
), num_cte as (
    select sex, age, count(distinct patid) as num
    from cte 
    where year = 2016
    group by sex, age
)
select d.year,
       d.denom,
       n.sex,
       n.age,
       n.num,
       round(n.num/d.denom, 6) as wt 
from denom_yr_cte d
join num_yr_cte n 
on d.year = n.year
union 
select 9999,
       d.denom,
       n.sex,
       n.age,
       n.num,
       round(n.num/d.denom, 6) as wt 
from num_cte n 
cross join denom_cte d 
;

with cte as (
    select  distinct
            a.patid, 
            a.year, 
            b.sex, 
            a.year - year(b.birth_date) as age
        from PAT_YEAR_ALL a 
        join DM_TABLE1 b on a.patid = b.patid
        join ALS_CASE_TABLE1 c on a.patid = c.patid
        where year(c.index_date) <= a.year and year(b.index_date) <= a.year
), denom_yr_cte as (
    select  a.year, 
            c.sex, 
            a.year - year(c.birth_date) as age, 
            count(distinct a.patid) as denom
    from PAT_YEAR_ALL a 
    join ALS_CASE_TABLE1 c on a.patid = c.patid
    where year(c.index_date) <= a.year
    group by a.year, c.sex, a.year - year(c.birth_date)
), rewt_yr_cte as (
    select  a.year, 
            a.sex, 
            a.age, 
            (count(distinct a.patid)/d.denom) * b.wt as prev_adj
    from cte a 
    join denom_yr_cte d
    on a.year = d.year and a.sex = d.sex and a.age = d.age
    join DM_SEX_AGE_DIST b 
    on a.year = b.year and a.sex = b.sex and a.age = b.age
    group by a.year, a.sex, a.age, d.denom, b.wt
), denom_cte as (
    select  c.sex, 
            a.year - year(c.birth_date) as age, 
            count(distinct a.patid) as denom
    from PAT_YEAR_ALL a 
    join ALS_CASE_TABLE1 c on a.patid = c.patid
    where year(c.index_date) <= a.year
    group by c.sex, a.year - year(c.birth_date)
), rewt_cte as (
    select  a.sex, 
            a.age, 
            (count(distinct a.patid)/d.denom) * b.wt as prev_adj
    from cte a 
    join denom_cte d
    on a.sex = d.sex and a.age = d.age
    join DM_SEX_AGE_DIST b 
    on a.sex = b.sex and a.age = b.age and b.year = 9999
    group by a.sex, a.age, d.denom, b.wt
)
select year, 
       sum(prev_adj) as prev_adj
from rewt_yr_cte
group by year 
union 
select 9999, 
       sum(prev_adj) as prev_adj
from rewt_cte
order by year
;

/* table 3 - T2DM+ALS : GLP1-DPP4*/
create or replace table T2DM_ALS_BASE as 
select a.patid,
       a.age_at_index,
       a.sex,
       a.race,
       a.hispanic,
       a.cphety,
       p.censor_date,
       p.death_ind,
       case when datediff(day,a.index_date,p.censor_date)/365.25 >= 1 then 1 else 0 end as surv1yr,
       case when datediff(day,a.index_date,p.censor_date)/365.25 >= 2 then 1 else 0 end as surv2yr,
       case when datediff(day,a.index_date,p.censor_date)/365.25 >= 3 then 1 else 0 end as surv3yr,
       case when datediff(day,a.index_date,p.censor_date)/365.25 >= 4 then 1 else 0 end as surv4yr,
       case when datediff(day,a.index_date,p.censor_date)/365.25 >= 5 then 1 else 0 end as surv5yr,
       case when coalesce(d.GLP1_IND,d.DPP4_IND) = 1 then 1 else 0 end as GLP1_DPP4_IND,
       case when d.GLP1_START_DATE<a.index_date and d.DPP4_START_DATE<a.index_date then 'both'
            when d.GLP1_START_DATE<a.index_date then 'glp1'
            when d.DPP4_START_DATE<a.index_date then 'dpp4'
       end as glp1_dpp4_prior
from ALS_CASE_TABLE1 a 
join PAT_TABLE1 p on a.patid = p.patid
join DM_TABLE1 dm on a.patid = dm.patid
left join GLP1_DPP4_TABLE1 d on a.patid = d.patid
where a.age_at_index <= 100
;

select * from T2DM_ALS_BASE order by censor_date desc;

select GLP1_DPP4_IND, round(avg(age_at_index)), round(stddev(age_at_index),1)
from T2DM_ALS_BASE
group by GLP1_DPP4_IND
;

select * from T2DM_ALS_BASE order by age_at_index desc;

with denom_N as (
    select GLP1_DPP4_IND, count(distinct patid) as denom
    from T2DM_ALS_BASE
    group by GLP1_DPP4_IND
)
select a.GLP1_DPP4_IND, a.sex, count(distinct a.patid), round(count(distinct a.patid)/n.denom*100,1)
from T2DM_ALS_BASE a
join denom_N n on a.GLP1_DPP4_IND = n.GLP1_DPP4_IND
group by a.GLP1_DPP4_IND, a.sex, n.denom
order by a.GLP1_DPP4_IND, a.sex
;

with denom_N as (
    select GLP1_DPP4_IND, count(distinct patid) as denom
    from T2DM_ALS_BASE
    group by GLP1_DPP4_IND
)
select a.GLP1_DPP4_IND, a.race, count(distinct a.patid), round(count(distinct a.patid)/n.denom*100,1)
from T2DM_ALS_BASE a
join denom_N n on a.GLP1_DPP4_IND = n.GLP1_DPP4_IND
group by a.GLP1_DPP4_IND, a.race, n.denom
order by a.GLP1_DPP4_IND, a.race
;

with denom_N as (
    select GLP1_DPP4_IND, count(distinct patid) as denom
    from T2DM_ALS_BASE
    group by GLP1_DPP4_IND
)
select a.GLP1_DPP4_IND, a.hispanic, count(distinct a.patid), round(count(distinct a.patid)/n.denom*100,1)
from T2DM_ALS_BASE a
join denom_N n on a.GLP1_DPP4_IND = n.GLP1_DPP4_IND
group by a.GLP1_DPP4_IND, a.hispanic, n.denom
order by a.GLP1_DPP4_IND, a.hispanic
;

with denom_N as (
    select GLP1_DPP4_IND, count(distinct patid) as denom
    from T2DM_ALS_BASE
    group by GLP1_DPP4_IND
)
select a.GLP1_DPP4_IND, a.glp1_dpp4_prior, count(distinct a.patid), round(count(distinct a.patid)/n.denom*100,1)
from T2DM_ALS_BASE a
join denom_N n on a.GLP1_DPP4_IND = n.GLP1_DPP4_IND
group by a.GLP1_DPP4_IND, a.glp1_dpp4_prior, n.denom
order by a.GLP1_DPP4_IND, a.glp1_dpp4_prior
;


with denom_N as (
    select GLP1_DPP4_IND, count(distinct patid) as denom
    from T2DM_ALS_BASE
    group by GLP1_DPP4_IND
)
select a.GLP1_DPP4_IND, a.surv1yr, count(distinct a.patid), round(count(distinct a.patid)/n.denom*100,1)
from T2DM_ALS_BASE a
join denom_N n on a.GLP1_DPP4_IND = n.GLP1_DPP4_IND
group by a.GLP1_DPP4_IND, a.surv1yr, n.denom
order by a.GLP1_DPP4_IND, a.surv1yr
;


with denom_N as (
    select GLP1_DPP4_IND, count(distinct patid) as denom
    from T2DM_ALS_BASE
    group by GLP1_DPP4_IND
)
select a.GLP1_DPP4_IND, a.surv2yr, count(distinct a.patid), round(count(distinct a.patid)/n.denom*100,1)
from T2DM_ALS_BASE a
join denom_N n on a.GLP1_DPP4_IND = n.GLP1_DPP4_IND
group by a.GLP1_DPP4_IND, a.surv2yr, n.denom
order by a.GLP1_DPP4_IND, a.surv2yr
;


with denom_N as (
    select GLP1_DPP4_IND, count(distinct patid) as denom
    from T2DM_ALS_BASE
    group by GLP1_DPP4_IND
)
select a.GLP1_DPP4_IND, a.surv3yr, count(distinct a.patid), round(count(distinct a.patid)/n.denom*100,1)
from T2DM_ALS_BASE a
join denom_N n on a.GLP1_DPP4_IND = n.GLP1_DPP4_IND
group by a.GLP1_DPP4_IND, a.surv3yr, n.denom
order by a.GLP1_DPP4_IND, a.surv3yr
;


with denom_N as (
    select GLP1_DPP4_IND, count(distinct patid) as denom
    from T2DM_ALS_BASE
    group by GLP1_DPP4_IND
)
select a.GLP1_DPP4_IND, a.surv4yr, count(distinct a.patid), round(count(distinct a.patid)/n.denom*100,1)
from T2DM_ALS_BASE a
join denom_N n on a.GLP1_DPP4_IND = n.GLP1_DPP4_IND
group by a.GLP1_DPP4_IND, a.surv4yr, n.denom
order by a.GLP1_DPP4_IND, a.surv4yr
;

with denom_N as (
    select GLP1_DPP4_IND, count(distinct patid) as denom
    from T2DM_ALS_BASE
    group by GLP1_DPP4_IND
)
select a.GLP1_DPP4_IND, a.surv5yr, count(distinct a.patid), round(count(distinct a.patid)/n.denom*100,1)
from T2DM_ALS_BASE a
join denom_N n on a.GLP1_DPP4_IND = n.GLP1_DPP4_IND
group by a.GLP1_DPP4_IND, a.surv5yr, n.denom
order by a.GLP1_DPP4_IND, a.surv5yr
;


with denom_N as (
    select cphety, count(distinct patid) as denom
    from T2DM_ALS_BASE
    group by cphety
)
select a.cphety, a.surv3yr, 
       n.denom, count(distinct a.patid) as numer, 
       round(count(distinct a.patid)/n.denom*100,1) as prop
from T2DM_ALS_BASE a
join denom_N n on a.cphety = n.cphety
group by a.cphety, a.surv3yr, n.denom
order by a.cphety, a.surv3yr
;




/* table 3 - T2DM : GLP1-DPP4*/
create or replace table T2DM_BASE as 
select a.patid,
       a.age_at_index,
       a.sex,
       a.race,
       a.hispanic,
       p.censor_date,
       p.death_ind,
       case when datediff(day,a.index_date,p.censor_date)/365.25 >= 1 then 1 else 0 end as surv1yr,
       case when datediff(day,a.index_date,p.censor_date)/365.25 >= 2 then 1 else 0 end as surv2yr,
       case when datediff(day,a.index_date,p.censor_date)/365.25 >= 3 then 1 else 0 end as surv3yr,
       case when datediff(day,a.index_date,p.censor_date)/365.25 >= 4 then 1 else 0 end as surv4yr,
       case when datediff(day,a.index_date,p.censor_date)/365.25 >= 5 then 1 else 0 end as surv5yr,
       case when coalesce(d.GLP1_IND,d.DPP4_IND) = 1 then 1 else 0 end as GLP1_DPP4_IND,
       case when d.GLP1_START_DATE<a.index_date and d.DPP4_START_DATE<a.index_date then 'both'
            when d.GLP1_START_DATE<a.index_date then 'glp1'
            when d.DPP4_START_DATE<a.index_date then 'dpp4'
       end as glp1_dpp4_prior
from DM_TABLE1 a 
join PAT_TABLE1 p on a.patid = p.patid
left join GLP1_DPP4_TABLE1 d on a.patid = d.patid
where a.age_at_index <= 100
;

select * from T2DM_BASE order by censor_date desc;

select GLP1_DPP4_IND, round(avg(age_at_index)), round(stddev(age_at_index),1)
from T2DM_BASE
group by GLP1_DPP4_IND
;

select * from T2DM_ALS_BASE order by age_at_index desc;

with denom_N as (
    select GLP1_DPP4_IND, count(distinct patid) as denom
    from T2DM_BASE
    group by GLP1_DPP4_IND
)
select a.GLP1_DPP4_IND, a.sex, count(distinct a.patid), round(count(distinct a.patid)/n.denom*100,1)
from T2DM_BASE a
join denom_N n on a.GLP1_DPP4_IND = n.GLP1_DPP4_IND
group by a.GLP1_DPP4_IND, a.sex, n.denom
order by a.GLP1_DPP4_IND, a.sex
;

with denom_N as (
    select GLP1_DPP4_IND, count(distinct patid) as denom
    from T2DM_BASE
    group by GLP1_DPP4_IND
)
select a.GLP1_DPP4_IND, a.race, count(distinct a.patid), round(count(distinct a.patid)/n.denom*100,1)
from T2DM_BASE a
join denom_N n on a.GLP1_DPP4_IND = n.GLP1_DPP4_IND
group by a.GLP1_DPP4_IND, a.race, n.denom
order by a.GLP1_DPP4_IND, a.race
;

with denom_N as (
    select GLP1_DPP4_IND, count(distinct patid) as denom
    from T2DM_BASE
    group by GLP1_DPP4_IND
)
select a.GLP1_DPP4_IND, a.hispanic, count(distinct a.patid), round(count(distinct a.patid)/n.denom*100,1)
from T2DM_BASE a
join denom_N n on a.GLP1_DPP4_IND = n.GLP1_DPP4_IND
group by a.GLP1_DPP4_IND, a.hispanic, n.denom
order by a.GLP1_DPP4_IND, a.hispanic
;

with denom_N as (
    select GLP1_DPP4_IND, count(distinct patid) as denom
    from T2DM_BASE
    group by GLP1_DPP4_IND
)
select a.GLP1_DPP4_IND, a.glp1_dpp4_prior, count(distinct a.patid), round(count(distinct a.patid)/n.denom*100,1)
from T2DM_BASE a
join denom_N n on a.GLP1_DPP4_IND = n.GLP1_DPP4_IND
group by a.GLP1_DPP4_IND, a.glp1_dpp4_prior, n.denom
order by a.GLP1_DPP4_IND, a.glp1_dpp4_prior
;


with denom_N as (
    select GLP1_DPP4_IND, count(distinct patid) as denom
    from T2DM_BASE
    group by GLP1_DPP4_IND
)
select a.GLP1_DPP4_IND, a.surv1yr, count(distinct a.patid), round(count(distinct a.patid)/n.denom*100,1)
from T2DM_BASE a
join denom_N n on a.GLP1_DPP4_IND = n.GLP1_DPP4_IND
group by a.GLP1_DPP4_IND, a.surv1yr, n.denom
order by a.GLP1_DPP4_IND, a.surv1yr
;


with denom_N as (
    select GLP1_DPP4_IND, count(distinct patid) as denom
    from T2DM_BASE
    group by GLP1_DPP4_IND
)
select a.GLP1_DPP4_IND, a.surv2yr, count(distinct a.patid), round(count(distinct a.patid)/n.denom*100,1)
from T2DM_BASE a
join denom_N n on a.GLP1_DPP4_IND = n.GLP1_DPP4_IND
group by a.GLP1_DPP4_IND, a.surv2yr, n.denom
order by a.GLP1_DPP4_IND, a.surv2yr
;


with denom_N as (
    select GLP1_DPP4_IND, count(distinct patid) as denom
    from T2DM_BASE
    group by GLP1_DPP4_IND
)
select a.GLP1_DPP4_IND, a.surv3yr, count(distinct a.patid), round(count(distinct a.patid)/n.denom*100,1)
from T2DM_BASE a
join denom_N n on a.GLP1_DPP4_IND = n.GLP1_DPP4_IND
group by a.GLP1_DPP4_IND, a.surv3yr, n.denom
order by a.GLP1_DPP4_IND, a.surv3yr
;


with denom_N as (
    select GLP1_DPP4_IND, count(distinct patid) as denom
    from T2DM_BASE
    group by GLP1_DPP4_IND
)
select a.GLP1_DPP4_IND, a.surv4yr, count(distinct a.patid), round(count(distinct a.patid)/n.denom*100,1)
from T2DM_BASE a
join denom_N n on a.GLP1_DPP4_IND = n.GLP1_DPP4_IND
group by a.GLP1_DPP4_IND, a.surv4yr, n.denom
order by a.GLP1_DPP4_IND, a.surv4yr
;

with denom_N as (
    select GLP1_DPP4_IND, count(distinct patid) as denom
    from T2DM_BASE
    group by GLP1_DPP4_IND
)
select a.GLP1_DPP4_IND, a.surv5yr, count(distinct a.patid), round(count(distinct a.patid)/n.denom*100,1)
from T2DM_BASE a
join denom_N n on a.GLP1_DPP4_IND = n.GLP1_DPP4_IND
group by a.GLP1_DPP4_IND, a.surv5yr, n.denom
order by a.GLP1_DPP4_IND, a.surv5yr
;