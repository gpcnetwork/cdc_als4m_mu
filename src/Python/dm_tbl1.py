import os
from snowflake.snowpark import Session
from snowflake.snowpark.functions import (
    col,
    count,
    datediff,
    lit,
    min as s_min,
    row_number,
    when,
)
from snowflake.snowpark.window import Window

from config import env, conn

def _build_log_uniq(log_tbl):
    return (
        log_tbl
            .select("PATID", "PHE_TYPE", "CD_DATE")
            .drop_duplicates()
    )


def _build_init_dx(log_uniq):
    return (
        log_uniq
            .filter(col("PHE_TYPE").isin(["T1DM","T2DM"]))
            .group_by(col("PATID"))
            .agg(s_min(col("CD_DATE")).alias("DX1_DATE"))
    )


def _build_t1dm_rt(log_uniq):
    dm_counts = (
        log_uniq
            .group_by(col("PATID"))
            .agg(
                count(when(col("PHE_TYPE") == "T1DM", 1)).alias("T1DM_CNT"),
                count(when(col("PHE_TYPE") == "T2DM", 1)).alias("T2DM_CNT"),
                count(lit(1)).alias("DM_CNT")
            )
    )
    return (
        dm_counts
            .with_column(
                "T1_RT",
                when(col("DM_CNT") > 0, col("T1DM_CNT") / col("DM_CNT")).otherwise(lit(0))
            )
    )


def _build_insl_ind(log_uniq):
    return (
        log_uniq
            .filter(col("PHE_TYPE").isin(["INSULIN"]))
            .select("PATID")
            .drop_duplicates()
            .with_column("INSL_IND", lit(1))
    )


def _build_phepair(log_uniq):
    log_uniqa = log_uniq.select("PATID", "PHE_TYPE", "CD_DATE").to_df("PATID", "PHE_TYPE1", "CD_DATE1")
    log_uniqb = log_uniq.select("PATID", "PHE_TYPE", "CD_DATE").to_df("PATID", "PHE_TYPE2", "CD_DATE2")

    return (
        log_uniqa.join(log_uniqb, ["PATID"], how="inner")
            .filter(col("CD_DATE1") < col("CD_DATE2"))
            .with_column("DELTA_DAYS", datediff("day", col("CD_DATE1"), col("CD_DATE2")))
            .filter((col("DELTA_DAYS") <= 730) & (col("DELTA_DAYS") > 30))
            .select("PATID", "PHE_TYPE1", "CD_DATE1", "PHE_TYPE2", "CD_DATE2", "DELTA_DAYS")
            .drop_duplicates()
    )


def _build_dm_pt(phepair, init_dx, t1dm_rt, insl_ind):
    w_patid = Window.partition_by("PATID").order_by(col("CD_DATE1"))
    return (
        phepair
            .select("*", row_number().over(w_patid).alias("RN"))
            .filter(col("RN") == 1)
            .select(
                phepair["PATID"],
                phepair["PHE_TYPE1"],
                phepair["PHE_TYPE2"],
                phepair["CD_DATE1"],
                phepair["DELTA_DAYS"],
            )
            .join(init_dx, ["PATID"], how="inner")
            .join(t1dm_rt, ["PATID"], how="left")
            .join(insl_ind, ["PATID"], how="left")
            .with_column(
                "T1DM_IND",
                when((col("T1_RT") > 0.5) & (col("INSL_IND") == 1), lit(1))
                .otherwise(lit(0)),
            )
    )


def build_dm_tbl1(session: Session):
    log_dm_dxrx = session.table("DM_DXRX_LONG")
    log_dm_lab = session.table("DM_LAB_LONG")

    phepair = _build_dm_pt(log_tbl_dxpx)
    nodat = _nodat(log_tbl_dxpx, ktx_idx)
    mal_ae = _mal_ae(log_tbl_dxpx, ktx_idx)
    mi_ae = _mi_ae(log_tbl_dxpx, ktx_idx)
    ar_ae = _ar_ae(log_tbl_dxpx, log_tbl_rx, ktx_idx)

    nodat.write.mode("overwrite").save_as_table("NODAT")
    mal_ae.write.mode("overwrite").save_as_table("MAL_AE")
    mi_ae.write.mode("overwrite").save_as_table("MI_AE")
    ar_ae.write.mode("overwrite").save_as_table("AR_AE")

    final = _build_final(session, ktx_idx, nodat, mal_ae, mi_ae, ar_ae)
    final.write.mode("overwrite").save_as_table("KTX_TBL1")


def main():
    env.load_env()
    connect_params = conn.load_snowcfg("ID")
    session = conn.get_snow_conn(connect_params)
    session.use_database(os.environ["ID_SNOW_DATABASE"])
    session.use_schema("SX_ALS_GPC")
    print(session.sql("SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_DATABASE()").collect())


if __name__ == "__main__":
    main()
