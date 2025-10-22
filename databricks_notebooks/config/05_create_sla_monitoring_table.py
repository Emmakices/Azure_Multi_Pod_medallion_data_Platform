# Databricks notebook source
storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")
spark.conf.set("fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net", storage_key)

from pyspark.sql.types import *

TABLE_PATH = "abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/config/sla_monitoring"

schema = StructType([
    StructField("sla_check_id", StringType(), False),
    StructField("execution_id", StringType(), False),
    StructField("pod_id", StringType(), False),
    StructField("company", StringType(), False),
    StructField("domain", StringType(), True),
    StructField("sla_hours", IntegerType(), False),
    StructField("priority", StringType(), False),
    StructField("file_arrival_time", TimestampType(), False),
    StructField("processing_start_time", TimestampType(), False),
    StructField("processing_end_time", TimestampType(), True),
    StructField("total_elapsed_hours", DoubleType(), True),
    StructField("sla_met", BooleanType(), True),
    StructField("sla_breach_minutes", IntegerType(), True),
    StructField("alert_sent", BooleanType(), False),
    StructField("alert_recipients", StringType(), True),
    StructField("sla_date", StringType(), False)
])

df = spark.createDataFrame([], schema=schema)
(df.write.format("delta").mode("overwrite").partitionBy("sla_date").save(TABLE_PATH))

spark.sql(f"CREATE TABLE IF NOT EXISTS sla_monitoring USING DELTA LOCATION '{TABLE_PATH}'")
spark.sql("ALTER TABLE sla_monitoring SET TBLPROPERTIES ('owner' = 'ihetuemmanuel@gmail.com')")
spark.sql("OPTIMIZE sla_monitoring")

print("[OK] sla_monitoring created (empty, production-ready)")
