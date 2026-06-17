select * from T2DM_TABLE1 limit 5;
select * from GLP1_DPP4_TABLE1 limit 5;

create or replace table T2DM_REF as 
select patid, race, hispanic, sex, 
       case when age_at_index between 10 and 13 then '10-13'
            when age_at_index between 14 and 17 then '14-17'
            when age_at_index between 18 and 44 then '18-44'
            when age_at_index between 45 and 64 then '45-64'
            when age_at_index >= 65 then '65+'
            else 'Unknown' end as age_group,
       case when age_at_index <= 17 then 1 else 0 end as adolescent_ind,
       index_src as site
from T2DM_TABLE1
where age_at_index >= 17 and index_date<= '2025-12-31' and index_src <> 'CMS'
;

select site, count(distinct patid) as num_patients
from T2DM_REF
group by site
order by count(distinct patid) desc
;
-- WASHU
-- IHC
-- UTSW
-- ALLINA
-- UTHOUSTON
-- MCW
       

select count(distinct patid) as num_patients
from T2DM_REF
where adolescent_ind = 1 and
  site in ('WASHU','IHC','UTSW','ALLINA','UTHOUSTON','MCW')
;

select age_group, count(distinct patid) as num_patients
from T2DM_REF
where adolescent_ind = 1 and
  site in ('WASHU','IHC','UTSW','ALLINA','UTHOUSTON','MCW')
group by age_group
order by age_group
;

select sex, count(distinct patid) as num_patients
from T2DM_REF
where adolescent_ind = 1 and
  site in ('WASHU','IHC','UTSW','ALLINA','UTHOUSTON','MCW')
group by sex
order by sex
;

select race, count(distinct patid) as num_patients
from T2DM_REF
where adolescent_ind = 1 and
  site in ('WASHU','IHC','UTSW','ALLINA','UTHOUSTON','MCW')
group by race
order by race
;

select hispanic, count(distinct patid) as num_patients
from T2DM_REF
where adolescent_ind = 1 and
  site in ('WASHU','IHC','UTSW','ALLINA','UTHOUSTON','MCW')
group by hispanic
order by hispanic
;

-- with GLP1
select count(distinct patid) as num_patients
from T2DM_REF
where adolescent_ind = 1 and 
  exists (select 1 from GLP1_DPP4_TABLE1 b where T2DM_REF.patid = b.patid and b.glp1_ind = 1) and
  site in ('WASHU','IHC','UTSW','ALLINA','UTHOUSTON','MCW')
;

select age_group, count(distinct patid) as num_patients
from T2DM_REF
where adolescent_ind = 1 and
  exists (select 1 from GLP1_DPP4_TABLE1 b where T2DM_REF.patid = b.patid and b.glp1_ind = 1) and
  site in ('WASHU','IHC','UTSW','ALLINA','UTHOUSTON','MCW')
group by age_group
order by age_group
;

select sex, count(distinct patid) as num_patients
from T2DM_REF
where adolescent_ind = 1 and
  exists (select 1 from GLP1_DPP4_TABLE1 b where T2DM_REF.patid = b.patid and b.glp1_ind = 1) and
  site in ('WASHU','IHC','UTSW','ALLINA','UTHOUSTON','MCW')
group by sex
order by sex
;

select race, count(distinct patid) as num_patients
from T2DM_REF
where adolescent_ind = 1 and
  exists (select 1 from GLP1_DPP4_TABLE1 b where T2DM_REF.patid = b.patid and b.glp1_ind = 1) and
  site in ('WASHU','IHC','UTSW','ALLINA','UTHOUSTON','MCW')
group by race
order by race
;

select hispanic, count(distinct patid) as num_patients
from T2DM_REF
where adolescent_ind = 1 and
  exists (select 1 from GLP1_DPP4_TABLE1 b where T2DM_REF.patid = b.patid and b.glp1_ind = 1) and
  site in ('WASHU','IHC','UTSW','ALLINA','UTHOUSTON','MCW')
group by hispanic
order by hispanic
;