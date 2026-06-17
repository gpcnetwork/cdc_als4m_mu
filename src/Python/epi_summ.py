import os
import json
from utils import QueryFromJson
from snowflake.snowpark import Session
from snowflake.snowpark.types import StructType, StructField, StringType, IntegerType, DateType, BooleanType, VariantType
from snowflake.snowpark.functions import (
    col, coalesce, lit, lag, to_date, when, datediff, sum as s_sum, max as s_max, min as s_min, row_number,
    abs as s_abs, iff, least, call_function
)

# data pull - connect to snowflake
path_to_config = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))) + '\.config.json'
with open(path_to_config,"r") as f:
    config = json.load(f)
    connect_params = {
        "account": config["snowflake-id-api"]["acct"],
        "authenticator": config["snowflake-id-api"]["authenticator"],
        "user": config["snowflake-id-api"]["user"],
        "password":config["snowflake-id-api"]["pwd"],
        "role": config["snowflake-id-api"]["role"],
        "warehouse": config["snowflake-id-api"]["wh"]
    }