import os
from config import env, conn
from utils import QueryFromJson
from snowflake.snowpark import Session
from snowflake.snowpark.functions import lit


# vs_dm_lab = QueryFromJson(
#     url = './ref/vs-cde-dm.json',
#     sqlty = 'snow',
#     cd_field = 'LAB_LOINC',
#     date_fields = ["SPECIMEN_DATE",'LAB_ORDER_DATE','RESULT_DATE'],
#     srctbl_name = ".LDS_LAB_RESULT_CM",
#     other_fields=["PATID","ENCOUNTERID","RESULT_NUM","RESULT_UNIT"],
#     sel_keys = ['HbA1C','FBG','RBG'],
#     sel_domain = "lab",
#     val_field = "RESULT_NUM"
# )
# print(vs_dm_lab.gen_qry())


def _create_log_tbl_kd(session: Session, log_tbl:str) -> None:
    session.sql(
        f"""
        create or replace table {log_tbl} (
            PATID varchar(50),
            ENCOUNTERID varchar(50),
            CD varchar(100),
            CD_TYPE varchar(20),
            CD_DATE date,
            PHE_TYPE varchar(100),
            SITE varchar(10)
        )
        """
    ).collect()
    

def _create_log_tbl_kvd(session: Session, log_tbl: str) -> None:
    session.sql(
        f"""
        create or replace table {log_tbl} (
            PATID varchar(50),
            ENCOUNTERID varchar(50),
            CD_VAL double,
            CD_UNIT varchar(20),
            CD varchar(100),
            CD_TYPE varchar(20),
            CD_DATE date,
            PHE_TYPE varchar(100),
            SITE varchar(10)
        )
        """
    ).collect()


def _set_site_table(site: str) -> str:
    if site == 'CMS':
        return f"GROUSE_DB.{site}_PCORNET_CDM"
    else:
        return f"GROUSE_DB.PCORNET_CDM_{site}"
    

def _build_dm_dxrx(session: Session, site: str):
    vs_dm_dx = QueryFromJson(
        url = './ref/vs-cde-dm.json',
        sqlty = 'snow',
        cd_field = 'DX',
        cdtype_field = 'DX_TYPE',
        date_fields = ["DX_DATE",'ADMIT_DATE'],
        srctbl_name = f"{_set_site_table(site)}.LDS_DIAGNOSIS",
        other_fields=["PATID","ENCOUNTERID"],
        sel_keys = ['T2DM','T1DM'],
        sel_domain = "dx"
    )
    vs_dm_rx = QueryFromJson(
        url = './ref/vs-cde-dm.json',
        sqlty = 'snow',
        cd_field = 'RXNORM_CUI',
        date_fields = ["RX_START_DATE",'RX_ORDER_DATE'],
        srctbl_name = f"{_set_site_table(site)}.LDS_PRESCRIBING",
        other_fields=["PATID","ENCOUNTERID"],
        sel_keys = ['SU','AGI','GLP1','DPP4','MEG','AML','INS','SGLT2','COMBO','BIGU','TZD'],
        sel_domain = "rx"
    )
    # vs_dm_rx = QueryFromJson(
    #     url = './ref/vs-cde-dm.json',
    #     sqlty = 'snow',
    #     cd_field = 'NDC',
    #     date_fields = ['DISPENSE_DATE'],
    #     srctbl_name = f"{_set_site_table(site)}.LDS_DISPENSING",
    #     other_fields=["PATID","DISPENSINGID"],
    #     sel_keys = ['SU','AGI','GLP1','DPP4','MEG','AML','INS','SGLT2','COMBO','BIGU','TZD'],
    #     sel_domain = "rx"
    # )

    dm_dx_df = session.sql(vs_dm_dx.gen_qry()).union_all(
        session.sql(vs_dm_rx.gen_qry())
    )
    return dm_dx_df.with_column("SITE", lit(site))


def _build_dm_lab(session: Session, site: str):
    vs_dm_lab = QueryFromJson(
        url = './ref/vs-cde-dm.json',
        sqlty = 'snow',
        cd_field = 'LAB_LOINC',
        date_fields = ["SPECIMEN_DATE",'LAB_ORDER_DATE','RESULT_DATE'],
        srctbl_name = f"{_set_site_table(site)}.LDS_LAB_RESULT_CM",
        other_fields=["PATID","ENCOUNTERID","RESULT_NUM","RESULT_UNIT"],
        sel_keys = ['HbA1C','FBG','RBG'],
        sel_domain = "lab",
        val_field = "RESULT_NUM"
    )

    dm_lab_df = session.sql(vs_dm_lab.gen_qry())
    return dm_lab_df.with_column("SITE", lit(site))


