# Databricks notebook source
# MAGIC %md
# MAGIC # Company Configuration Table - Enterprise Standard
# MAGIC
# MAGIC **Purpose**: Central registry for all companies being processed in the data platform
# MAGIC
# MAGIC **Location**: `gold/config/companies`
# MAGIC
# MAGIC **Features**:
# MAGIC - Schema validation and constraints
# MAGIC - Audit trail with created/modified timestamps
# MAGIC - Version control via Delta Lake
# MAGIC - Data quality checks
# MAGIC - Partitioning for performance
# MAGIC - Table properties for governance
# MAGIC
# MAGIC **Owner**: Data Engineering Team
# MAGIC
# MAGIC **Last Updated**: 2025-01-15

# COMMAND ----------

# MAGIC %md
# MAGIC ## Setup and Imports

# COMMAND ----------

# Configure storage access using Databricks Secrets (Enterprise way)
# This must be run before accessing ADLS Gen2
storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")

spark.conf.set(
    "fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net",
    storage_key
)

print("Storage access configured securely via Databricks Secrets")

# COMMAND ----------

from pyspark.sql import SparkSession
from pyspark.sql.types import (
    StructType, StructField, StringType, IntegerType,
    BooleanType, ArrayType, TimestampType, DoubleType
)
from pyspark.sql.functions import (
    current_timestamp, col, lit, array_contains, size, expr
)
from datetime import datetime
import json

# COMMAND ----------

# MAGIC %md
# MAGIC ## Configuration Parameters

# COMMAND ----------

# Storage account name (from Terraform output)
STORAGE_ACCOUNT = "stdldevshared77b5h3"

# Gold layer path for configuration tables
GOLD_CONFIG_PATH = f"abfss://gold@{STORAGE_ACCOUNT}.dfs.core.windows.net/config"
COMPANY_TABLE_PATH = f"{GOLD_CONFIG_PATH}/companies"

# Table version for tracking schema changes
TABLE_VERSION = "1.0.0"

# Environment
ENVIRONMENT = "dev"

