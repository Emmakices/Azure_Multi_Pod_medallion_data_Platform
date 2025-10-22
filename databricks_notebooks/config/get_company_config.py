# Databricks notebook source
# MAGIC %md
# MAGIC # Company Configuration Query
# MAGIC Queries Delta table and returns filtered company list for ADF pipeline

# COMMAND ----------

# Configure storage access using Databricks Secrets (Enterprise way)
storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")

spark.conf.set(
    "fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net",
    storage_key
)

print("Storage access configured securely")

# COMMAND ----------

# Define parameters
dbutils.widgets.text("pod_id", "podA", "Pod ID")
dbutils.widgets.text("storage_account", "stdldevshared77b5h3", "Storage Account")

# COMMAND ----------

# Get parameter values
pod_id = dbutils.widgets.get("pod_id")
storage_account = dbutils.widgets.get("storage_account")

print(f"Querying companies for pod: {pod_id}")

# COMMAND ----------

# Read Delta table
config_path = f"abfss://gold@{storage_account}.dfs.core.windows.net/config/companies"
df = spark.read.format("delta").load(config_path)

# Filter for enabled companies in this pod
companies_df = df.filter(f"pod_id = '{pod_id}' AND enabled = true") \
                 .select("pod_id", "company", "worker_count", "domains")

print(f"Found {companies_df.count()} enabled companies")
companies_df.show()

# COMMAND ----------

# Convert to list of dictionaries for ADF
companies_list = [row.asDict() for row in companies_df.collect()]

# Return as JSON string for ADF to parse
import json
result = json.dumps(companies_list)

print(f"Returning to ADF: {result}")
dbutils.notebook.exit(result)
