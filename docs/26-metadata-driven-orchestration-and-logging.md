# Metadata-Driven Orchestration and Execution Logging

**Created**: January 16, 2025
**Purpose**: Enterprise-grade configuration management and execution tracking
**Status**: Production-Ready

---

## Overview

This solution implements metadata-driven pipeline orchestration with comprehensive execution logging for monitoring, troubleshooting, and analytics.

---

## Architecture Components

### 1. Configuration Tables

**Company Configuration Table**
- Location: `gold/config/companies`
- Notebook: `databricks_notebooks/config/01_create_company_config_table.py`
- Purpose: Central registry for all companies and processing configuration

**Pipeline Execution Log Table**
- Location: `gold/config/pipeline_execution_log`
- Notebook: `databricks_notebooks/config/02_create_pipeline_execution_log_table.py`
- Purpose: Track all pipeline executions with metrics and errors

### 2. Helper Notebooks

**Get Company Config**
- Path: `/Shared/config/get_company_config`
- File: `databricks_notebooks/config/get_company_config.py`
- Purpose: Query configuration for a specific pod

**Log Execution Start**
- Path: `/Shared/config/log_execution_start`
- File: `databricks_notebooks/config/log_execution_start.py`
- Purpose: Log when pipeline execution starts

**Log Execution End**
- Path: `/Shared/config/log_execution_end`
- File: `databricks_notebooks/config/log_execution_end.py`
- Purpose: Log when pipeline execution completes with metrics

**Log Execution Error**
- Path: `/Shared/config/log_execution_error`
- File: `databricks_notebooks/config/log_execution_error.py`
- Purpose: Log pipeline execution errors

---

## Configuration Table Schema

### Company Configuration

```sql
CREATE TABLE company_config (
    -- Identifiers
    company_id STRING,              -- Unique ID: {pod_id}-{company}
    pod_id STRING,                  -- podA, podB, podC
    company STRING,                 -- finance, operations, etc.

    -- Processing Configuration
    enabled BOOLEAN,                -- Whether to process
    worker_count INT,               -- Number of workers
    domains ARRAY<STRING>,          -- [hr, payroll, finance]

    -- Business Metadata
    business_unit STRING,           -- Finance Operations
    cost_center STRING,             -- CC-FIN-001
    data_classification STRING,     -- CONFIDENTIAL, INTERNAL, etc.
    compliance_tags ARRAY<STRING>,  -- [GDPR, SOX, HIPAA]

    -- SLA and Priority
    sla_hours INT,                  -- SLA in hours
    priority STRING,                -- HIGH, MEDIUM, LOW
    max_retry_count INT,            -- Max retries on failure

    -- Cluster Configuration
    driver_node_type STRING,        -- Standard_DS3_v2
    worker_node_type STRING,        -- Standard_DS3_v2
    autoscale_min_workers INT,      -- Min workers
    autoscale_max_workers INT,      -- Max workers
    spot_instances_enabled BOOLEAN, -- Use spot instances

    -- Volume Estimates
    estimated_monthly_gb DOUBLE,    -- Expected data volume
    estimated_monthly_rows LONG,    -- Expected row count

    -- Audit
    created_by STRING,
    created_at TIMESTAMP,
    modified_by STRING,
    modified_at TIMESTAMP,
    approval_status STRING,         -- DRAFT, APPROVED, REJECTED
    approved_by STRING,

    -- Additional
    comments STRING,
    config_version STRING
)
PARTITIONED BY (pod_id)
```

### Pipeline Execution Log

```sql
CREATE TABLE pipeline_execution_log (
    -- Execution Identifiers
    execution_id STRING,            -- Unique execution GUID
    pipeline_name STRING,           -- ADF pipeline name
    activity_name STRING,           -- ADF activity name
    run_id STRING,                  -- ADF run ID

    -- Business Context
    pod_id STRING,
    company STRING,
    domain STRING,
    stage STRING,                   -- bronze_to_silver, silver_to_gold

    -- Execution Timing
    execution_start_time TIMESTAMP,
    execution_end_time TIMESTAMP,
    execution_duration_seconds LONG,

    -- Status
    status STRING,                  -- RUNNING, SUCCESS, FAILED
    error_message STRING,
    error_stack_trace STRING,
    retry_count INT,

    -- Data Metrics
    input_file_count INT,
    input_row_count LONG,
    output_row_count LONG,
    input_size_mb DOUBLE,
    output_size_mb DOUBLE,
    rows_failed_validation LONG,

    -- Resource Metrics
    cluster_id STRING,
    worker_count INT,
    node_type STRING,
    dbu_consumed DOUBLE,

    -- Paths
    source_path STRING,
    target_path STRING,
    notebook_path STRING,

    -- Custom Dimensions (key-value pairs)
    custom_dimensions MAP<STRING, STRING>,

    -- Quality
    data_quality_score DOUBLE,
    completeness_check_status STRING,

    -- Audit
    triggered_by STRING,
    environment STRING,
    log_version STRING,
    execution_date STRING           -- For partitioning
)
PARTITIONED BY (execution_date)
```