print(f"Configuration Table Path: {COMPANY_TABLE_PATH}")
print(f"Table Version: {TABLE_VERSION}")
print(f"Environment: {ENVIRONMENT}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Enterprise Schema Definition

# COMMAND ----------

# Define comprehensive schema with enterprise standards
company_config_schema = StructType([
    # Primary identifiers
    StructField("company_id", StringType(), False,
                metadata={"comment": "Unique identifier: {pod_id}-{company}"}),
    StructField("pod_id", StringType(), False,
                metadata={"comment": "Processing pod identifier (podA, podB, podC)"}),
    StructField("company", StringType(), False,
                metadata={"comment": "Company/account name (finance, operations, etc.)"}),

    # Processing configuration
    StructField("enabled", BooleanType(), False,
                metadata={"comment": "Whether to process this company (true/false)"}),
    StructField("worker_count", IntegerType(), False,
                metadata={"comment": "Number of Databricks cluster workers (1-10)"}),
    StructField("domains", ArrayType(StringType()), False,
                metadata={"comment": "Data domains to process [hr, payroll, finance, etc.]"}),

    # Business metadata
    StructField("business_unit", StringType(), True,
                metadata={"comment": "Business unit owning this company"}),
    StructField("cost_center", StringType(), True,
                metadata={"comment": "Cost center for chargeback"}),
    StructField("data_classification", StringType(), False,
                metadata={"comment": "Data sensitivity: PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED"}),
    StructField("compliance_tags", ArrayType(StringType()), True,
                metadata={"comment": "Compliance requirements: [GDPR, HIPAA, SOX, etc.]"}),

    # Processing SLA
    StructField("sla_hours", IntegerType(), False,
                metadata={"comment": "SLA for processing completion (hours)"}),
    StructField("priority", StringType(), False,
                metadata={"comment": "Processing priority: HIGH, MEDIUM, LOW"}),
    StructField("max_retry_count", IntegerType(), False,
                metadata={"comment": "Maximum retry attempts on failure"}),

    # Cluster configuration
    StructField("driver_node_type", StringType(), False,
                metadata={"comment": "Azure VM size for driver node"}),
    StructField("worker_node_type", StringType(), False,
                metadata={"comment": "Azure VM size for worker nodes"}),
    StructField("autoscale_min_workers", IntegerType(), True,
                metadata={"comment": "Minimum workers for autoscaling"}),
    StructField("autoscale_max_workers", IntegerType(), True,
                metadata={"comment": "Maximum workers for autoscaling"}),
    StructField("spot_instances_enabled", BooleanType(), False,
                metadata={"comment": "Use Azure Spot instances for cost savings"}),

    # Data volume estimates
    StructField("estimated_monthly_gb", DoubleType(), True,
                metadata={"comment": "Estimated monthly data volume in GB"}),
    StructField("estimated_monthly_rows", IntegerType(), True,
                metadata={"comment": "Estimated monthly row count"}),

    # Audit and governance
    StructField("created_by", StringType(), False,
                metadata={"comment": "User who created this configuration"}),
    StructField("created_at", TimestampType(), False,
                metadata={"comment": "Configuration creation timestamp"}),
    StructField("modified_by", StringType(), False,
                metadata={"comment": "User who last modified this configuration"}),
    StructField("modified_at", TimestampType(), False,
                metadata={"comment": "Last modification timestamp"}),
    StructField("approval_status", StringType(), False,
                metadata={"comment": "Configuration approval status: DRAFT, APPROVED, REJECTED"}),
    StructField("approved_by", StringType(), True,
                metadata={"comment": "Approver name"}),

    # Additional metadata
    StructField("comments", StringType(), True,
                metadata={"comment": "Additional notes or comments"}),
    StructField("config_version", StringType(), False,
                metadata={"comment": "Configuration schema version"})
])

print("[OK] Enterprise schema defined with comprehensive metadata")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Initial Configuration Data

# COMMAND ----------

# Enterprise-standard company configurations
company_configs = [
    # Pod A Companies
    {
        "company_id": "podA-finance",
        "pod_id": "podA",
        "company": "finance",
        "enabled": True,
        "worker_count": 2,
        "domains": ["hr", "payroll", "finance", "inventory"],
        "business_unit": "Finance Operations",
        "cost_center": "CC-FIN-001",
        "data_classification": "CONFIDENTIAL",
        "compliance_tags": ["SOX", "GDPR"],
        "sla_hours": 4,
        "priority": "HIGH",
        "max_retry_count": 3,
        "driver_node_type": "Standard_DS3_v2",
        "worker_node_type": "Standard_DS3_v2",
        "autoscale_min_workers": 2,
        "autoscale_max_workers": 4,
        "spot_instances_enabled": True,
        "estimated_monthly_gb": 150.5,
        "estimated_monthly_rows": 5000000,
        "created_by": "ihetuemmanuel@gmail.com",
        "created_at": datetime.now(),
        "modified_by": "ihetuemmanuel@gmail.com",
        "modified_at": datetime.now(),
        "approval_status": "APPROVED",
        "approved_by": "ihetuemmanuel@gmail.com",
        "comments": "Primary finance data processing",
        "config_version": TABLE_VERSION
    },
    {
        "company_id": "podA-operations",
        "pod_id": "podA",
        "company": "operations",
        "enabled": True,
        "worker_count": 2,
        "domains": ["hr", "inventory", "tickets"],
        "business_unit": "Operations",
        "cost_center": "CC-OPS-001",
        "data_classification": "INTERNAL",
        "compliance_tags": ["GDPR"],
        "sla_hours": 6,
        "priority": "MEDIUM",
        "max_retry_count": 3,
        "driver_node_type": "Standard_DS3_v2",
        "worker_node_type": "Standard_DS3_v2",
        "autoscale_min_workers": 2,
        "autoscale_max_workers": 4,
        "spot_instances_enabled": True,
        "estimated_monthly_gb": 100.0,
        "estimated_monthly_rows": 3000000,
        "created_by": "ihetuemmanuel@gmail.com",
        "created_at": datetime.now(),
        "modified_by": "ihetuemmanuel@gmail.com",
        "modified_at": datetime.now(),
        "approval_status": "APPROVED",
        "approved_by": "ihetuemmanuel@gmail.com",
        "comments": "Operations and logistics data",
        "config_version": TABLE_VERSION
    },
    {
        "company_id": "podA-marketing",
        "pod_id": "podA",
        "company": "marketing",
        "enabled": True,
        "worker_count": 1,
        "domains": ["campaigns", "crm"],
        "business_unit": "Marketing",
        "cost_center": "CC-MKT-001",
        "data_classification": "INTERNAL",
        "compliance_tags": ["GDPR"],
        "sla_hours": 8,
        "priority": "MEDIUM",
        "max_retry_count": 2,
        "driver_node_type": "Standard_DS3_v2",
        "worker_node_type": "Standard_DS3_v2",
        "autoscale_min_workers": 1,
        "autoscale_max_workers": 3,
        "spot_instances_enabled": True,
        "estimated_monthly_gb": 50.0,
        "estimated_monthly_rows": 1000000,
        "created_by": "ihetuemmanuel@gmail.com",
        "created_at": datetime.now(),
        "modified_by": "ihetuemmanuel@gmail.com",
        "modified_at": datetime.now(),
        "approval_status": "APPROVED",
        "approved_by": "ihetuemmanuel@gmail.com",
        "comments": "Marketing campaigns and CRM data",
        "config_version": TABLE_VERSION
    },
    {
        "company_id": "podA-it",
        "pod_id": "podA",
        "company": "it",
        "enabled": True,
        "worker_count": 1,
        "domains": ["tickets", "audit_logs"],
        "business_unit": "Information Technology",
        "cost_center": "CC-IT-001",
        "data_classification": "INTERNAL",
        "compliance_tags": ["SOX"],
        "sla_hours": 12,
        "priority": "LOW",
        "max_retry_count": 2,
        "driver_node_type": "Standard_DS3_v2",
        "worker_node_type": "Standard_DS3_v2",
        "autoscale_min_workers": 1,
        "autoscale_max_workers": 2,
        "spot_instances_enabled": True,
        "estimated_monthly_gb": 30.0,
        "estimated_monthly_rows": 800000,
        "created_by": "ihetuemmanuel@gmail.com",
        "created_at": datetime.now(),
        "modified_by": "ihetuemmanuel@gmail.com",
        "modified_at": datetime.now(),
        "approval_status": "APPROVED",
        "approved_by": "ihetuemmanuel@gmail.com",
        "comments": "IT support tickets and audit logs",
        "config_version": TABLE_VERSION
    },

    # Pod B Companies
    {
        "company_id": "podB-finance",
        "pod_id": "podB",
        "company": "finance",
        "enabled": True,
        "worker_count": 2,
        "domains": ["hr", "payroll", "finance"],
        "business_unit": "Finance Operations",
        "cost_center": "CC-FIN-002",
        "data_classification": "CONFIDENTIAL",
        "compliance_tags": ["SOX", "GDPR"],
        "sla_hours": 4,
        "priority": "HIGH",
        "max_retry_count": 3,
        "driver_node_type": "Standard_DS3_v2",
        "worker_node_type": "Standard_DS3_v2",
        "autoscale_min_workers": 2,
        "autoscale_max_workers": 4,
        "spot_instances_enabled": True,
        "estimated_monthly_gb": 120.0,
        "estimated_monthly_rows": 4000000,
        "created_by": "ihetuemmanuel@gmail.com",
        "created_at": datetime.now(),
        "modified_by": "ihetuemmanuel@gmail.com",
        "modified_at": datetime.now(),
        "approval_status": "APPROVED",
        "approved_by": "ihetuemmanuel@gmail.com",
        "comments": "Pod B finance operations",
        "config_version": TABLE_VERSION
    },
    {
        "company_id": "podB-operations",
        "pod_id": "podB",
        "company": "operations",
        "enabled": True,
        "worker_count": 2,
        "domains": ["hr", "inventory"],
        "business_unit": "Operations",
        "cost_center": "CC-OPS-002",
        "data_classification": "INTERNAL",
        "compliance_tags": ["GDPR"],
        "sla_hours": 6,
        "priority": "MEDIUM",
        "max_retry_count": 3,
        "driver_node_type": "Standard_DS3_v2",
        "worker_node_type": "Standard_DS3_v2",
        "autoscale_min_workers": 2,
        "autoscale_max_workers": 4,
        "spot_instances_enabled": True,
        "estimated_monthly_gb": 90.0,
        "estimated_monthly_rows": 2500000,
        "created_by": "ihetuemmanuel@gmail.com",
        "created_at": datetime.now(),
        "modified_by": "ihetuemmanuel@gmail.com",
        "modified_at": datetime.now(),
        "approval_status": "APPROVED",
        "approved_by": "ihetuemmanuel@gmail.com",
        "comments": "Pod B operations data",
        "config_version": TABLE_VERSION
    },
    {
        "company_id": "podB-sales",
        "pod_id": "podB",
        "company": "sales",
        "enabled": True,
        "worker_count": 2,
        "domains": ["crm", "campaigns"],
        "business_unit": "Sales",
        "cost_center": "CC-SALES-001",
        "data_classification": "CONFIDENTIAL",
        "compliance_tags": ["GDPR"],
        "sla_hours": 4,
        "priority": "HIGH",
        "max_retry_count": 3,
        "driver_node_type": "Standard_DS3_v2",
        "worker_node_type": "Standard_DS3_v2",
        "autoscale_min_workers": 2,
        "autoscale_max_workers": 5,
        "spot_instances_enabled": True,
        "estimated_monthly_gb": 200.0,
        "estimated_monthly_rows": 6000000,
        "created_by": "ihetuemmanuel@gmail.com",
        "created_at": datetime.now(),
        "modified_by": "ihetuemmanuel@gmail.com",
        "modified_at": datetime.now(),
        "approval_status": "APPROVED",
        "approved_by": "ihetuemmanuel@gmail.com",
        "comments": "Sales and CRM data processing",
        "config_version": TABLE_VERSION
    },

    # Pod C Companies
    {
        "company_id": "podC-finance",
        "pod_id": "podC",
        "company": "finance",
        "enabled": True,
        "worker_count": 2,
        "domains": ["hr", "payroll", "finance"],
        "business_unit": "Finance Operations",
        "cost_center": "CC-FIN-003",
        "data_classification": "CONFIDENTIAL",
        "compliance_tags": ["SOX", "GDPR"],
        "sla_hours": 4,
        "priority": "HIGH",
        "max_retry_count": 3,
        "driver_node_type": "Standard_DS3_v2",
        "worker_node_type": "Standard_DS3_v2",
        "autoscale_min_workers": 2,
        "autoscale_max_workers": 4,
        "spot_instances_enabled": True,
        "estimated_monthly_gb": 110.0,
        "estimated_monthly_rows": 3500000,
        "created_by": "ihetuemmanuel@gmail.com",
        "created_at": datetime.now(),
        "modified_by": "ihetuemmanuel@gmail.com",
        "modified_at": datetime.now(),
        "approval_status": "APPROVED",
        "approved_by": "ihetuemmanuel@gmail.com",
        "comments": "Pod C finance operations",
        "config_version": TABLE_VERSION
    },
    {
        "company_id": "podC-hr_central",
        "pod_id": "podC",
        "company": "hr_central",
        "enabled": True,
        "worker_count": 3,
        "domains": ["hr", "payroll", "benefits"],
        "business_unit": "Human Resources",
        "cost_center": "CC-HR-001",
        "data_classification": "RESTRICTED",
        "compliance_tags": ["GDPR", "HIPAA"],
        "sla_hours": 2,
        "priority": "HIGH",
        "max_retry_count": 5,
        "driver_node_type": "Standard_DS4_v2",
        "worker_node_type": "Standard_DS4_v2",
        "autoscale_min_workers": 3,
        "autoscale_max_workers": 6,
        "spot_instances_enabled": False,  # Sensitive data - no spot instances
        "estimated_monthly_gb": 300.0,
        "estimated_monthly_rows": 8000000,
        "created_by": "ihetuemmanuel@gmail.com",
        "created_at": datetime.now(),
        "modified_by": "ihetuemmanuel@gmail.com",
        "modified_at": datetime.now(),
        "approval_status": "APPROVED",
        "approved_by": "ihetuemmanuel@gmail.com",
        "comments": "Central HR data - highly sensitive, requires higher SLA",
        "config_version": TABLE_VERSION
    },
    {
        "company_id": "podC-compliance",
        "pod_id": "podC",
        "company": "compliance",
        "enabled": True,
        "worker_count": 1,
        "domains": ["audit_logs", "hr"],
        "business_unit": "Legal & Compliance",
        "cost_center": "CC-COMP-001",
        "data_classification": "RESTRICTED",
        "compliance_tags": ["SOX", "GDPR"],
        "sla_hours": 4,
        "priority": "HIGH",
        "max_retry_count": 3,
        "driver_node_type": "Standard_DS3_v2",
        "worker_node_type": "Standard_DS3_v2",
        "autoscale_min_workers": 1,
        "autoscale_max_workers": 3,
        "spot_instances_enabled": False,  # Compliance data - no spot instances
        "estimated_monthly_gb": 75.0,
        "estimated_monthly_rows": 2000000,
        "created_by": "ihetuemmanuel@gmail.com",
        "created_at": datetime.now(),
        "modified_by": "ihetuemmanuel@gmail.com",
        "modified_at": datetime.now(),
        "approval_status": "APPROVED",
        "approved_by": "ihetuemmanuel@gmail.com",
        "comments": "Compliance and audit data - no interruptions allowed",
        "config_version": TABLE_VERSION
    }
]

print(f"[OK] Defined {len(company_configs)} company configurations")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Create DataFrame with Validation

# COMMAND ----------

# Create DataFrame from configuration data
df_companies = spark.createDataFrame(company_configs, schema=company_config_schema)

# Add data quality checks
print("Running data quality validations...")

# Validation 1: Check for duplicate company_ids
duplicate_check = df_companies.groupBy("company_id").count().filter(col("count") > 1)
if duplicate_check.count() > 0:
    print("[ERROR] ERROR: Duplicate company_ids found!")
    duplicate_check.show()
    raise ValueError("Duplicate company_ids are not allowed")
else:
    print("[OK] No duplicate company_ids")

# Validation 2: Check worker count is within acceptable range
invalid_workers = df_companies.filter((col("worker_count") < 1) | (col("worker_count") > 10))
if invalid_workers.count() > 0:
    print("[ERROR] ERROR: Invalid worker_count found (must be 1-10)")
    invalid_workers.select("company_id", "worker_count").show()
    raise ValueError("Worker count must be between 1 and 10")
else:
    print("[OK] All worker counts are valid (1-10)")

# Validation 3: Check that domains array is not empty
empty_domains = df_companies.filter(size(col("domains")) == 0)
if empty_domains.count() > 0:
    print("[ERROR] ERROR: Companies with empty domains found")
    empty_domains.select("company_id", "domains").show()
    raise ValueError("Each company must have at least one domain")
else:
    print("[OK] All companies have domains defined")

# Validation 4: Check valid priorities
valid_priorities = ["HIGH", "MEDIUM", "LOW"]
invalid_priorities = df_companies.filter(~col("priority").isin(valid_priorities))
if invalid_priorities.count() > 0:
    print("[ERROR] ERROR: Invalid priority values found")
    invalid_priorities.select("company_id", "priority").show()
    raise ValueError("Priority must be HIGH, MEDIUM, or LOW")
else:
    print("[OK] All priorities are valid")

# Validation 5: Check valid data classifications
valid_classifications = ["PUBLIC", "INTERNAL", "CONFIDENTIAL", "RESTRICTED"]
invalid_classifications = df_companies.filter(~col("data_classification").isin(valid_classifications))
if invalid_classifications.count() > 0:
    print("[ERROR] ERROR: Invalid data_classification values found")
    invalid_classifications.select("company_id", "data_classification").show()
    raise ValueError("Data classification must be PUBLIC, INTERNAL, CONFIDENTIAL, or RESTRICTED")
else:
    print("[OK] All data classifications are valid")

# Validation 6: Check autoscale min <= max
invalid_autoscale = df_companies.filter(
    col("autoscale_min_workers") > col("autoscale_max_workers")
)
if invalid_autoscale.count() > 0:
    print("[ERROR] ERROR: Autoscale min > max found")
    invalid_autoscale.select("company_id", "autoscale_min_workers", "autoscale_max_workers").show()
    raise ValueError("Autoscale min_workers must be <= max_workers")
else:
    print("[OK] All autoscale configurations are valid")

print("\n[OK] All data quality validations passed!")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Display Configuration Summary

# COMMAND ----------

print("=" * 80)
print("COMPANY CONFIGURATION SUMMARY")
print("=" * 80)

# Show all configurations
df_companies.select(
    "company_id", "pod_id", "company", "enabled", "priority",
    "worker_count", "data_classification", "sla_hours"
).orderBy("pod_id", "company").show(truncate=False)

# Statistics by pod
print("\n" + "=" * 80)
print("STATISTICS BY POD")
print("=" * 80)
df_companies.groupBy("pod_id").agg(
    {"company_id": "count", "worker_count": "sum", "estimated_monthly_gb": "sum"}
).withColumnRenamed("count(company_id)", "company_count") \
 .withColumnRenamed("sum(worker_count)", "total_workers") \
 .withColumnRenamed("sum(estimated_monthly_gb)", "total_gb_monthly") \
 .orderBy("pod_id").show()

# Statistics by priority
print("\n" + "=" * 80)
print("STATISTICS BY PRIORITY")
print("=" * 80)
df_companies.groupBy("priority").count().orderBy("priority").show()

# Statistics by data classification
print("\n" + "=" * 80)
print("STATISTICS BY DATA CLASSIFICATION")
print("=" * 80)
df_companies.groupBy("data_classification").count().orderBy("data_classification").show()

# COMMAND ----------

# MAGIC %md
# MAGIC ## Write Delta Table with Enterprise Properties

# COMMAND ----------

print(f"Writing company configuration table to: {COMPANY_TABLE_PATH}")

# Write as Delta table with enterprise properties
(df_companies.write
    .format("delta")
    .mode("overwrite")
    .option("overwriteSchema", "true")
    .option("delta.enableChangeDataFeed", "true")  # Enable CDC for audit trail
    .option("delta.columnMapping.mode", "name")  # Column mapping for schema evolution
    .partitionBy("pod_id")  # Partition by pod for query performance
    .save(COMPANY_TABLE_PATH)
)

print(f"[OK] Delta table created successfully at: {COMPANY_TABLE_PATH}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Set Table Properties for Governance

# COMMAND ----------

# Register table in metastore
spark.sql(f"""
CREATE TABLE IF NOT EXISTS company_config
USING DELTA
LOCATION '{COMPANY_TABLE_PATH}'
""")

# Set table properties for enterprise governance
spark.sql("""
ALTER TABLE company_config SET TBLPROPERTIES (
    'delta.enableChangeDataFeed' = 'true',
    'delta.logRetentionDuration' = 'interval 90 days',
    'delta.deletedFileRetentionDuration' = 'interval 30 days',
    'delta.autoOptimize.optimizeWrite' = 'true',
    'delta.autoOptimize.autoCompact' = 'true',
    'description' = 'Central configuration registry for company data processing',
    'owner' = 'ihetuemmanuel@gmail.com',
    'created_by' = 'Databricks ETL Pipeline',
    'environment' = 'dev',
    'data_classification' = 'INTERNAL',
    'retention_policy' = '7 years',
    'version' = '1.0.0'
)
""")

print("[OK] Table properties set for enterprise governance")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Create Optimized Indexes

# COMMAND ----------

# Optimize table for query performance
spark.sql("OPTIMIZE company_config")

# Create Z-ordering for common query patterns
spark.sql("OPTIMIZE company_config ZORDER BY (enabled, priority, data_classification)")

print("[OK] Table optimized with Z-ordering")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Verification and Testing

# COMMAND ----------

print("=" * 80)
print("TABLE VERIFICATION")
print("=" * 80)

# Verify table was created
df_verify = spark.read.format("delta").load(COMPANY_TABLE_PATH)
print(f"\n[OK] Table contains {df_verify.count()} companies")

# Show table description
print("\n" + "=" * 80)
print("TABLE SCHEMA")
print("=" * 80)
spark.sql("DESCRIBE EXTENDED company_config").show(100, truncate=False)

# Show table history
print("\n" + "=" * 80)
print("TABLE HISTORY")
print("=" * 80)
spark.sql("DESCRIBE HISTORY company_config").show(truncate=False)

# Show table properties
print("\n" + "=" * 80)
print("TABLE PROPERTIES")
print("=" * 80)
spark.sql("SHOW TBLPROPERTIES company_config").show(truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Query Examples for ADF Integration

# COMMAND ----------

print("=" * 80)
print("EXAMPLE QUERIES FOR ADF PIPELINE INTEGRATION")
print("=" * 80)

# Query 1: Get all enabled companies for a specific pod
print("\n1. Get all enabled companies for podA:")
spark.sql("""
    SELECT company_id, company, worker_count, domains, priority, sla_hours
    FROM company_config
    WHERE pod_id = 'podA' AND enabled = true
    ORDER BY priority DESC, company
""").show(truncate=False)

# Query 2: Get high priority companies only
print("\n2. Get all HIGH priority companies:")
spark.sql("""
    SELECT pod_id, company, data_classification, sla_hours,
           estimated_monthly_gb, compliance_tags
    FROM company_config
    WHERE enabled = true AND priority = 'HIGH'
    ORDER BY sla_hours
""").show(truncate=False)

# Query 3: Get cluster configuration for dynamic sizing
print("\n3. Get cluster configuration for dynamic sizing:")
spark.sql("""
    SELECT company_id, worker_node_type,
           autoscale_min_workers, autoscale_max_workers,
           spot_instances_enabled
    FROM company_config
    WHERE enabled = true AND pod_id = 'podA'
""").show(truncate=False)

# Query 4: Get cost center information for chargeback
print("\n4. Get cost center information:")
spark.sql("""
    SELECT pod_id, company, business_unit, cost_center,
           estimated_monthly_gb, data_classification
    FROM company_config
    WHERE enabled = true
    ORDER BY estimated_monthly_gb DESC
""").show(truncate=False)

# Query 5: Get compliance requirements
print("\n5. Get companies requiring GDPR compliance:")
spark.sql("""
    SELECT company_id, business_unit, data_classification, compliance_tags
    FROM company_config
    WHERE enabled = true
    AND array_contains(compliance_tags, 'GDPR')
    ORDER BY data_classification DESC
""").show(truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Create View for Simplified ADF Queries

# COMMAND ----------

# Create a simplified view for ADF pipeline consumption
spark.sql("""
CREATE OR REPLACE VIEW vw_company_config_simple AS
SELECT
    company_id,
    pod_id,
    company,
    enabled,
    worker_count,
    domains,
    priority,
    sla_hours,
    driver_node_type,
    worker_node_type,
    autoscale_min_workers,
    autoscale_max_workers,
    spot_instances_enabled,
    data_classification,
    cost_center
FROM company_config
WHERE enabled = true
ORDER BY pod_id, priority DESC, company
""")

print("[OK] Simplified view created: vw_company_config_simple")

# Test the view
print("\nView contents:")
spark.sql("SELECT * FROM vw_company_config_simple").show(truncate=False)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Export Configuration as JSON for Reference

# COMMAND ----------

# Export configuration to JSON for documentation
config_json = df_companies.toPandas().to_json(orient='records', indent=2, date_format='iso')

print("=" * 80)
print("CONFIGURATION EXPORTED AS JSON")
print("=" * 80)
print(config_json[:1000] + "\n... (truncated)")

# Optionally write to file system
json_path = f"{GOLD_CONFIG_PATH}/company_config_export.json"
dbutils.fs.put(json_path, config_json, overwrite=True)
print(f"\n[OK] Full configuration exported to: {json_path}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Summary Report

# COMMAND ----------

print("=" * 80)
print("COMPANY CONFIGURATION TABLE - CREATION SUMMARY")
print("=" * 80)
print(f"\n📍 Location: {COMPANY_TABLE_PATH}")
print(f"📊 Total Companies: {df_verify.count()}")
print(f"🏢 Pods Configured: {df_verify.select('pod_id').distinct().count()}")
print(f"[OK] Enabled Companies: {df_verify.filter('enabled = true').count()}")
print(f"🔒 Data Classifications: {df_verify.select('data_classification').distinct().count()}")
print(f"📋 Schema Version: {TABLE_VERSION}")
print(f"🌍 Environment: {ENVIRONMENT}")

print("\n[OK] ENTERPRISE FEATURES ENABLED:")
print("   • Change Data Feed (CDC) for audit trail")
print("   • Column mapping for schema evolution")
print("   • Partitioning by pod_id for performance")
print("   • Z-ordering on enabled, priority, data_classification")
print("   • Auto-optimize and auto-compaction")
print("   • 90-day log retention for compliance")
print("   • Comprehensive business and technical metadata")

print("\n[OK] READY FOR ADF INTEGRATION")
print("   Use query: SELECT * FROM company_config WHERE pod_id = @pod_id AND enabled = true")
print("=" * 80)

# COMMAND ----------

# MAGIC %md
# MAGIC ## Next Steps
# MAGIC
# MAGIC 1. **Configure ADF Linked Service** to connect to Databricks
# MAGIC 2. **Create Lookup Activity** in ADF to read from `company_config` table
# MAGIC 3. **Build ForEach Pipeline** to iterate through companies
# MAGIC 4. **Add Databricks Notebook Activities** with job cluster specifications
# MAGIC 5. **Test with a single company** before enabling all
# MAGIC 6. **Monitor** using the pipeline metrics table (to be created next)
