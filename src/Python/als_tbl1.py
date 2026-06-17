import os
from snowflake.snowpark import Session
from snowflake.snowpark.functions import (
    col,
    datediff,
    lit,
    min as s_min,
    row_number,
    to_date,
    when,
)
from snowflake.snowpark.window import Window

from config import env, conn


def _get_session() -> Session:
    env.load_env()
    connect_params = conn.load_snowcfg("DEID")
    session = conn.get_snow_conn(connect_params)
    session.use_database(os.environ["DEID_SNOW_DATABASE"])
    session.use_schema("SX_CISTEM2")
    return session


def _ktx_idx(log_tbl_dxpx):
    w = Window.partition_by(col("PATID")).order_by(col("CD_DATE"))
    return (
        log_tbl_dxpx.filter(col("PHE_TYPE").isin(["KTx"]))
        .filter(col("ENC_TYPE").isin(["EI", "IP"]))
        .filter(
            (col("CD_DATE") >= to_date(lit("2014-01-01")))
            & (col("CD_DATE") <= to_date(lit("2023-12-31")))
        )
        .with_column("rn", row_number().over(w))
        .filter(col("rn") == 1)
        .with_column_renamed("CD_DATE", "KTX_DATE1")
        .select("PATID", "KTX_DATE1", "SITE")
    )


def _nodat(log_tbl_dxpx, ktx_idx):
    dm_idx = (
        log_tbl_dxpx.filter(col("PHE_TYPE").isin(["T2DM"]))
        .filter(
            (col("CD_DATE") >= to_date(lit("2014-01-01")))
            & (col("CD_DATE") <= to_date(lit("2023-12-31")))
        )
        .group_by(col("PATID"))
        .agg(s_min(col("CD_DATE")).alias("DM_DATE1"))
    )

    return (
        ktx_idx.join(dm_idx, ktx_idx["PATID"] == dm_idx["PATID"], "inner")
        .filter(dm_idx["DM_DATE1"] > ktx_idx["KTX_DATE1"])
        .select(
            ktx_idx["PATID"].alias("PATID"),
            dm_idx["DM_DATE1"].alias("DM_DATE1"),
            datediff("day", ktx_idx["KTX_DATE1"], dm_idx["DM_DATE1"]).alias(
                "DAYS_TO_NODAT"
            ),
        )
    )


def _mal_ae(log_tbl_dxpx, ktx_idx):
    mal_idx = (
        log_tbl_dxpx.filter(col("PHE_TYPE").isin(["MAL"]))
        .filter(
            (col("CD_DATE") >= to_date(lit("2014-01-01")))
            & (col("CD_DATE") <= to_date(lit("2023-12-31")))
        )
        .group_by(col("PATID"))
        .agg(s_min(col("CD_DATE")).alias("MAL_DATE1"))
    )

    return (
        ktx_idx.join(mal_idx, ktx_idx["PATID"] == mal_idx["PATID"])
        .filter(mal_idx["MAL_DATE1"] > ktx_idx["KTX_DATE1"])
        .select(
            ktx_idx["PATID"].alias("PATID"),
            mal_idx["MAL_DATE1"].alias("MAL_DATE1"),
            datediff("day", ktx_idx["KTX_DATE1"], mal_idx["MAL_DATE1"]).alias(
                "DAYS_TO_MAL"
            ),
        )
    )


def _mi_ae(log_tbl_dxpx, ktx_idx):
    mi_any = (
        log_tbl_dxpx.filter(col("PHE_TYPE").isin(["MI"]))
        .filter(
            (col("CD_DATE") >= to_date(lit("2014-01-01")))
            & (col("CD_DATE") <= to_date(lit("2023-12-31")))
        )
        .filter(col("ENC_TYPE").isin(["EI", "IP"]))
    )

    return (
        ktx_idx.join(mi_any, ktx_idx["PATID"] == mi_any["PATID"])
        .filter(mi_any["CD_DATE"] > ktx_idx["KTX_DATE1"])
        .select(
            ktx_idx["PATID"].alias("PATID"),
            mi_any["CD_DATE"].alias("MI_DATE1"),
            datediff("day", ktx_idx["KTX_DATE1"], mi_any["CD_DATE"]).alias(
                "DAYS_TO_MI"
            ),
        )
        .group_by(ktx_idx["PATID"])
        .agg(
            s_min(mi_any["CD_DATE"]).alias("MI_DATE1"),
            s_min(col("DAYS_TO_MI")).alias("DAYS_TO_MI"),
        )
    )


def _ar_ae(log_tbl_dxpx, log_tbl_rx, ktx_idx):
    biopsy_idx = (
        ktx_idx.join(
            log_tbl_dxpx,
            (ktx_idx["PATID"] == log_tbl_dxpx["PATID"])
            & (log_tbl_dxpx["PHE_TYPE"]).isin(["RenalBiopsy"])
            & (log_tbl_dxpx["CD_DATE"] >= to_date(lit("2014-01-01")))
            & (log_tbl_dxpx["CD_DATE"] <= to_date(lit("2023-12-31")))
            & (
                datediff("day", ktx_idx["KTX_DATE1"], log_tbl_dxpx["CD_DATE"])
            ).between(0, 180),
            join_type="inner",
        )
        .group_by(ktx_idx["PATID"], ktx_idx["KTX_DATE1"])
        .agg(s_min(log_tbl_dxpx["CD_DATE"]).alias("CD_DATE"))
        .select(
            ktx_idx["PATID"].alias("PATID"),
            log_tbl_dxpx["CD_DATE"].alias("RBX_DATE1"),
            datediff("day", ktx_idx["KTX_DATE1"], log_tbl_dxpx["CD_DATE"]).alias(
                "DAYS_TO_RBX"
            ),
        )
    )

    return (
        biopsy_idx.join(
            log_tbl_rx,
            (biopsy_idx["PATID"] == log_tbl_rx["PATID"])
            & (
                datediff("day", biopsy_idx["RBX_DATE1"], log_tbl_rx["CD_DATE"])
            ).between(0, 7),
            "inner",
        )
        .group_by(
            biopsy_idx["PATID"],
            biopsy_idx["RBX_DATE1"],
            biopsy_idx["DAYS_TO_RBX"],
        )
        .agg(s_min(log_tbl_rx["CD_DATE"]).alias("ANTIREJ_DATE1"))
        .select(
            biopsy_idx["PATID"].alias("PATID"),
            biopsy_idx["RBX_DATE1"].alias("RBX_DATE1"),
            biopsy_idx["DAYS_TO_RBX"].alias("DAYS_TO_RBX"),
            col("ANTIREJ_DATE1"),
        )
    )