---

## ADF Integration Pattern

### Step 1: Get Company Configuration

```json
{
    "name": "Get_Company_Config",
    "type": "DatabricksNotebook",
    "typeProperties": {
        "notebookPath": "/Shared/config/get_company_config",
        "baseParameters": {
            "pod_id": "@pipeline().parameters.pod_id",
            "storage_account": "@pipeline().parameters.storage_account"
        }
    }
}
```

**Returns**: JSON array of companies
```json
[
    {
        "pod_id": "podA",
        "company": "finance",
        "worker_count": 2,
        "domains": ["hr", "payroll"]
    }
]
```

### Step 2: Loop Through Companies

```json
{
    "name": "ForEach_Company",
    "type": "ForEach",
    "typeProperties": {
        "items": {
            "value": "@json(activity('Get_Company_Config').output.runOutput)",
            "type": "Expression"
        },
        "isSequential": false,
        "activities": [
            // Nested activities here
        ]
    }
}
```

### Step 3: Log Execution Start

```json
{
    "name": "Log_Bronze_to_Silver_Start",
    "type": "DatabricksNotebook",
    "typeProperties": {
        "notebookPath": "/Shared/config/log_execution_start",
        "baseParameters": {
            "execution_id": "@guid()",
            "pipeline_name": "@pipeline().Pipeline",
            "activity_name": "Bronze_to_Silver",
            "run_id": "@pipeline().RunId",
            "pod_id": "@item().pod_id",
            "company": "@item().company",
            "domain": "@item().domain",
            "stage": "bronze_to_silver",
            "triggered_by": "@pipeline().parameters.triggered_by",
            "environment": "dev",
            "source_path": "@concat('bronze/', item().pod_id, '/', item().company, '/', item().domain)",
            "notebook_path": "@concat('/Shared/', item().pod_id, '/bronze_to_silver')",
            "custom_dimensions": "@json(concat('{\"cost_center\":\"', item().cost_center, '\",\"owner\":\"', item().pod_id, '_team\"}'))"
        }
    }
}
```

**Returns**:
```json
{
    "execution_id": "abc123-...",
    "execution_start_time": "2025-01-16T10:00:00",
    "status": "RUNNING"
}
```

### Step 4: Execute Main Activity

```json
{
    "name": "Bronze_to_Silver_Job",
    "type": "DatabricksNotebook",
    "dependsOn": [
        {
            "activity": "Log_Bronze_to_Silver_Start",
            "dependencyConditions": ["Succeeded"]
        }
    ],
    "typeProperties": {
        "notebookPath": "@concat('/Shared/', item().pod_id, '/bronze_to_silver')",
        "baseParameters": {
            "pod_id": "@item().pod_id",
            "company": "@item().company",
            "domain": "@item().domain",
            "storage_account": "@pipeline().parameters.storage_account"
        }
    }
}
```

### Step 5: Log Execution End (Success)

```json
{
    "name": "Log_Bronze_to_Silver_End",
    "type": "DatabricksNotebook",
    "dependsOn": [
        {
            "activity": "Bronze_to_Silver_Job",
            "dependencyConditions": ["Succeeded"]
        }
    ],
    "typeProperties": {
        "notebookPath": "/Shared/config/log_execution_end",
        "baseParameters": {
            "execution_id": "@activity('Log_Bronze_to_Silver_Start').output.runOutput.execution_id",
            "status": "SUCCESS",
            "input_row_count": "@activity('Bronze_to_Silver_Job').output.runOutput.input_rows",
            "output_row_count": "@activity('Bronze_to_Silver_Job').output.runOutput.output_rows",
            "data_quality_score": "@activity('Bronze_to_Silver_Job').output.runOutput.quality_score",
            "target_path": "@concat('silver/', item().pod_id, '/', item().company, '/', item().domain)"
        }
    }
}
```

### Step 6: Log Execution Error (Failure)

```json
{
    "name": "Log_Bronze_to_Silver_Error",
    "type": "DatabricksNotebook",
    "dependsOn": [
        {
            "activity": "Bronze_to_Silver_Job",
            "dependencyConditions": ["Failed"]
        }
    ],
    "typeProperties": {
        "notebookPath": "/Shared/config/log_execution_error",
        "baseParameters": {
            "execution_id": "@activity('Log_Bronze_to_Silver_Start').output.runOutput.execution_id",
            "error_message": "@activity('Bronze_to_Silver_Job').error.message",
            "error_stack_trace": "@string(activity('Bronze_to_Silver_Job').error)",
            "retry_count": "@pipeline().parameters.retry_count"
        }
    }
}
```

