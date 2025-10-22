# Databricks notebook source
storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")
spark.conf.set("fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net", storage_key)

from pyspark.sql.types import *

TABLE_PATH = "abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/config/data_quality_log"

schema = StructType([
    StructField("quality_check_id", StringType(), False),
    StructField("execution_id", StringType(), False),
    StructField("lineage_id", StringType(), True),
    StructField("pod_id", StringType(), False),
    StructField("company", StringType(), False),
    StructField("domain", StringType(), False),
    StructField("rule_name", StringType(), False),
    StructField("rule_type", StringType(), False),
    StructField("column_name", StringType(), True),
    StructField("expected_value", StringType(), True),
    StructField("actual_value", StringType(), True),
    StructField("records_checked", LongType(), False),
    StructField("records_passed", LongType(), False),
    StructField("records_failed", LongType(), False),
    StructField("pass_percentage", DoubleType(), False),
    StructField("severity", StringType(), False),
    StructField("action_taken", StringType(), False),
    StructField("check_timestamp", TimestampType(), False),
    StructField("check_duration_ms", LongType(), True),
    StructField("error_sample", StringType(), True),
    StructField("check_date", StringType(), False)
])

df = spark.createDataFrame([], schema=schema)
(df.write.format("delta").mode("overwrite").partitionBy("check_date").save(TABLE_PATH))

spark.sql(f"CREATE TABLE IF NOT EXISTS data_quality_log USING DELTA LOCATION '{TABLE_PATH}'")
spark.sql("ALTER TABLE data_quality_log SET TBLPROPERTIES ('owner' = 'ihetuemmanuel@gmail.com')")
spark.sql("OPTIMIZE data_quality_log")

print("[OK] data_quality_log created (empty, production-ready)")