def _build_als_dxrxpx(session: Session, site: str):
    vs_als_dx = QueryFromJson(
        url = './ref/vs-cde-als.json',
        sqlty = 'snow',
        cd_field = 'DX',
        cdtype_field = 'DX_TYPE',
        date_fields = ["DX_DATE",'ADMIT_DATE'],
        srctbl_name = f"{_set_site_table(site)}.LDS_DIAGNOSIS",
        other_fields=["PATID","ENCOUNTERID"],
        sel_keys = ['ALS','SxSpeech','SxSwallowing','SxMuscleWeakness','SxMuscleMovement','SxPainJointLimb','SxWalking','PBP','PLS'],
        sel_domain = "dx"
    )
    vs_als_px = QueryFromJson(
        url = './ref/vs-cde-als.json',
        sqlty = 'snow',
        cd_field = 'PX',
        cdtype_field= 'PX_TYPE',
        date_fields = ["PX_DATE",'ADMIT_DATE'],
        srctbl_name = f"{_set_site_table(site)}.LDS_PROCEDURES",
        other_fields=["PATID","ENCOUNTERID"],
        sel_keys = ["MobilityDeviceWheelchair","AssistiveDeviceCommunication","EnteralFeedingEquipment","RespiratoryDeviceNIV","RespiratoryDeviceMV"],
        sel_domain = "px"
    )
    vs_als_rx = QueryFromJson(
        url = './ref/vs-cde-als.json',
        sqlty = 'snow',
        cd_field = 'RXNORM_CUI',
        date_fields = ["RX_START_DATE",'RX_ORDER_DATE'],
        srctbl_name = f"{_set_site_table(site)}.LDS_PRESCRIBING",
        other_fields=["PATID","ENCOUNTERID"],
        sel_keys = ["riluzole","edaravone","tofersen"],
        sel_domain = "rx"
    )
    # vs_als_rx = QueryFromJson(
    #     url = './ref/vs-cde-als.json',
    #     sqlty = 'snow',
    #     cd_field = 'NDC',
    #     date_fields = ['DISPENSE_DATE'],
    #     srctbl_name = "GROUSE_DB.CMS_PCORNET_CDM.LDS_DISPENSING",
    #     other_fields=["PATID","DISPENSINGID"],
    #     sel_keys = ["riluzole","edaravone","tofersen"],
    #     sel_domain = "rx"
    # )

    als_dxrxpx_df = session.sql(vs_als_dx.gen_qry()).union_all(
        session.sql(vs_als_px.gen_qry())
    ).union_all(
        session.sql(vs_als_rx.gen_qry())
    )
    return als_dxrxpx_df.with_column("SITE", lit(site))


def build_event_logs(
    session: Session,
    site_lst: list[str],
    log_dm_dxrx: str = "DM_DXRX_LONG",
    log_dm_lab: str = "DM_LAB_LONG",
    log_als_dxrxpx: str = "ALS_DXRXPX_LONG"
):
    _create_log_tbl_kd(session, log_dm_dxrx)
    _create_log_tbl_kvd(session, log_dm_lab)
    _create_log_tbl_kd(session, log_als_dxrxpx)

    for site in site_lst:
        _build_dm_dxrx(session, site).write.mode("append").save_as_table(log_dm_dxrx)
        _build_dm_lab(session, site).write.mode("append").save_as_table(log_dm_lab)
        _build_als_dxrxpx(session, site).write.mode("append").save_as_table(log_als_dxrxpx)
        print(f"✅ Event log data for site {site} appended.")


def main():
    env.load_env()
    connect_params = conn.load_snowcfg("ID")
    session = conn.get_snow_conn(connect_params)
    session.use_database(os.environ["ID_SNOW_DATABASE"])
    session.use_schema("SX_ALS_GPC")
    print(session.sql("SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_DATABASE()").collect())

    site_lst = [
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
        "UTSW",
        "UU",
        "WASHU"
    ]

    build_event_logs(session, site_lst)

if __name__ == "__main__":
    main()
