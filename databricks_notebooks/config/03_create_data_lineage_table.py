# Databricks notebook source
storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")
spark.conf.set("fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net", storage_key)

from pyspark.sql.types import *

STORAGE_ACCOUNT = "stdldevshared77b5h3"
TABLE_PATH = f"abfss://gold@{STORAGE_ACCOUNT}.dfs.core.windows.net/config/data_lineage"

schema = StructType([
    StructField("lineage_id", StringType(), False),
    StructField("execution_id", StringType(), False),
    StructField("source_file_path", StringType(), False),
    StructField("source_file_name", StringType(), False),
    StructField("source_file_size_mb", DoubleType(), True),
    StructField("source_file_timestamp", TimestampType(), True),
    StructField("source_file_hash", StringType(), True),
    StructField("pod_id", StringType(), False),
    StructField("company", StringType(), False),
    StructField("domain", StringType(), False),
    StructField("bronze_path", StringType(), True),
    StructField("bronze_timestamp", TimestampType(), True),
    StructField("records_in_bronze", LongType(), True),
    StructField("silver_path", StringType(), True),
    StructField("silver_timestamp", TimestampType(), True),
    StructField("records_in_silver", LongType(), True),
    StructField("records_rejected", LongType(), True),
    StructField("gold_path", StringType(), True),
    StructField("gold_timestamp", TimestampType(), True),
    StructField("records_in_gold", LongType(), True),
    StructField("processing_start_time", TimestampType(), False),
    StructField("processing_end_time", TimestampType(), True),
    StructField("total_processing_seconds", LongType(), True),
    StructField("lineage_status", StringType(), False),
    StructField("created_at", TimestampType(), False),
    StructField("updated_at", TimestampType(), True),
    StructField("lineage_version", StringType(), False),
    StructField("processing_date", StringType(), False)
])

df = spark.createDataFrame([], schema=schema)
(df.write.format("delta").mode("overwrite").option("delta.enableChangeDataFeed", "true")
 .partitionBy("processing_date").save(TABLE_PATH))

spark.sql(f"CREATE TABLE IF NOT EXISTS data_lineage USING DELTA LOCATION '{TABLE_PATH}'")
spark.sql("ALTER TABLE data_lineage SET TBLPROPERTIES ('owner' = 'ihetuemmanuel@gmail.com')")
spark.sql("OPTIMIZE data_lineage")

print(f"[OK] data_lineage created (empty, production-ready)")
