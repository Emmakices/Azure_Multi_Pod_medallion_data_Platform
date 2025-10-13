# Databricks Notebook Upload and Execution Guide

## Overview

This guide documents how to upload and run Databricks notebooks, specifically the company configuration table creation notebook.

**Date**: 2025-01-15
**Environment**: Dev
**Databricks Workspace**: https://adb-3370863217573312.12.azuredatabricks.net

---

## Table of Contents

1. [Automated Upload Method](#automated-upload-method)
2. [Manual Upload Method (UI)](#manual-upload-method-ui)
3. [Running the Notebook](#running-the-notebook)
4. [Troubleshooting](#troubleshooting)
5. [Verification](#verification)

---

## Automated Upload Method

### Prerequisites

- Python 3.x installed
- `requests` library (`pip install requests`)
- Databricks personal access token
- Notebook file on local system

### Step 1: Upload Script

A Python script was created to automate the upload and execution process:

**Location**: `C:\Users\User\Desktop\Delta_lake_project\scripts\upload_and_run_config_notebook.py`

**What it does**:
1. Creates `/Shared/config/` directory in Databricks workspace
2. Uploads the notebook to `/Shared/config/01_create_company_config_table`
3. Creates an ephemeral job cluster
4. Runs the notebook
5. Monitors execution status

### Step 2: Run the Upload Script

```bash
cd C:/Users/User/Desktop/Delta_lake_project/scripts
python upload_and_run_config_notebook.py
```

### Step 3: Output

```
================================================================================
DATABRICKS NOTEBOOK UPLOAD AND EXECUTION
================================================================================
Host: https://adb-3370863217573312.12.azuredatabricks.net
Notebook: C:\Users\User\Desktop\Delta_lake_project\databricks_notebooks\config\01_create_company_config_table.py
Target: /Shared/config/01_create_company_config_table
================================================================================
Creating directory: /Shared/config
[OK] Directory created: /Shared/config

Uploading notebook from: C:\Users\User\Desktop\Delta_lake_project\databricks_notebooks\config\01_create_company_config_table.py
To Databricks path: /Shared/config/01_create_company_config_table
[OK] Notebook uploaded successfully

Listing available clusters...
[INFO]  No running clusters found. Will create ephemeral job cluster.
   (This is cost-effective as cluster terminates after completion)

Preparing to run notebook: /Shared/config/01_create_company_config_table
Creating ephemeral job cluster for this run
[OK] Notebook run submitted successfully
Run ID: 253869264584483

Monitoring run 253869264584483...
Status: PENDING
Status: RUNNING
```

### Known Issues with Automated Method

**Issue**: Job clusters don't have storage access configured by default

**Error**: `Failure to initialize configuration for storage account stdldevshared77b5h3.dfs.core.windows.net`

**Reason**: Job clusters need either:
- Storage account access keys configured
- Managed Identity with RBAC permissions

**Solution**: Use manual method with existing cluster that has access configured

---

## Manual Upload Method (UI)

This is the **recommended method** for the first run.

### Step 1: Access Databricks Workspace

1. Open browser and navigate to:
   ```
   https://adb-3370863217573312.12.azuredatabricks.net
   ```

2. Sign in with your Azure credentials

### Step 2: Create Directory Structure

1. Click on **Workspace** in the left sidebar
2. Navigate to **Shared**
3. Right-click on **Shared** → **Create** → **Folder**
4. Name the folder: `config`
5. Click **Create**

Result: `/Shared/config/` directory created

### Step 3: Upload the Notebook

**Option A: Using Import Button**

1. Navigate to `/Shared/config/`
2. Click the dropdown arrow next to **config**
3. Select **Import**
4. Click **browse** or drag and drop
5. Select file: `C:\Users\User\Desktop\Delta_lake_project\databricks_notebooks\config\01_create_company_config_table.py`
6. Click **Import**

**Option B: Using Workspace Upload**

1. In Databricks workspace, click **Workspace** menu
2. Navigate to `/Shared/config/`
3. Click **↓** (down arrow) → **Import**
4. Choose **File**
5. Browse to: `C:\Users\User\Desktop\Delta_lake_project\databricks_notebooks\config\01_create_company_config_table.py`
6. Click **Import**

### Step 4: Verify Upload

1. Navigate to `/Shared/config/`
2. You should see: `01_create_company_config_table`
3. Click on it to open the notebook

---

## Running the Notebook

### Method 1: Using Existing Interactive Cluster (Recommended)

**Prerequisites**: One of the pod clusters must be running (podA-interactive, podB-interactive, or podC-interactive)

#### Step 1: Start a Cluster

1. Click **Compute** in left sidebar
2. Find one of the interactive clusters:
   - `podA-interactive`
   - `podB-interactive`
   - `podC-interactive`
3. If status is **TERMINATED**, click **Start**
4. Wait 3-5 minutes for cluster to reach **RUNNING** status

#### Step 2: Attach Notebook to Cluster

1. Open the notebook: `/Shared/config/01_create_company_config_table`
2. At the top, click the **Detached** dropdown
3. Select the running cluster (e.g., `podA-interactive`)
4. Wait for "Attached" confirmation

#### Step 3: Run the Notebook

1. Click **Run All** at the top of the notebook
2. Monitor execution in real-time
3. Each cell will show:
   - ⏳ Running (grey)
   - [DONE] Success (green)
   - [ERROR] Error (red)

#### Step 4: Monitor Progress

The notebook has multiple sections. Watch for:

```
Setup and Imports → [DONE]
Configuration Parameters → [DONE]
Enterprise Schema Definition → [DONE]
Initial Configuration Data → [DONE]
Create DataFrame with Validation → [DONE]
  - No duplicate company_ids [DONE]
  - All worker counts valid [DONE]
  - All companies have domains [DONE]
  - All priorities valid [DONE]
  - All classifications valid [DONE]
  - All autoscale configs valid [DONE]
Display Configuration Summary → [DONE]
Write Delta Table → [DONE]
Set Table Properties → [DONE]
Create Optimized Indexes → [DONE]
Verification and Testing → [DONE]
Query Examples → [DONE]
Create View → [DONE]
Export Configuration → [DONE]
Summary Report → [DONE]
```

#### Expected Runtime

- **Total time**: 2-4 minutes
- **Most time-consuming steps**:
  - Write Delta Table: ~30 seconds
  - Optimize table: ~20 seconds

### Method 2: Using Job Cluster (After Storage Access Fixed)

1. Open notebook: `/Shared/config/01_create_company_config_table`
2. Click **Run** dropdown → **Run as Job**
3. Configure job cluster specifications
4. Click **Run Now**

---

## Troubleshooting

### Issue 1: "Storage account access denied"

**Symptom**:
```
Failure to initialize configuration for storage account stdldevshared77b5h3.dfs.core.windows.net
```

**Cause**: Cluster doesn't have access to Azure Data Lake Storage

**Solution**:
1. Use an existing interactive cluster (podA/B/C-interactive)
2. These clusters have storage access pre-configured via managed identity

### Issue 2: "No clusters available"

**Symptom**: All clusters show as TERMINATED

**Solution**:
1. Go to **Compute** → Select any pod cluster
2. Click **Start**
3. Wait for **RUNNING** status
4. Return to notebook and attach to running cluster

### Issue 3: "ModuleNotFoundError: No module named 'delta'"

**Symptom**: Python import errors

**Cause**: Cluster doesn't have required libraries

**Solution**:
1. Use Databricks Runtime 13.3 LTS or higher
2. Delta Lake is pre-installed on DBR 13.3+

### Issue 4: "Path already exists"

**Symptom**:
```
AnalysisException: Path 'abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/config/companies' already exists
```

**Cause**: Table was already created in a previous run

**Solution**:
1. This is expected behavior if re-running
2. The notebook uses `mode("overwrite")` so it will replace the table
3. Or, comment out the write section and just run verification queries

### Issue 5: "Permission denied on gold container"

**Symptom**: Cannot write to gold layer

**Solution**:
1. Verify Databricks managed identity has "Storage Blob Data Contributor" role on storage account
2. Check in Azure Portal:
   - Storage Account: `stdldevshared77b5h3`
   - Access Control (IAM)
   - Role Assignments
   - Find Databricks workspace managed identity

---

## Verification

### Step 1: Check Notebook Output

At the end of execution, you should see:

```
================================================================================
COMPANY CONFIGURATION TABLE - CREATION SUMMARY
================================================================================

📍 Location: abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/config/companies
📊 Total Companies: 10
🏢 Pods Configured: 3
[DONE] Enabled Companies: 10
🔒 Data Classifications: 4
📋 Schema Version: 1.0.0
🌍 Environment: dev

[DONE] ENTERPRISE FEATURES ENABLED:
   • Change Data Feed (CDC) for audit trail
   • Column mapping for schema evolution
   • Partitioning by pod_id for performance
   • Z-ordering on enabled, priority, data_classification
   • Auto-optimize and auto-compaction
   • 90-day log retention for compliance
   • Comprehensive business and technical metadata

[DONE] READY FOR ADF INTEGRATION
================================================================================
```

### Step 2: Query the Table

Run this in a new notebook cell or Databricks SQL Editor:

```sql
-- View all companies
SELECT * FROM company_config
ORDER BY pod_id, company;

-- Count by pod
SELECT pod_id, COUNT(*) as company_count
FROM company_config
GROUP BY pod_id;

-- View enabled companies only
SELECT company_id, priority, sla_hours, data_classification
FROM company_config
WHERE enabled = true
ORDER BY priority DESC, sla_hours;
```

Expected results:
- 10 total companies
- 3 pods (podA: 4 companies, podB: 3 companies, podC: 3 companies)
- All companies enabled
- Priorities: HIGH (6), MEDIUM (3), LOW (1)

### Step 3: Verify in Azure Storage

```bash
# Using Azure CLI
az storage fs directory list \
  --account-name stdldevshared77b5h3 \
  --file-system gold \
  --path config/companies \
  --auth-mode login \
  --output table
```

Expected output:
- `_delta_log/` directory (Delta Lake transaction log)
- Multiple `.parquet` files (actual data)
- Partitioned by `pod_id` (subdirectories: pod_id=podA, pod_id=podB, pod_id=podC)

### Step 4: Test ADF Integration Query

This is the query ADF will use:

```sql
SELECT company_id, company, worker_count, domains, priority,
       driver_node_type, worker_node_type,
       autoscale_min_workers, autoscale_max_workers,
       spot_instances_enabled
FROM delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/config/companies`
WHERE pod_id = 'podA' AND enabled = true
ORDER BY priority DESC, company
```

Expected: 4 companies for podA (finance, operations, marketing, it)

---

## Post-Execution Checklist

- [ ] Notebook uploaded to `/Shared/config/01_create_company_config_table`
- [ ] Notebook executed successfully (all cells green)
- [ ] Table `company_config` exists and is queryable
- [ ] 10 companies created across 3 pods
- [ ] Delta files visible in `gold/config/companies/`
- [ ] Simplified view `vw_company_config_simple` created
- [ ] Configuration exported to JSON
- [ ] Ready to proceed with ADF pipeline configuration

---

## Next Steps

Now that the company configuration table is created:

1. **Configure ADF Linked Services**
   - Databricks linked service
   - Data Lake Gen2 linked service

2. **Build ForEach Pipeline**
   - Lookup activity to read company config
   - ForEach loop for parallel processing
   - Databricks notebook activities

3. **Test Pipeline**
   - Start with single company
   - Verify end-to-end flow
   - Enable all companies

---

## Reference

- **Notebook Location (Local)**: `C:\Users\User\Desktop\Delta_lake_project\databricks_notebooks\config\01_create_company_config_table.py`
- **Notebook Location (Databricks)**: `/Shared/config/01_create_company_config_table`
- **Table Name**: `company_config`
- **Table Path**: `abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/config/companies`
- **Documentation**: [Company Configuration Table](./19-company-configuration-table.md)

---

## Execution Summary

**What Was Done**:
1. [DONE] Created Python upload script (`upload_and_run_config_notebook.py`)
2. [DONE] Automated directory creation in Databricks workspace (`/Shared/config/`)
3. [DONE] Successfully uploaded notebook via REST API
4. [WARNING] Job cluster execution failed (storage access issue)
5. [DONE] Documented manual execution method using interactive clusters

**Current Status**:
- Notebook is uploaded and ready in Databricks workspace
- Manual execution using interactive cluster is recommended
- Interactive clusters have storage access pre-configured

**Recommended Action**:
Open Databricks workspace UI and run the notebook using an interactive cluster (podA/B/C-interactive).
