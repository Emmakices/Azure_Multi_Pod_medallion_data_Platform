# Databricks notebook source
# MAGIC %md
# MAGIC # Pipeline Execution Log Table
# MAGIC Creates empty production-ready table

# COMMAND ----------

storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")
spark.conf.set("fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net", storage_key)

from pyspark.sql.types import *

STORAGE_ACCOUNT = "stdldevshared77b5h3"
LOG_TABLE_PATH = f"abfss://gold@{STORAGE_ACCOUNT}.dfs.core.windows.net/config/pipeline_execution_log"

execution_log_schema = StructType([
    StructField("execution_id", StringType(), False),
    StructField("pipeline_name", StringType(), False),
    StructField("activity_name", StringType(), True),
    StructField("run_id", StringType(), False),
    StructField("pod_id", StringType(), False),
    StructField("company", StringType(), False),
    StructField("domain", StringType(), True),
    StructField("stage", StringType(), False),
    StructField("execution_start_time", TimestampType(), False),
    StructField("execution_end_time", TimestampType(), True),
    StructField("execution_duration_seconds", LongType(), True),
    StructField("status", StringType(), False),
    StructField("error_message", StringType(), True),
    StructField("error_stack_trace", StringType(), True),
    StructField("retry_count", IntegerType(), False),
    StructField("input_file_count", IntegerType(), True),
    StructField("input_row_count", LongType(), True),
    StructField("output_row_count", LongType(), True),
    StructField("input_size_mb", DoubleType(), True),
    StructField("output_size_mb", DoubleType(), True),
    StructField("rows_failed_validation", LongType(), True),
    StructField("cluster_id", StringType(), True),
    StructField("worker_count", IntegerType(), True),
    StructField("node_type", StringType(), True),
    StructField("dbu_consumed", DoubleType(), True),
    StructField("source_path", StringType(), True),
    StructField("target_path", StringType(), True),
    StructField("notebook_path", StringType(), True),
    StructField("custom_dimensions", MapType(StringType(), StringType()), True),
    StructField("data_quality_score", DoubleType(), True),
    StructField("completeness_check_status", StringType(), True),
    StructField("triggered_by", StringType(), False),
    StructField("environment", StringType(), False),
    StructField("log_version", StringType(), False),
    StructField("execution_date", StringType(), False)
])

df_logs = spark.createDataFrame([], schema=execution_log_schema)

(df_logs.write.format("delta").mode("overwrite").option("overwriteSchema", "true")
 .option("delta.enableChangeDataFeed", "true").partitionBy("execution_date").save(LOG_TABLE_PATH))

spark.sql(f"CREATE TABLE IF NOT EXISTS pipeline_execution_log USING DELTA LOCATION '{LOG_TABLE_PATH}'")
spark.sql("ALTER TABLE pipeline_execution_log SET TBLPROPERTIES ('owner' = 'ihetuemmanuel@gmail.com')")
spark.sql("OPTIMIZE pipeline_execution_log")

spark.sql("""CREATE OR REPLACE VIEW vw_recent_executions AS
SELECT execution_id, pipeline_name, pod_id, company, stage, status, execution_duration_seconds
FROM pipeline_execution_log WHERE execution_date >= DATE_SUB(CURRENT_DATE(), 7)""")

print(f"[OK] pipeline_execution_log created at {LOG_TABLE_PATH} (empty, production-ready)")
