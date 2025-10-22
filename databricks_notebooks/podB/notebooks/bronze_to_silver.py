# Databricks notebook source
# MAGIC %md
# MAGIC # podB - Bronze to Silver Transformation
# MAGIC **Owner**: podB Data Engineering Team
# MAGIC **Purpose**: Transform raw Bronze data to cleansed Silver layer for podB
# MAGIC **Customization**: podB-specific data quality rules and business logic

# COMMAND ----------

# Configure storage access using Databricks Secrets
storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")
spark.conf.set(
    "fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net",
    storage_key
)

# COMMAND ----------

# Get parameters from ADF
dbutils.widgets.text("pod_id", "podB", "Pod ID")
dbutils.widgets.text("company", "sales", "Company")
dbutils.widgets.text("domain", "customers", "Domain")
dbutils.widgets.text("storage_account", "stdldevshared77b5h3", "Storage Account")

pod_id = dbutils.widgets.get("pod_id")
company = dbutils.widgets.get("company")
domain = dbutils.widgets.get("domain")
storage_account = dbutils.widgets.get("storage_account")

print(f"[podB] Processing: {pod_id}/{company}/{domain}")

# COMMAND ----------

# Define paths
bronze_path = f"abfss://bronze@{storage_account}.dfs.core.windows.net/{pod_id}/{company}/{domain}/"
silver_path = f"abfss://silver@{storage_account}.dfs.core.windows.net/{pod_id}/{company}/{domain}/"

print(f"Bronze: {bronze_path}")
print(f"Silver: {silver_path}")

# COMMAND ----------

# Read data from Bronze
df_bronze = spark.read.option("header", "true").option("inferSchema", "true").csv(f"{bronze_path}*.csv")
print(f"Read {df_bronze.count()} rows from Bronze")

# COMMAND ----------

from pyspark.sql.functions import col, trim, current_timestamp, lit

# podB-specific transformation logic
# Customize based on podB business requirements

df_cleansed = df_bronze \
    .dropDuplicates() \
    .na.drop() \
    .withColumn("processed_timestamp", current_timestamp()) \
    .withColumn("pod_id", lit(pod_id)) \
    .withColumn("company", lit(company)) \
    .withColumn("domain", lit(domain))

print(f"[podB] Cleansed to {df_cleansed.count()} rows")

# COMMAND ----------

# Write to Silver
df_cleansed.write.format("delta").mode("overwrite").save(silver_path)
print(f"Written to Silver: {silver_path}")

# COMMAND ----------

import json

result = {
    "status": "SUCCESS",
    "pod_id": pod_id,
    "company": company,
    "domain": domain,
    "rows_written": df_cleansed.count(),
    "silver_path": silver_path,
    "owner": "podB_team"
}

print(json.dumps(result, indent=2))
dbutils.notebook.exit(json.dumps(result))
