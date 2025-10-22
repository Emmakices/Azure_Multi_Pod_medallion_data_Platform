# Databricks notebook source
# MAGIC %md
# MAGIC # Log Data Lineage
# MAGIC
# MAGIC **Purpose**: Record or update data lineage tracking information
# MAGIC **Called By**: ADF pipeline after Copy, Bronze→Silver, Silver→Gold activities
# MAGIC **Updates**: data_lineage table with path and record count information

# COMMAND ----------

# Configure storage access
storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")
spark.conf.set(
    "fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net",
    storage_key
)

# COMMAND ----------

# Get parameters
dbutils.widgets.text("lineage_id", "", "Lineage ID")
dbutils.widgets.text("execution_id", "", "Execution ID")
dbutils.widgets.text("pod_id", "", "Pod ID")
dbutils.widgets.text("company", "", "Company")
dbutils.widgets.text("domain", "", "Domain")
dbutils.widgets.text("source_file_path", "", "Source File Path")
dbutils.widgets.text("source_file_name", "", "Source File Name")
dbutils.widgets.text("source_file_size_mb", "0", "Source File Size MB")
dbutils.widgets.text("layer", "", "Layer")  # bronze, silver, gold
dbutils.widgets.text("layer_path", "", "Layer Path")
dbutils.widgets.text("record_count", "0", "Record Count")
dbutils.widgets.text("records_rejected", "0", "Records Rejected")

# COMMAND ----------

from pyspark.sql.functions import col, lit
from delta.tables import DeltaTable
from datetime import datetime
import json
import uuid

# Get parameters
lineage_id = dbutils.widgets.get("lineage_id") or str(uuid.uuid4())
execution_id = dbutils.widgets.get("execution_id")
pod_id = dbutils.widgets.get("pod_id")
company = dbutils.widgets.get("company")
domain = dbutils.widgets.get("domain")
source_file_path = dbutils.widgets.get("source_file_path")
source_file_name = dbutils.widgets.get("source_file_name")
source_file_size_mb = float(dbutils.widgets.get("source_file_size_mb") or 0) or None
layer = dbutils.widgets.get("layer")  # bronze, silver, gold
layer_path = dbutils.widgets.get("layer_path")
record_count = int(dbutils.widgets.get("record_count") or 0) or None
records_rejected = int(dbutils.widgets.get("records_rejected") or 0) or None

current_timestamp = datetime.now()
processing_date = current_timestamp.strftime("%Y-%m-%d")

print(f"Logging lineage for: {lineage_id}")
print(f"  Layer: {layer}")
print(f"  Path: {layer_path}")
print(f"  Records: {record_count}")

# COMMAND ----------

STORAGE_ACCOUNT = "stdldevshared77b5h3"
LINEAGE_TABLE_PATH = f"abfss://gold@{STORAGE_ACCOUNT}.dfs.core.windows.net/config/data_lineage"

# Read existing table
df_lineage = spark.read.format("delta").load(LINEAGE_TABLE_PATH)

# Check if lineage_id exists
existing = df_lineage.filter(col("lineage_id") == lineage_id)

# COMMAND ----------

if existing.count() == 0:
    # Create new lineage record
    print(f"Creating new lineage record: {lineage_id}")

    new_record = {
        "lineage_id": lineage_id,
        "execution_id": execution_id,
        "source_file_path": source_file_path,
        "source_file_name": source_file_name,
        "source_file_size_mb": source_file_size_mb,
        "source_file_timestamp": current_timestamp,
        "source_file_hash": None,
        "pod_id": pod_id,
        "company": company,
        "domain": domain,
        "bronze_path": layer_path if layer == "bronze" else None,
        "bronze_timestamp": current_timestamp if layer == "bronze" else None,
        "records_in_bronze": record_count if layer == "bronze" else None,
        "silver_path": layer_path if layer == "silver" else None,
        "silver_timestamp": current_timestamp if layer == "silver" else None,
        "records_in_silver": record_count if layer == "silver" else None,
        "records_rejected": records_rejected if layer == "silver" else None,
        "gold_path": layer_path if layer == "gold" else None,
        "gold_timestamp": current_timestamp if layer == "gold" else None,
        "records_in_gold": record_count if layer == "gold" else None,
        "processing_start_time": current_timestamp,
        "processing_end_time": None,
        "total_processing_seconds": None,
        "lineage_status": "IN_PROGRESS",
        "created_at": current_timestamp,
        "updated_at": current_timestamp,
        "lineage_version": "1.0.0",
        "processing_date": processing_date
    }

    df_new = spark.createDataFrame([new_record])
    df_new.write.format("delta").mode("append").save(LINEAGE_TABLE_PATH)

    print(f"[OK] Created lineage record: {lineage_id}")

else:
    # Update existing lineage record
    print(f"Updating existing lineage record: {lineage_id}")

    deltaTable = DeltaTable.forPath(spark, LINEAGE_TABLE_PATH)

    # Build update dict based on layer
    update_dict = {"updated_at": lit(current_timestamp)}

    if layer == "bronze":
        update_dict["bronze_path"] = lit(layer_path)
        update_dict["bronze_timestamp"] = lit(current_timestamp)
        update_dict["records_in_bronze"] = lit(record_count)

    elif layer == "silver":
        update_dict["silver_path"] = lit(layer_path)
        update_dict["silver_timestamp"] = lit(current_timestamp)
        update_dict["records_in_silver"] = lit(record_count)
        update_dict["records_rejected"] = lit(records_rejected)

    elif layer == "gold":
        update_dict["gold_path"] = lit(layer_path)
        update_dict["gold_timestamp"] = lit(current_timestamp)
        update_dict["records_in_gold"] = lit(record_count)
        update_dict["lineage_status"] = lit("COMPLETED")

        # Calculate total processing time
        start_time = existing.select("processing_start_time").collect()[0][0]
        if start_time:
            duration = int((current_timestamp - start_time).total_seconds())
            update_dict["processing_end_time"] = lit(current_timestamp)
            update_dict["total_processing_seconds"] = lit(duration)

    deltaTable.update(
        condition = col("lineage_id") == lineage_id,
        set = update_dict
    )

    print(f"[OK] Updated lineage record: {lineage_id}")

# COMMAND ----------

# Return result
result = {
    "lineage_id": lineage_id,
    "layer": layer,
    "layer_path": layer_path,
    "record_count": record_count,
    "status": "SUCCESS"
}

print(f"Returning: {json.dumps(result)}")
dbutils.notebook.exit(json.dumps(result))
