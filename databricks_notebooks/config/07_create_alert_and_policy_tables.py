# Databricks notebook source
# MAGIC %md
# MAGIC # Alert Rules, Retry Policy, and Archive Log Tables
# MAGIC
# MAGIC **Purpose**: Configuration for alerts, retries, and archive tracking
# MAGIC **Location**: `gold/config/`
# MAGIC
# MAGIC **Why**:
# MAGIC - Alert Rules: Define when and how to alert on issues
# MAGIC - Retry Policy: Configure retry behavior per pod/company
# MAGIC - Archive Log: Track archived files for compliance
# MAGIC
# MAGIC **Benefits**:
# MAGIC - Centralized alert management
# MAGIC - Flexible retry configuration
# MAGIC - Audit trail for file archival
# MAGIC - Compliance with data retention policies

# COMMAND ----------

storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")
spark.conf.set("fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net", storage_key)

from pyspark.sql.types import *
from datetime import datetime, timedelta

STORAGE_ACCOUNT = "stdldevshared77b5h3"
GOLD_CONFIG_PATH = f"abfss://gold@{STORAGE_ACCOUNT}.dfs.core.windows.net/config"

# COMMAND ----------

# MAGIC %md
# MAGIC ## 1. Alert Rules Table

# COMMAND ----------

alert_schema = StructType([
    StructField("alert_rule_id", StringType(), False),
    StructField("rule_name", StringType(), False),
    StructField("rule_type", StringType(), False,
                metadata={"comment": "DURATION, QUALITY, SLA, ERROR_RATE, COST"}),
    StructField("pod_id", StringType(), True),
    StructField("company", StringType(), True),
    StructField("domain", StringType(), True),
    StructField("stage", StringType(), True),
    StructField("threshold_value", DoubleType(), False),
    StructField("threshold_operator", StringType(), False,
                metadata={"comment": "GREATER_THAN, LESS_THAN, EQUALS"}),
    StructField("severity", StringType(), False),
    StructField("notification_channel", StringType(), False,
                metadata={"comment": "EMAIL, SLACK, TEAMS, PAGERDUTY"}),
    StructField("recipients", StringType(), False),
    StructField("enabled", BooleanType(), False),
    StructField("cooldown_minutes", IntegerType(), True,
                metadata={"comment": "Min time between alerts"}),
    StructField("created_at", TimestampType(), False),
    StructField("created_by", StringType(), False)
])

sample_alerts = [
    {
        "alert_rule_id": "alert-default",
        "rule_name": "Data_Quality_Critical_Alert",
        "rule_type": "QUALITY",
        "pod_id": None,
        "company": None,
        "domain": None,
        "stage": None,
        "threshold_value": 95.0,
        "threshold_operator": "LESS_THAN",
        "severity": "CRITICAL",
        "notification_channel": "EMAIL",
        "recipients": "ihetuemmanuel@gmail.com",
        "enabled": True,
        "cooldown_minutes": 60,
        "created_at": datetime.now(),
        "created_by": "ihetuemmanuel@gmail.com"
    }
]

ALERT_TABLE_PATH = f"{GOLD_CONFIG_PATH}/alert_rules"
df_alerts = spark.createDataFrame(sample_alerts, schema=alert_schema)
(df_alerts.write.format("delta").mode("overwrite").save(ALERT_TABLE_PATH))

spark.sql(f"CREATE TABLE IF NOT EXISTS alert_rules USING DELTA LOCATION '{ALERT_TABLE_PATH}'")
spark.sql("ALTER TABLE alert_rules SET TBLPROPERTIES ('owner' = 'ihetuemmanuel@gmail.com')")
spark.sql("OPTIMIZE alert_rules")

print("[OK] alert_rules created (1 default rule for ihetuemmanuel@gmail.com)")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 2. Retry Policy Table

# COMMAND ----------

retry_schema = StructType([
    StructField("policy_id", StringType(), False),
    StructField("pod_id", StringType(), False),
    StructField("company", StringType(), True),
    StructField("stage", StringType(), False),
    StructField("max_retry_count", IntegerType(), False),
    StructField("retry_delay_seconds", IntegerType(), False),
    StructField("exponential_backoff", BooleanType(), False),
    StructField("backoff_multiplier", DoubleType(), True),
    StructField("retry_on_errors", ArrayType(StringType()), True,
                metadata={"comment": "Error types to retry: TIMEOUT, RESOURCE_EXHAUSTED, etc."}),
    StructField("notify_on_retry", BooleanType(), False),
    StructField("notify_recipients", StringType(), True),
    StructField("enabled", BooleanType(), False)
])

