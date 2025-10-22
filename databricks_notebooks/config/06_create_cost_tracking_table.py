# Databricks notebook source
# MAGIC %md
# MAGIC # Cost Tracking Table
# MAGIC
# MAGIC **Purpose**: Track actual Azure costs per execution for chargeback
# MAGIC **Location**: `gold/config/cost_tracking`
# MAGIC **Why**: Attribute costs to business units, justify budgets, optimize spending
# MAGIC
# MAGIC **Benefits**:
# MAGIC - Monthly chargeback to cost centers
# MAGIC - Identify expensive processes for optimization
# MAGIC - Budget planning with historical cost data
# MAGIC - ROI analysis for infrastructure changes
# MAGIC - Cost transparency to business stakeholders

# COMMAND ----------

storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")
spark.conf.set("fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net", storage_key)

from pyspark.sql.types import *
from datetime import datetime

STORAGE_ACCOUNT = "stdldevshared77b5h3"
COST_TABLE_PATH = f"abfss://gold@{STORAGE_ACCOUNT}.dfs.core.windows.net/config/cost_tracking"

# COMMAND ----------

cost_schema = StructType([
    StructField("cost_id", StringType(), False),
    StructField("execution_id", StringType(), False),
    StructField("pod_id", StringType(), False),
    StructField("company", StringType(), False),
    StructField("domain", StringType(), True),
    StructField("cluster_id", StringType(), True),
    StructField("dbu_consumed", DoubleType(), True),
    StructField("dbu_rate_per_hour", DoubleType(), True,
                metadata={"comment": "DBU cost rate (e.g., $0.15/DBU)"}),
    StructField("compute_cost_usd", DoubleType(), True),
    StructField("storage_gb_read", DoubleType(), True),
    StructField("storage_gb_written", DoubleType(), True),
    StructField("storage_cost_usd", DoubleType(), True),
    StructField("total_cost_usd", DoubleType(), True),
    StructField("cost_center", StringType(), True),
    StructField("business_unit", StringType(), True),
    StructField("execution_duration_hours", DoubleType(), True),
    StructField("cost_per_record", DoubleType(), True,
                metadata={"comment": "Cost divided by records processed"}),
    StructField("billing_month", StringType(), False),
    StructField("cost_date", StringType(), False)
])

df_cost = spark.createDataFrame([], schema=cost_schema)
(df_cost.write.format("delta").mode("overwrite").partitionBy("billing_month").save(COST_TABLE_PATH))

spark.sql(f"CREATE TABLE IF NOT EXISTS cost_tracking USING DELTA LOCATION '{COST_TABLE_PATH}'")
spark.sql("ALTER TABLE cost_tracking SET TBLPROPERTIES ('owner' = 'ihetuemmanuel@gmail.com')")
spark.sql("OPTIMIZE cost_tracking")

spark.sql("""
CREATE OR REPLACE VIEW vw_cost_by_cost_center AS
SELECT
    cost_center,
    business_unit,
    billing_month,
    SUM(total_cost_usd) as total_cost,
    SUM(dbu_consumed) as total_dbu,
    COUNT(*) as execution_count
FROM cost_tracking
GROUP BY cost_center, business_unit, billing_month
ORDER BY total_cost DESC
""")

print("[OK] cost_tracking created (empty, production-ready)")
