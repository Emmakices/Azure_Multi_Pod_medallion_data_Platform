# Databricks notebook source
# MAGIC %md
# MAGIC # podA - Silver to Gold Transformation
# MAGIC **Owner**: podA Data Engineering Team
# MAGIC **Purpose**: Create podA-specific analytics and business metrics
# MAGIC **Customization**: podA business rules and KPIs

# COMMAND ----------

# Configure storage access using Databricks Secrets
storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")
spark.conf.set(
    "fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net",
    storage_key
)

# COMMAND ----------

# Get parameters
dbutils.widgets.text("pod_id", "podA", "Pod ID")
dbutils.widgets.text("company", "finance", "Company")
dbutils.widgets.text("domain", "hr", "Domain")
dbutils.widgets.text("storage_account", "stdldevshared77b5h3", "Storage Account")

pod_id = dbutils.widgets.get("pod_id")
company = dbutils.widgets.get("company")
domain = dbutils.widgets.get("domain")
storage_account = dbutils.widgets.get("storage_account")

print(f"[podA] Processing Silver to Gold for {pod_id}/{company}/{domain}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 1: Read Data from Silver

# COMMAND ----------

silver_path = f"abfss://silver@{storage_account}.dfs.core.windows.net/{pod_id}/{company}/{domain}/"

try:
    df_silver = spark.read.format("delta").load(silver_path)
    print(f"Read {df_silver.count()} records from Silver")
    df_silver.display()
except Exception as e:
    print(f"No Silver data found: {e}")
    import json
    dbutils.notebook.exit(json.dumps({
        "status": "NO_DATA",
        "message": f"Silver data not ready for {domain}"
    }))

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 2: Create podA-Specific Business Metrics

# COMMAND ----------

from pyspark.sql.functions import avg, count, sum as _sum, min, max, current_date, lit, round as _round, datediff

# podA-specific business logic and KPIs
# Each pod team defines their own metrics based on business requirements

if domain == "hr" and company == "finance":
    # podA Finance HR metrics
    df_gold = df_silver.groupBy("department").agg(
        count("*").alias("employee_count"),
        _round(avg("salary"), 2).alias("avg_salary") if "salary" in df_silver.columns else lit(0).alias("avg_salary"),
        min("hire_date").alias("earliest_hire") if "hire_date" in df_silver.columns else lit(None).alias("earliest_hire"),
        max("hire_date").alias("latest_hire") if "hire_date" in df_silver.columns else lit(None).alias("latest_hire")
    )
    print(f"[podA Finance HR] Created department-level metrics")

elif domain == "payroll" and company == "finance":
    # podA Finance Payroll metrics
    df_gold = df_silver.groupBy("department").agg(
        count("*").alias("employee_count"),
        _round(_sum("base_salary"), 2).alias("total_base_salary") if "base_salary" in df_silver.columns else lit(0).alias("total_base_salary"),
        _round(_sum("bonus"), 2).alias("total_bonus") if "bonus" in df_silver.columns else lit(0).alias("total_bonus"),
        _round(_sum("base_salary") + _sum("bonus"), 2).alias("total_compensation") if "base_salary" in df_silver.columns and "bonus" in df_silver.columns else lit(0).alias("total_compensation")
    )
    print(f"[podA Finance Payroll] Created compensation metrics")

elif domain == "operations":
    # podA Operations metrics (example)
    df_gold = df_silver.groupBy("category").agg(
        count("*").alias("record_count"),
        avg("metric_value").alias("avg_metric") if "metric_value" in df_silver.columns else lit(0).alias("avg_metric")
    )
    print(f"[podA Operations] Created operations metrics")

else:
    # Generic podA metrics for other domains
    df_gold = df_silver.groupBy("category").agg(
        count("*").alias("record_count")
    ) if "category" in df_silver.columns else df_silver.groupBy().agg(count("*").alias("total_records"))
    print(f"[podA {domain}] Created generic metrics")

# Add metadata
df_gold = df_gold \
    .withColumn("report_date", current_date()) \
    .withColumn("pod_id", lit(pod_id)) \
    .withColumn("company", lit(company)) \
    .withColumn("domain", lit(domain))

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 3: Write to Gold

# COMMAND ----------

gold_path = f"abfss://gold@{storage_account}.dfs.core.windows.net/{pod_id}/{company}/{domain}_metrics/"

df_gold.write.format("delta").mode("overwrite").save(gold_path)

print(f"Written to Gold: {gold_path}")
print(f"Rows: {df_gold.count()}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 4: Summary and Exit

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
    "owner": "podA_team"
}

print("[podA] Silver to Gold transformation complete")
print(json.dumps(summary, indent=2))

dbutils.notebook.exit(json.dumps(summary))
