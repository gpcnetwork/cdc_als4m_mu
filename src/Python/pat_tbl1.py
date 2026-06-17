import os
from snowflake.snowpark import Session
from snowflake.snowpark.functions import (
    col,
    coalesce,
    current_date,
    datediff,
    floor,
    lit,
    max as s_max,
    min as s_min,
    round as s_round,
    row_number,
    when,
    year,
    concat,
)
from snowflake.snowpark.window import Window
from config import env, conn

def _site_cdm(site: str) -> str:
    return "CMS_PCORNET_CDM" if site == "CMS" else f"PCORNET_CDM_{site}"


def _create_pat_demo_long(session: Session) -> None:
    session.sql(
        """
        create or replace table PAT_DEMO_LONG (
            PATID varchar(50) NOT NULL,
            BIRTH_DATE date,
            INDEX_DATE date,
            INDEX_ENC_TYPE varchar(3),
            AGE_AT_INDEX integer,
            SEX varchar(3),
            RACE varchar(6),
            HISPANIC varchar(20),
            INDEX_SRC varchar(20),
            CENSOR_DATE date,
            DEATH_IND integer,
            CMS_IND integer
        )
        """
    ).collect()


def _build_pat_demo_long_site(session: Session, site: str):
    site_cdm = _site_cdm(site)
    cms_ind = 1 if site == "CMS" else 0

    demo = session.table(f"GROUSE_DB.{site_cdm}.LDS_DEMOGRAPHIC")
    enc = session.table(f"GROUSE_DB.{site_cdm}.LDS_ENCOUNTER")
    dth = session.table(f"GROUSE_DB.{site_cdm}.LDS_DEATH")

    censor_date = s_max(
        coalesce(enc["DISCHARGE_DATE"].cast("DATE"), enc["ADMIT_DATE"].cast("DATE"),)
    ).over(Window.partition_by(enc["PATID"]))

    death_date = s_max(dth["DEATH_DATE"]).over(Window.partition_by(enc["PATID"]))

    cte = (
        demo.join(enc, demo["PATID"] == enc["PATID"])
        .join(dth, enc["PATID"] == dth["PATID"], "left")
        .filter(demo["PATID"].is_not_null())
        .filter(
            coalesce(
                enc["DISCHARGE_DATE"].cast("DATE"),
                enc["ADMIT_DATE"].cast("DATE"),
            )
            <= current_date()
        )
        .select(
            enc["PATID"].alias("PATID"),
            demo["BIRTH_DATE"].alias("BIRTH_DATE"),
            enc["ADMIT_DATE"].cast("DATE").alias("INDEX_DATE"),
            enc["ENC_TYPE"].alias("INDEX_ENC_TYPE"),
            s_round(
                datediff(
                    "day",
                    demo["BIRTH_DATE"].cast("DATE"),
                    enc["ADMIT_DATE"].cast("DATE"),
                )
                / lit(365.25)
            ).cast("INTEGER").alias("AGE_AT_INDEX"),
            when(demo["SEX"].isin(["NI", "UN", "OT"]), lit(None)).otherwise(
                demo["SEX"]
            ).alias("SEX"),
            when(demo["RACE"].isin(["NI", "UN", "07", "OT"]), lit(None)).otherwise(
                demo["RACE"]
            ).alias("RACE"),
            when(demo["HISPANIC"].isin(["NI", "UN", "R", "OT"]), lit(None)).otherwise(
                demo["HISPANIC"]
            ).alias("HISPANIC"),
            lit(site).alias("INDEX_SRC"),
            censor_date.alias("CENSOR_DATE"),
            death_date.alias("DEATH_DATE"),
        )
    )

    return (
        cte.select(
            col("PATID"),
            col("BIRTH_DATE"),
            col("INDEX_DATE"),
            col("INDEX_ENC_TYPE"),
            col("AGE_AT_INDEX"),
            col("SEX"),
            col("RACE"),
            col("HISPANIC"),
            col("INDEX_SRC"),
            coalesce(col("DEATH_DATE"), col("CENSOR_DATE")).alias("CENSOR_DATE"),
            when(col("DEATH_DATE").is_not_null(), lit(1)).otherwise(lit(0)).alias(
                "DEATH_IND"
            ),
            lit(cms_ind).alias("CMS_IND"),
        )
        .distinct()
    )


