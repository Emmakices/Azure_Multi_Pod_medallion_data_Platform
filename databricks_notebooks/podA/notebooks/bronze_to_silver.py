# Databricks notebook source
# MAGIC %md
# MAGIC # podA - Bronze to Silver Transformation
# MAGIC **Owner**: podA Data Engineering Team
# MAGIC **Purpose**: Transform raw Bronze data to cleansed Silver layer for podA
# MAGIC **Customization**: podA-specific data quality rules and business logic

# COMMAND ----------

# Configure storage access using Databricks Secrets
storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")
spark.conf.set(
    "fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net",
    storage_key
)

# COMMAND ----------

# Get parameters from ADF
dbutils.widgets.text("pod_id", "podA", "Pod ID")
dbutils.widgets.text("company", "finance", "Company")
dbutils.widgets.text("domain", "hr", "Domain")
dbutils.widgets.text("storage_account", "stdldevshared77b5h3", "Storage Account")

pod_id = dbutils.widgets.get("pod_id")
company = dbutils.widgets.get("company")
domain = dbutils.widgets.get("domain")
storage_account = dbutils.widgets.get("storage_account")

print(f"[podA] Processing: {pod_id}/{company}/{domain}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 1: Define Paths

# COMMAND ----------

bronze_path = f"abfss://bronze@{storage_account}.dfs.core.windows.net/{pod_id}/{company}/{domain}/"
silver_path = f"abfss://silver@{storage_account}.dfs.core.windows.net/{pod_id}/{company}/{domain}/"

print(f"Bronze: {bronze_path}")
print(f"Silver: {silver_path}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 2: Read Data from Bronze

# COMMAND ----------

# Read all CSV files for this domain from Bronze
df_bronze = spark.read.option("header", "true").option("inferSchema", "true").csv(f"{bronze_path}*.csv")

print(f"Read {df_bronze.count()} rows from Bronze")
df_bronze.display()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 3: Apply podA-Specific Data Quality Rules

# COMMAND ----------

from pyspark.sql.functions import col, trim, upper, lower, current_timestamp, lit, regexp_replace

# podA-specific transformation logic
# Each pod team can customize this section based on their requirements

if domain == "hr":
    # podA HR-specific rules
    df_cleansed = df_bronze \
        .dropDuplicates() \
        .filter(col("employee_id").isNotNull()) \
        .withColumn("first_name", trim(col("first_name"))) \
        .withColumn("last_name", trim(col("last_name"))) \
        .withColumn("email", lower(col("email"))) \
        .withColumn("department", upper(col("department"))) \
        .withColumn("processed_timestamp", current_timestamp()) \
        .withColumn("pod_id", lit(pod_id)) \
        .withColumn("company", lit(company)) \
        .withColumn("domain", lit(domain))

    print(f"[podA HR] Applied HR-specific data quality rules")

elif domain == "payroll":
    # podA Payroll-specific rules
    df_cleansed = df_bronze \
        .dropDuplicates() \
        .filter(col("employee_id").isNotNull()) \
        .filter(col("base_salary") > 0) \
        .withColumn("processed_timestamp", current_timestamp()) \
        .withColumn("pod_id", lit(pod_id)) \
        .withColumn("company", lit(company)) \
        .withColumn("domain", lit(domain))

    print(f"[podA Payroll] Applied Payroll-specific data quality rules")

else:
    # Generic podA rules for other domains
    df_cleansed = df_bronze \
        .dropDuplicates() \
        .na.drop() \
        .withColumn("processed_timestamp", current_timestamp()) \
        .withColumn("pod_id", lit(pod_id)) \
        .withColumn("company", lit(company)) \
        .withColumn("domain", lit(domain))

    print(f"[podA {domain}] Applied generic data quality rules")

print(f"Cleansed to {df_cleansed.count()} rows")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 4: Write to Silver as Delta Table

# COMMAND ----------

df_cleansed.write \
    .format("delta") \
    .mode("overwrite") \
    .save(silver_path)

print(f"Written to Silver: {silver_path}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 5: Verify and Exit

# COMMAND ----------

import json

# Verify
df_verify = spark.read.format("delta").load(silver_path)
rows_written = df_verify.count()

print(f"Verification: {rows_written} rows in Silver")

# Return success
result = {
    "status": "SUCCESS",
    "pod_id": pod_id,
    "company": company,
    "domain": domain,
    "rows_written": rows_written,
    "silver_path": silver_path,
    "owner": "podA_team"
}

print(json.dumps(result, indent=2))
dbutils.notebook.exit(json.dumps(result))
