# Databricks notebook source
# MAGIC %md
# MAGIC # Log Execution Error
# MAGIC
# MAGIC **Purpose**: Log execution errors with stack trace
# MAGIC **Called By**: ADF pipeline error handlers
# MAGIC **Updates**: existing log entry with FAILED status and error details

# COMMAND ----------

# Configure storage access
storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")
spark.conf.set(
    "fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net",
    storage_key
)

# COMMAND ----------

# Get parameters from ADF
dbutils.widgets.text("execution_id", "", "Execution ID")
dbutils.widgets.text("error_message", "", "Error Message")
dbutils.widgets.text("error_stack_trace", "", "Error Stack Trace")
dbutils.widgets.text("retry_count", "0", "Retry Count")

# COMMAND ----------

from pyspark.sql.functions import col, lit
from delta.tables import DeltaTable
from datetime import datetime
import json

# Get parameters
execution_id = dbutils.widgets.get("execution_id")
error_message = dbutils.widgets.get("error_message")
error_stack_trace = dbutils.widgets.get("error_stack_trace") or None
retry_count = int(dbutils.widgets.get("retry_count") or 0)

execution_end_time = datetime.now()

print(f"Logging execution error: {execution_id}")
print(f"  Error: {error_message}")
print(f"  Retry Count: {retry_count}")

# COMMAND ----------

# Update log table
STORAGE_ACCOUNT = "stdldevshared77b5h3"
LOG_TABLE_PATH = f"abfss://gold@{STORAGE_ACCOUNT}.dfs.core.windows.net/config/pipeline_execution_log"

deltaTable = DeltaTable.forPath(spark, LOG_TABLE_PATH)

# Read current entry to calculate duration
df_logs = spark.read.format("delta").load(LOG_TABLE_PATH)
df_current = df_logs.filter(col("execution_id") == execution_id)

if df_current.count() > 0:
    start_time = df_current.select("execution_start_time").collect()[0][0]
    duration_seconds = int((execution_end_time - start_time).total_seconds())

    deltaTable.update(
        condition = col("execution_id") == execution_id,
        set = {
            "execution_end_time": lit(execution_end_time),
            "execution_duration_seconds": lit(duration_seconds),
            "status": lit("FAILED"),
            "error_message": lit(error_message),
            "error_stack_trace": lit(error_stack_trace),
            "retry_count": lit(retry_count)
        }
    )

    print(f"[OK] Logged error for execution: {execution_id}")
    print(f"  Duration: {duration_seconds} seconds")
else:
    print(f"[WARNING] Execution ID not found: {execution_id}")
    print("Creating new error log entry")

    log_entry = {
        "execution_id": execution_id,
        "pipeline_name": "Unknown",
        "activity_name": "Unknown",
        "run_id": "Unknown",
        "pod_id": "Unknown",
        "company": "Unknown",
        "domain": None,
        "stage": "Unknown",
        "execution_start_time": execution_end_time,
        "execution_end_time": execution_end_time,
        "execution_duration_seconds": 0,
        "status": "FAILED",
        "error_message": error_message,
        "error_stack_trace": error_stack_trace,
        "retry_count": retry_count,
        "input_file_count": None,
        "input_row_count": None,
        "output_row_count": None,
        "input_size_mb": None,
        "output_size_mb": None,
        "rows_failed_validation": None,
        "cluster_id": None,
        "worker_count": None,
        "node_type": None,
        "dbu_consumed": None,
        "source_path": None,
        "target_path": None,
        "notebook_path": None,
        "custom_dimensions": {},
        "data_quality_score": None,
        "completeness_check_status": None,
        "triggered_by": "system",
        "environment": "dev",
        "log_version": "1.0.0",
        "execution_date": execution_end_time.strftime("%Y-%m-%d")
    }

    df_new = spark.createDataFrame([log_entry])
    df_new.write.format("delta").mode("append").save(LOG_TABLE_PATH)

# COMMAND ----------

# Return result to ADF
result = {
    "execution_id": execution_id,
    "status": "FAILED",
    "error_message": error_message,
    "retry_count": retry_count
}

print(f"Returning: {json.dumps(result)}")
dbutils.notebook.exit(json.dumps(result))