def _build_final(session: Session, ktx_idx, nodat, mal_ae, mi_ae, ar_ae):
    k = ktx_idx.alias("k")
    n = nodat.alias("n")
    c = mal_ae.alias("c")
    m = mi_ae.alias("m")
    a = ar_ae.alias("a")
    p = session.table("PAT_TABLE1")

    jn1 = (
        k.join(n, k["PATID"] == n["PATID"], "left")
        .select(
            k["PATID"].alias("PATID"),
            k["KTX_DATE1"].alias("KTX_DATE1"),
            k["SITE"].alias("KTX_SITE"),
            n["DM_DATE1"].alias("DM_DATE1"),
            n["DAYS_TO_NODAT"].alias("DAYS_TO_NODAT"),
        )
        .with_column("NODAT_IND", when(col("DM_DATE1").is_not_null(), 1).otherwise(0))
    )
    jn2 = (
        jn1.join(m, jn1["PATID"] == m["PATID"], "left")
        .select(
            jn1["PATID"],
            jn1["KTX_DATE1"],
            jn1["KTX_SITE"],
            jn1["DM_DATE1"],
            jn1["DAYS_TO_NODAT"],
            jn1["NODAT_IND"],
            m["MI_DATE1"],
            m["DAYS_TO_MI"],
        )
        .with_column("MI_IND", when(col("MI_DATE1").is_not_null(), 1).otherwise(0))
    )
    jn3 = (
        jn2.join(c, jn2["PATID"] == c["PATID"], "left")
        .select(
            jn2["PATID"],
            jn2["KTX_DATE1"],
            jn2["KTX_SITE"],
            jn2["DM_DATE1"],
            jn2["DAYS_TO_NODAT"],
            jn2["NODAT_IND"],
            jn2["MI_DATE1"],
            jn2["DAYS_TO_MI"],
            jn2["MI_IND"],
            c["MAL_DATE1"],
            c["DAYS_TO_MAL"],
        )
        .with_column("MAL_IND", when(col("MAL_DATE1").is_not_null(), 1).otherwise(0))
    )
    jn4 = (
        jn3.join(a, jn3["PATID"] == a["PATID"], "left")
        .select(
            jn3["PATID"],
            jn3["KTX_DATE1"],
            jn3["KTX_SITE"],
            jn3["DM_DATE1"],
            jn3["DAYS_TO_NODAT"],
            jn3["NODAT_IND"],
            jn3["MI_DATE1"],
            jn3["DAYS_TO_MI"],
            jn3["MI_IND"],
            jn3["MAL_DATE1"],
            jn3["DAYS_TO_MAL"],
            jn3["MAL_IND"],
            a["RBX_DATE1"],
            a["DAYS_TO_RBX"],
            a["ANTIREJ_DATE1"],
            datediff("day", a["RBX_DATE1"], a["ANTIREJ_DATE1"]).alias(
                "DAYS_RBX_TO_ANTIREJ"
            ),
        )
        .with_column("AR_IND", when(col("RBX_DATE1").is_not_null(), 1).otherwise(0))
    )

    return (
        jn4.join(p, jn4["PATID"] == p["PATID"], "inner")
        .select(
            jn4["PATID"].alias("PATID"),
            jn4["KTX_DATE1"].alias("INDEX_DATE"),
            jn4["KTX_SITE"],
            jn4["DM_DATE1"],
            jn4["DAYS_TO_NODAT"],
            jn4["NODAT_IND"],
            jn4["MI_DATE1"],
            jn4["DAYS_TO_MI"],
            jn4["MI_IND"],
            jn4["MAL_DATE1"],
            jn4["DAYS_TO_MAL"],
            jn4["MAL_IND"],
            jn4["RBX_DATE1"],
            jn4["DAYS_TO_RBX"],
            jn4["ANTIREJ_DATE1"],
            jn4["DAYS_RBX_TO_ANTIREJ"],
            jn4["AR_IND"],
            p["SEX"],
            p["RACE"],
            p["HISPANIC"],
            datediff("year", p["BIRTH_DATE"], jn4["KTX_DATE1"]).alias("AGE_AT_KTX"),
            p["DEATH_IND"],
            p["CENSOR_DATE"],
            datediff("day", jn4["KTX_DATE1"], p["CENSOR_DATE"]).alias(
                "DAYS_TO_CENSOR"
            ),
            p["INDEX_SRC"].alias("SRC_SITE"),
        )
    )


def build_ktx_tbl1(session: Session):
    log_tbl_dxpx = session.table("KTX_DXPX_LONG")
    log_tbl_rx = session.table("KTX_RX_LONG")

    ktx_idx = _ktx_idx(log_tbl_dxpx)
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
    session = _get_session()
    print(session.sql("SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_DATABASE()").collect())
    build_ktx_tbl1(session)

if __name__ == "__main__":
    main()
