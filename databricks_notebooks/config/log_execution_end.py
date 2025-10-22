# Databricks notebook source
# MAGIC %md
# MAGIC # Log Execution End
# MAGIC
# MAGIC **Purpose**: Update execution log with completion status and metrics
# MAGIC **Called By**: ADF pipeline after each major activity completes
# MAGIC **Updates**: existing log entry with end time, status, and metrics

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
dbutils.widgets.text("status", "SUCCESS", "Status")
dbutils.widgets.text("error_message", "", "Error Message")
dbutils.widgets.text("input_row_count", "0", "Input Row Count")
dbutils.widgets.text("output_row_count", "0", "Output Row Count")
dbutils.widgets.text("input_size_mb", "0", "Input Size MB")
dbutils.widgets.text("output_size_mb", "0", "Output Size MB")
dbutils.widgets.text("rows_failed_validation", "0", "Rows Failed Validation")
dbutils.widgets.text("target_path", "", "Target Path")
dbutils.widgets.text("data_quality_score", "0", "Data Quality Score")
dbutils.widgets.text("completeness_check_status", "", "Completeness Check Status")
dbutils.widgets.text("custom_metrics", "{}", "Custom Metrics (JSON)")

# COMMAND ----------

from pyspark.sql.functions import col, lit, current_timestamp, unix_timestamp
from datetime import datetime
import json

# Get parameters
execution_id = dbutils.widgets.get("execution_id")
status = dbutils.widgets.get("status")
error_message = dbutils.widgets.get("error_message") or None
input_row_count = int(dbutils.widgets.get("input_row_count") or 0) or None
output_row_count = int(dbutils.widgets.get("output_row_count") or 0) or None
input_size_mb = float(dbutils.widgets.get("input_size_mb") or 0) or None
output_size_mb = float(dbutils.widgets.get("output_size_mb") or 0) or None
rows_failed_validation = int(dbutils.widgets.get("rows_failed_validation") or 0) or None
target_path = dbutils.widgets.get("target_path") or None
data_quality_score = float(dbutils.widgets.get("data_quality_score") or 0) or None
completeness_check_status = dbutils.widgets.get("completeness_check_status") or None
custom_metrics_str = dbutils.widgets.get("custom_metrics")

# Parse custom metrics
custom_metrics = json.loads(custom_metrics_str) if custom_metrics_str != "{}" else {}

execution_end_time = datetime.now()

print(f"Logging execution end: {execution_id}")
print(f"  Status: {status}")
print(f"  Output Rows: {output_row_count}")
print(f"  Quality Score: {data_quality_score}")

# COMMAND ----------

# Read current log table
STORAGE_ACCOUNT = "stdldevshared77b5h3"
LOG_TABLE_PATH = f"abfss://gold@{STORAGE_ACCOUNT}.dfs.core.windows.net/config/pipeline_execution_log"

df_logs = spark.read.format("delta").load(LOG_TABLE_PATH)

# COMMAND ----------

# Update the specific execution log entry
from delta.tables import DeltaTable

deltaTable = DeltaTable.forPath(spark, LOG_TABLE_PATH)

# Calculate duration
df_current = df_logs.filter(col("execution_id") == execution_id)

if df_current.count() == 0:
    print(f"[WARNING] Execution ID not found: {execution_id}")
    print("Creating new log entry")

    # Create new entry if not found
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
        "status": status,
        "error_message": error_message,
        "error_stack_trace": None,
        "retry_count": 0,
        "input_file_count": None,
        "input_row_count": input_row_count,
        "output_row_count": output_row_count,
        "input_size_mb": input_size_mb,
        "output_size_mb": output_size_mb,
        "rows_failed_validation": rows_failed_validation,
        "cluster_id": None,
        "worker_count": None,
        "node_type": None,
        "dbu_consumed": None,
        "source_path": None,
        "target_path": target_path,
        "notebook_path": None,
        "custom_dimensions": custom_metrics,
        "data_quality_score": data_quality_score,
        "completeness_check_status": completeness_check_status,
        "triggered_by": "system",
        "environment": "dev",
        "log_version": "1.0.0",
        "execution_date": execution_end_time.strftime("%Y-%m-%d")
    }

    df_new = spark.createDataFrame([log_entry])
    df_new.write.format("delta").mode("append").save(LOG_TABLE_PATH)

else:
    # Update existing entry
    start_time = df_current.select("execution_start_time").collect()[0][0]
    duration_seconds = int((execution_end_time - start_time).total_seconds())

    # Merge custom dimensions
    existing_custom_dims = df_current.select("custom_dimensions").collect()[0][0] or {}
    merged_custom_dims = {**existing_custom_dims, **custom_metrics}

    deltaTable.update(
        condition = col("execution_id") == execution_id,
        set = {
            "execution_end_time": lit(execution_end_time),
            "execution_duration_seconds": lit(duration_seconds),
            "status": lit(status),
            "error_message": lit(error_message),
            "input_row_count": lit(input_row_count),
            "output_row_count": lit(output_row_count),
            "input_size_mb": lit(input_size_mb),
            "output_size_mb": lit(output_size_mb),
            "rows_failed_validation": lit(rows_failed_validation),
            "target_path": lit(target_path),
            "data_quality_score": lit(data_quality_score),
            "completeness_check_status": lit(completeness_check_status),
            "custom_dimensions": lit(merged_custom_dims)
        }
    )

    print(f"[OK] Updated execution log: {execution_id}")
    print(f"  Duration: {duration_seconds} seconds")

# COMMAND ----------

# Return result to ADF
result = {
    "execution_id": execution_id,
    "status": status,
    "execution_end_time": execution_end_time.isoformat(),
    "output_row_count": output_row_count,
    "data_quality_score": data_quality_score
}

print(f"Returning: {json.dumps(result)}")
dbutils.notebook.exit(json.dumps(result))