sample_retry = [
    {
        "policy_id": "retry-001",
        "pod_id": "podA",
        "company": "finance",
        "stage": "bronze_to_silver",
        "max_retry_count": 3,
        "retry_delay_seconds": 60,
        "exponential_backoff": True,
        "backoff_multiplier": 2.0,
        "retry_on_errors": ["TIMEOUT", "RESOURCE_EXHAUSTED", "TRANSIENT_ERROR"],
        "notify_on_retry": True,
        "notify_recipients": "ihetuemmanuel@gmail.com",
        "enabled": True
    },
    {
        "policy_id": "retry-002",
        "pod_id": "podA",
        "company": None,
        "stage": "silver_to_gold",
        "max_retry_count": 2,
        "retry_delay_seconds": 30,
        "exponential_backoff": False,
        "backoff_multiplier": None,
        "retry_on_errors": ["TIMEOUT"],
        "notify_on_retry": False,
        "notify_recipients": None,
        "enabled": True
    }
]

RETRY_TABLE_PATH = f"{GOLD_CONFIG_PATH}/retry_policy"
df_retry = spark.createDataFrame(sample_retry, schema=retry_schema)
(df_retry.write.format("delta").mode("overwrite").save(RETRY_TABLE_PATH))

spark.sql(f"CREATE TABLE IF NOT EXISTS retry_policy USING DELTA LOCATION '{RETRY_TABLE_PATH}'")
spark.sql("OPTIMIZE retry_policy")

print("[OK] Retry Policy Table Created")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 3. Archive Log Table

# COMMAND ----------

archive_schema = StructType([
    StructField("archive_id", StringType(), False),
    StructField("source_path", StringType(), False),
    StructField("archive_path", StringType(), False),
    StructField("file_count", IntegerType(), False),
    StructField("total_size_mb", DoubleType(), False),
    StructField("archive_timestamp", TimestampType(), False),
    StructField("retention_days", IntegerType(), False,
                metadata={"comment": "Days to keep archived files"}),
    StructField("deletion_date", TimestampType(), False,
                metadata={"comment": "When files will be auto-deleted"}),
    StructField("pod_id", StringType(), False),
    StructField("company", StringType(), False),
    StructField("archived_by", StringType(), False),
    StructField("archive_date", StringType(), False)
])

sample_archive = [
    {
        "archive_id": "arch-001",
        "source_path": "landing/podA/finance/",
        "archive_path": "landing/podA/finance/archive/2025-01-16/",
        "file_count": 2,
        "total_size_mb": 25.7,
        "archive_timestamp": datetime(2025, 1, 16, 9, 2, 0),
        "retention_days": 90,
        "deletion_date": datetime(2025, 4, 16, 9, 2, 0),
        "pod_id": "podA",
        "company": "finance",
        "archived_by": "ADF_Pipeline",
        "archive_date": "2025-01-16"
    }
]

ARCHIVE_TABLE_PATH = f"{GOLD_CONFIG_PATH}/archive_log"
df_archive = spark.createDataFrame(sample_archive, schema=archive_schema)
(df_archive.write.format("delta").mode("overwrite").partitionBy("archive_date").save(ARCHIVE_TABLE_PATH))

spark.sql(f"CREATE TABLE IF NOT EXISTS archive_log USING DELTA LOCATION '{ARCHIVE_TABLE_PATH}'")
spark.sql("OPTIMIZE archive_log")

print("[OK] Archive Log Table Created")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Create Helper Views

# COMMAND ----------

# Active alerts view
spark.sql("""
CREATE OR REPLACE VIEW vw_active_alerts AS
SELECT
    alert_rule_id,
    rule_name,
    rule_type,
    severity,
    notification_channel,
    recipients,
    COALESCE(pod_id, 'ALL') as pod_id,
    COALESCE(company, 'ALL') as company
FROM alert_rules
WHERE enabled = true
ORDER BY severity DESC, rule_type
""")

# Files pending deletion view
spark.sql("""
CREATE OR REPLACE VIEW vw_files_pending_deletion AS
SELECT
    archive_id,
    archive_path,
    file_count,
    total_size_mb,
    deletion_date,
    DATEDIFF(deletion_date, CURRENT_DATE()) as days_until_deletion
FROM archive_log
WHERE deletion_date > CURRENT_DATE()
ORDER BY days_until_deletion
""")

print("[OK] Helper views created")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Summary

# COMMAND ----------

print("=" * 80)
print("CONFIGURATION TABLES CREATED")
print("=" * 80)
print("\n1. Alert Rules")
print(f"   Location: {ALERT_TABLE_PATH}")
print("   Purpose: Define alert conditions and notification channels")
print(f"   Sample Rules: {df_alerts.count()}")

print("\n2. Retry Policy")
print(f"   Location: {RETRY_TABLE_PATH}")
print("   Purpose: Configure retry behavior per pod/stage")
print(f"   Sample Policies: {df_retry.count()}")

print("\n3. Archive Log")
print(f"   Location: {ARCHIVE_TABLE_PATH}")
print("   Purpose: Track archived files and retention")
print(f"   Sample Records: {df_archive.count()}")

print("\n[OK] All configuration tables ready for use")
print("=" * 80)
