# Databricks notebook source
# MAGIC %md
# MAGIC # Log Execution Start
# MAGIC
# MAGIC **Purpose**: Log the start of a pipeline execution
# MAGIC **Called By**: ADF pipeline before each major activity
# MAGIC **Returns**: execution_id for tracking

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
dbutils.widgets.text("pipeline_name", "", "Pipeline Name")
dbutils.widgets.text("activity_name", "", "Activity Name")
dbutils.widgets.text("run_id", "", "Run ID")
dbutils.widgets.text("pod_id", "", "Pod ID")
dbutils.widgets.text("company", "", "Company")
dbutils.widgets.text("domain", "", "Domain")
dbutils.widgets.text("stage", "", "Stage")
dbutils.widgets.text("triggered_by", "system", "Triggered By")
dbutils.widgets.text("environment", "dev", "Environment")
dbutils.widgets.text("source_path", "", "Source Path")
dbutils.widgets.text("notebook_path", "", "Notebook Path")
dbutils.widgets.text("custom_dimensions", "{}", "Custom Dimensions (JSON)")

# COMMAND ----------

from pyspark.sql.types import StructType, StructField, StringType, IntegerType, TimestampType, MapType
from datetime import datetime
import json
import uuid

# Get all parameters
execution_id = dbutils.widgets.get("execution_id") or str(uuid.uuid4())
pipeline_name = dbutils.widgets.get("pipeline_name")
activity_name = dbutils.widgets.get("activity_name")
run_id = dbutils.widgets.get("run_id")
pod_id = dbutils.widgets.get("pod_id")
company = dbutils.widgets.get("company")
domain = dbutils.widgets.get("domain") or None
stage = dbutils.widgets.get("stage")
triggered_by = dbutils.widgets.get("triggered_by")
environment = dbutils.widgets.get("environment")
source_path = dbutils.widgets.get("source_path") or None
notebook_path = dbutils.widgets.get("notebook_path") or None
custom_dimensions_str = dbutils.widgets.get("custom_dimensions")

# Parse custom dimensions
custom_dimensions = json.loads(custom_dimensions_str) if custom_dimensions_str != "{}" else {}

# Current timestamp
execution_start_time = datetime.now()
execution_date = execution_start_time.strftime("%Y-%m-%d")

print(f"Logging execution start: {execution_id}")
print(f"  Pipeline: {pipeline_name}")
print(f"  Activity: {activity_name}")
print(f"  Pod: {pod_id}")
print(f"  Company: {company}")
print(f"  Domain: {domain}")
print(f"  Stage: {stage}")

# COMMAND ----------

# Create log entry
log_entry = {
    "execution_id": execution_id,
    "pipeline_name": pipeline_name,
    "activity_name": activity_name,
    "run_id": run_id,
    "pod_id": pod_id,
    "company": company,
    "domain": domain,
    "stage": stage,
    "execution_start_time": execution_start_time,
    "execution_end_time": None,
    "execution_duration_seconds": None,
    "status": "RUNNING",
    "error_message": None,
    "error_stack_trace": None,
    "retry_count": 0,
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
    "source_path": source_path,
    "target_path": None,
    "notebook_path": notebook_path,
    "custom_dimensions": custom_dimensions,
    "data_quality_score": None,
    "completeness_check_status": None,
    "triggered_by": triggered_by,
    "environment": environment,
    "log_version": "1.0.0",
    "execution_date": execution_date
}

# COMMAND ----------

# Append to Delta table
STORAGE_ACCOUNT = "stdldevshared77b5h3"
LOG_TABLE_PATH = f"abfss://gold@{STORAGE_ACCOUNT}.dfs.core.windows.net/config/pipeline_execution_log"

df_log = spark.createDataFrame([log_entry])

df_log.write \
    .format("delta") \
    .mode("append") \
    .save(LOG_TABLE_PATH)

print(f"[OK] Logged execution start: {execution_id}")

# COMMAND ----------

# Return execution_id to ADF for tracking
result = {
    "execution_id": execution_id,
    "execution_start_time": execution_start_time.isoformat(),
    "status": "RUNNING"
}

print(f"Returning: {json.dumps(result)}")
dbutils.notebook.exit(json.dumps(result))