def build_pat_demo_long(session: Session, sites: list[str]):
    _create_pat_demo_long(session)

    for site in sites:
        _build_pat_demo_long_site(session, site).write.mode("append").save_as_table(
            "PAT_DEMO_LONG"
        )
        print(f"✅ PAT_DEMO_LONG data for site {site} appended.")

def _get_partab(session: Session):
    enr = session.table("GROUSE_DEID_DB.CMS_PCORNET_CDM.LDS_ENROLLMENT")
    return (
        enr.filter(col("ENR_BASIS") == lit("I"))
        .group_by(col("PATID"))
        .agg(
            s_min(col("ENR_START_DATE")).alias("PARTAB_START_DATE"),
            s_max(coalesce(col("ENR_END_DATE"), col("ENR_START_DATE"))).alias(
                "PARTAB_END_DATE"
            ),
            s_max(when(col("CHART") == lit("Y"), lit(1)).otherwise(lit(0))).alias(
                "XWALK_IND"
            ),
        )
    )


def _get_partd(session: Session):
    enr = session.table("GROUSE_DEID_DB.CMS_PCORNET_CDM.LDS_ENROLLMENT")
    return (
        enr.filter(col("ENR_BASIS") == lit("D"))
        .group_by(col("PATID"))
        .agg(
            s_min(col("ENR_START_DATE")).alias("PARTD_START_DATE"),
            s_max(coalesce(col("ENR_END_DATE"), col("ENR_START_DATE"))).alias(
                "PARTD_END_DATE"
            ),
        )
    )


def _get_ehr(session: Session):
    demo = session.table("PAT_DEMO_LONG")
    return (
        demo.filter(col("CMS_IND") == lit(0))
        .group_by(col("PATID"))
        .agg(
            s_min(col("INDEX_DATE")).alias("EHR_START_DATE"),
            s_max(col("INDEX_DATE")).alias("EHR_END_DATE"),
        )
    )


def _get_partc(session: Session):
    enr = session.table("GROUSE_DEID_DB.CMS_PCORNET_CDM.LDS_ENROLLMENT")
    return (
        enr.filter(col("RAW_BASIS") == lit("C"))
        .select(col("PATID"), lit(1).alias("PARTC_IND"))
        .distinct()
    )