---

## Custom Dimensions Usage

Custom dimensions allow flexible filtering and analytics. Examples:

```json
{
    "cost_center": "CC-FIN-001",
    "owner": "podA_team",
    "priority": "HIGH",
    "sla_hours": "4",
    "data_classification": "CONFIDENTIAL",
    "business_unit": "Finance Operations",
    "triggered_by_file": "hr_employees.csv"
}
```

### Query by Custom Dimensions

```sql
SELECT *
FROM pipeline_execution_log
WHERE custom_dimensions['owner'] = 'podA_team'
  AND custom_dimensions['priority'] = 'HIGH'
  AND execution_date >= '2025-01-01'
```

---

## Monitoring Queries

### Recent Executions

```sql
SELECT
    execution_id,
    pod_id,
    company,
    domain,
    stage,
    status,
    execution_duration_seconds,
    data_quality_score
FROM vw_recent_executions
WHERE execution_date >= CURRENT_DATE() - 7
ORDER BY execution_start_time DESC
```

### Failed Executions

```sql
SELECT
    execution_id,
    pod_id,
    company,
    stage,
    error_message,
    retry_count
FROM vw_failed_executions
WHERE execution_date >= CURRENT_DATE() - 1
```

### Performance Metrics

```sql
SELECT
    stage,
    pod_id,
    COUNT(*) as execution_count,
    AVG(execution_duration_seconds) as avg_duration,
    AVG(data_quality_score) as avg_quality
FROM pipeline_execution_log
WHERE status = 'SUCCESS'
  AND execution_date >= CURRENT_DATE() - 30
GROUP BY stage, pod_id
```

### Cost Analysis by Owner

```sql
SELECT
    custom_dimensions['owner'] as owner,
    SUM(dbu_consumed) as total_dbu,
    COUNT(*) as execution_count,
    SUM(execution_duration_seconds) / 3600.0 as total_hours
FROM pipeline_execution_log
WHERE execution_date >= CURRENT_DATE() - 30
GROUP BY custom_dimensions['owner']
ORDER BY total_dbu DESC
```

---

## Setup Instructions

### 1. Create Tables

```bash
# Upload and run configuration table creation
databricks workspace import \
    databricks_notebooks/config/01_create_company_config_table.py \
    /Shared/config/create_company_config_table \
    --language PYTHON --overwrite

databricks workspace import \
    databricks_notebooks/config/02_create_pipeline_execution_log_table.py \
    /Shared/config/create_pipeline_execution_log_table \
    --language PYTHON --overwrite

# Run notebooks
databricks runs submit --notebook-path /Shared/config/create_company_config_table
databricks runs submit --notebook-path /Shared/config/create_pipeline_execution_log_table
```

### 2. Upload Helper Notebooks

```bash
databricks workspace import \
    databricks_notebooks/config/get_company_config.py \
    /Shared/config/get_company_config \
    --language PYTHON --overwrite

databricks workspace import \
    databricks_notebooks/config/log_execution_start.py \
    /Shared/config/log_execution_start \
    --language PYTHON --overwrite

databricks workspace import \
    databricks_notebooks/config/log_execution_end.py \
    /Shared/config/log_execution_end \
    --language PYTHON --overwrite

databricks workspace import \
    databricks_notebooks/config/log_execution_error.py \
    /Shared/config/log_execution_error \
    --language PYTHON --overwrite
```

### 3. Update ADF Pipeline

Add logging activities before and after each major processing step as shown in the ADF Integration Pattern section above.

---

## Benefits

**Metadata-Driven Orchestration**:
- Dynamic pipeline execution based on config table
- No hardcoded company lists in ADF
- Easy to add/remove companies without pipeline changes
- Centralized configuration management

**Execution Logging**:
- Complete audit trail of all executions
- Performance metrics for optimization
- Error tracking for troubleshooting
- Custom dimensions for flexible analytics
- Cost attribution by owner/pod/company

**Monitoring and Analytics**:
- Query execution history with Delta Lake
- Time travel for historical analysis
- Pre-built monitoring views
- Integration with Azure Monitor

**Governance**:
- Approval workflow for config changes
- Compliance tracking via tags
- Data classification enforcement
- SLA monitoring

---

## Summary

This metadata-driven orchestration solution provides:

1. **Configuration Table**: Central registry for all companies
2. **Execution Logging**: Comprehensive tracking of pipeline runs
3. **Helper Notebooks**: Reusable logging functions
4. **Custom Dimensions**: Flexible filtering and analytics
5. **Monitoring Views**: Pre-built queries for common use cases
6. **ADF Integration**: Seamless integration with pipeline activities

**Location**: `gold/config/`
**Status**: Production-Ready
**Documentation**: This document (docs/26)
