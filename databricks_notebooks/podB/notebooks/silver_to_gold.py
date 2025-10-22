# Databricks notebook source
# MAGIC %md
# MAGIC # podB - Silver to Gold Transformation
# MAGIC **Owner**: podB Data Engineering Team
# MAGIC **Purpose**: Create podB-specific analytics and business metrics
# MAGIC **Customization**: podB business rules and KPIs

# COMMAND ----------

# Configure storage access
storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")
spark.conf.set(
    "fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net",
    storage_key
)

# COMMAND ----------

# Get parameters
dbutils.widgets.text("pod_id", "podB", "Pod ID")
dbutils.widgets.text("company", "sales", "Company")
dbutils.widgets.text("domain", "customers", "Domain")
dbutils.widgets.text("storage_account", "stdldevshared77b5h3", "Storage Account")

pod_id = dbutils.widgets.get("pod_id")
company = dbutils.widgets.get("company")
domain = dbutils.widgets.get("domain")
storage_account = dbutils.widgets.get("storage_account")

print(f"[podB] Processing Silver to Gold for {pod_id}/{company}/{domain}")

# COMMAND ----------

# Read from Silver
silver_path = f"abfss://silver@{storage_account}.dfs.core.windows.net/{pod_id}/{company}/{domain}/"

try:
    df_silver = spark.read.format("delta").load(silver_path)
    print(f"Read {df_silver.count()} records from Silver")
except Exception as e:
    import json
    dbutils.notebook.exit(json.dumps({"status": "NO_DATA", "message": f"Silver data not ready for {domain}"}))

# COMMAND ----------

from pyspark.sql.functions import count, current_date, lit

# podB-specific business metrics
# Customize based on podB KPIs

df_gold = df_silver.groupBy().agg(count("*").alias("total_records"))

df_gold = df_gold \
    .withColumn("report_date", current_date()) \
    .withColumn("pod_id", lit(pod_id)) \
    .withColumn("company", lit(company)) \
    .withColumn("domain", lit(domain))

print(f"[podB] Created metrics")

# COMMAND ----------

# Write to Gold
gold_path = f"abfss://gold@{storage_account}.dfs.core.windows.net/{pod_id}/{company}/{domain}_metrics/"
df_gold.write.format("delta").mode("overwrite").save(gold_path)
print(f"Written to Gold: {gold_path}")

# COMMAND ----------

import json

summary = {
    "status": "SUCCESS",
    "pod_id": pod_id,
    "company": company,
    "domain": domain,
    "silver_records_processed": df_silver.count(),
    "gold_records_created": df_gold.count(),
    "gold_path": gold_path,
    "owner": "podB_team"
}

print(json.dumps(summary, indent=2))
dbutils.notebook.exit(json.dumps(summary))