def build_pat_table1(session: Session):
    demo = session.table("PAT_DEMO_LONG")

    cte_ord = (
        demo.select("*")
        .with_column(
            "RN",
            row_number().over(
                Window.partition_by("PATID").order_by(col("INDEX_DATE"), col("CMS_IND").desc())
            ),
        )
    )

    partab = _get_partab(session).with_column_renamed("PATID", "PARTAB_PATID")
    partd = _get_partd(session).with_column_renamed("PATID", "PARTD_PATID")
    ehr = _get_ehr(session).with_column_renamed("PATID", "EHR_PATID")
    partc = _get_partc(session).with_column_renamed("PATID", "PARTC_PATID")

    agegrp = (
        when(cte_ord["AGE_AT_INDEX"].is_null(), lit("NI"))
        .when(cte_ord["AGE_AT_INDEX"] < 19, lit("agegrp1"))
        .when(
            (cte_ord["AGE_AT_INDEX"] >= 19) & (cte_ord["AGE_AT_INDEX"] < 24),
            lit("agegrp2"),
        )
        .when(
            (cte_ord["AGE_AT_INDEX"] >= 25) & (cte_ord["AGE_AT_INDEX"] < 85),
            concat(
                lit("agegrp"),
                (floor((cte_ord["AGE_AT_INDEX"] - lit(25)) / lit(5)) + lit(3)).cast(
                    "STRING"
                ),
            ),
        )
        .otherwise(lit("agegrp15"))
    )

    race_grp = (
        when(cte_ord["RACE"] == lit("05"), lit("white"))
        .when(cte_ord["RACE"] == lit("03"), lit("black"))
        .when(cte_ord["RACE"] == lit("02"), lit("asian"))
        .when(cte_ord["RACE"] == lit("01"), lit("aian"))
        .when(cte_ord["RACE"] == lit("04"), lit("nhpi"))
        .when(cte_ord["RACE"] == lit("06"), lit("multi"))
        .when(cte_ord["RACE"] == lit("OT"), lit("other"))
        .otherwise(lit("NI"))
    )

    hispanic_grp = (
        when(cte_ord["HISPANIC"] == lit("Y"), lit("hispanic"))
        .when(cte_ord["HISPANIC"] == lit("N"), lit("non-hispanic"))
        .otherwise(lit("NI"))
    )

    pat_table1 = (
        cte_ord.filter(cte_ord["RN"] == 1)
        .join(ehr, cte_ord["PATID"] == ehr["EHR_PATID"], "left")
        .join(partab, cte_ord["PATID"] == partab["PARTAB_PATID"], "left")
        .join(partc, cte_ord["PATID"] == partc["PARTC_PATID"], "left")
        .join(partd, cte_ord["PATID"] == partd["PARTD_PATID"], "left")
        .select(
            cte_ord["PATID"].alias("PATID"),
            cte_ord["BIRTH_DATE"].alias("BIRTH_DATE"),
            cte_ord["INDEX_DATE"].alias("INDEX_DATE"),
            year(cte_ord["INDEX_DATE"]).alias("INDEX_YEAR"),
            cte_ord["AGE_AT_INDEX"].alias("AGE_AT_INDEX"),
            agegrp.alias("AGEGRP_AT_INDEX"),
            cte_ord["SEX"].alias("SEX"),
            race_grp.alias("RACE"),
            hispanic_grp.alias("HISPANIC"),
            cte_ord["INDEX_ENC_TYPE"].alias("INDEX_ENC_TYPE"),
            cte_ord["INDEX_SRC"].alias("INDEX_SRC"),
            cte_ord["CENSOR_DATE"].alias("CENSOR_DATE"),
            year(cte_ord["CENSOR_DATE"]).alias("CENSOR_YEAR"),
            cte_ord["DEATH_IND"].alias("DEATH_IND"),
            coalesce(partab["XWALK_IND"], lit(0)).alias("XWALK_IND"),
            partab["PARTAB_START_DATE"].alias("PARTAB_START_DATE"),
            partab["PARTAB_END_DATE"].alias("PARTAB_END_DATE"),
            when(partd["PARTD_START_DATE"].is_not_null(), lit(1)).otherwise(lit(0)).alias(
                "PARTD_IND"
            ),
            partd["PARTD_START_DATE"].alias("PARTD_START_DATE"),
            partd["PARTD_END_DATE"].alias("PARTD_END_DATE"),
            when(ehr["EHR_START_DATE"].is_not_null(), lit(1)).otherwise(lit(0)).alias(
                "EHR_IND"
            ),
            ehr["EHR_START_DATE"].alias("EHR_START_DATE"),
            ehr["EHR_END_DATE"].alias("EHR_END_DATE"),
            coalesce(partc["PARTC_IND"], lit(0)).alias("PARTC_IND"),
        )
    )

    pat_table1.write.mode("overwrite").save_as_table("PAT_TABLE1")


def main():
    env.load_env()
    cfg = conn.load_snowcfg("DEID")
    session = conn.get_snow_conn(cfg)
    session.use_database(os.environ["DEID_SNOW_DATABASE"])
    session.use_schema("SX_CISTEM2")
    print(session.sql("SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_DATABASE()").collect())

    sites = [
        "ALLINA",
        "IHC",
        "KUMC",
        "MCRI",
        "MCW",
        "MU",
        "UCD",
        "UIOWA",
        "UNMC",
        "UTHOUSTON",
        "UTHSCSA",
        "UTSW",
        "UU",
        "WASHU"
    ]

    build_pat_demo_long(session, sites)
    build_pat_table1(session)


if __name__ == "__main__":
    main()