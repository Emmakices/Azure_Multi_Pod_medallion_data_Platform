# Pipeline Integration Guide - Hash Validation

## Overview

This guide shows how to integrate hash validation into your data pipeline orchestration. The validation must **pass before** any data processing begins.

---

## Integration Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. Data Upload                                                  │
│    - data_2025-10-28.zip uploaded to Azure Storage             │
│    - data_2025-10-28.hash uploaded to Azure Storage            │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Event Grid Trigger                                           │
│    - Blob Created event detected                                │
│    - Triggers Hash Validation Function                          │
└────────────────┬────────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. Hash Validation Function                                     │
│    - Downloads ZIP and hash file                                │
│    - Validates data integrity                                   │
│    - Returns: PASS or FAIL                                      │
└────────────────┬────────────────────────────────────────────────┘
                 │
         ┌───────┴───────┐
         │               │
         ▼               ▼
    [PASS]           [FAIL]
         │               │
         ▼               ▼
┌────────────────┐  ┌────────────────┐
│ 4a. Continue   │  │ 4b. Stop       │
│ - Trigger ADF  │  │ - Send Alert   │
│ - Run Bronze   │  │ - Log Error    │
│ - Run Silver   │  │ - Quarantine   │
│ - Run Gold     │  │ - Notify Team  │
└────────────────┘  └────────────────┘
```

---

## Option 1: Azure Data Factory (ADF) Pipeline (Recommended)

### Why This Option?
- Native Azure integration
- Visual pipeline designer
- Built-in error handling and retry logic
- Easy monitoring and logging
- Supports conditional execution

### Architecture

```
ADF Pipeline: "Data Processing with Validation"
├─ Web Activity: Call Validation API
│  └─ Output: {"status": "PASS", "exitCode": 0, ...}
├─ If Condition: Check status == "PASS"
│  ├─ TRUE Branch:
│  │  ├─ Copy Data Activity (Bronze Layer)
│  │  ├─ Databricks Notebook Activity (Bronze Processing)
│  │  ├─ Databricks Notebook Activity (Silver Processing)
│  │  └─ Databricks Notebook Activity (Gold Processing)
│  └─ FALSE Branch:
│     ├─ Move data to quarantine folder
│     ├─ Log error to monitoring table
│     └─ Send email alert
```

### Step-by-Step Implementation

#### Step 1: Create ADF Pipeline

**Azure Portal → Data Factory → Author → New Pipeline**

Pipeline Name: `pl_validate_and_process_data`

#### Step 2: Add Variables

Add pipeline parameters:
- `zipBlobName` (String) - e.g., "data_2025-10-28.zip"
- `containerName` (String) - e.g., "raw-data"
- `storageAccount` (String) - e.g., "stdldevshared77b5h3"

#### Step 3: Add Web Activity (Validation)

**Activity Name:** `act_validate_hash`

**Settings:**
- **URL:** `https://func-hash-validation-dev.azurewebsites.net/api/validatehash?code=<YOUR_FUNCTION_KEY>`
- **Method:** POST
- **Headers:**
  ```json
  {
    "Content-Type": "application/json"
  }
  ```
- **Body:** (Dynamic content using pipeline parameters)
  ```json
  [
    {
      "topic": "/subscriptions/e97fa8c6-457d-495f-aa82-0d87e72f5842/resourceGroups/rg-platform-dev/providers/Microsoft.Storage/storageAccounts/@{pipeline().parameters.storageAccount}",
      "subject": "/blobServices/default/containers/@{pipeline().parameters.containerName}/blobs/@{pipeline().parameters.zipBlobName}",
      "eventType": "Microsoft.Storage.BlobCreated",
      "eventTime": "@{utcnow()}",
      "id": "@{guid()}",
      "data": {
        "api": "PutBlob",
        "contentType": "application/x-zip-compressed",
        "blobType": "BlockBlob",
        "url": "https://@{pipeline().parameters.storageAccount}.blob.core.windows.net/@{pipeline().parameters.containerName}/@{pipeline().parameters.zipBlobName}"
      },
      "dataVersion": "",
      "metadataVersion": "1"
    }
  ]
  ```

#### Step 4: Add If Condition Activity

**Activity Name:** `act_check_validation_result`

**Expression:**
```javascript
@equals(activity('act_validate_hash').output.status, 'PASS')
```

**Depends On:** `act_validate_hash` (Success)

#### Step 5: Configure TRUE Branch (PASS)

Add these activities in sequence:

**5a. Copy Data Activity**
- **Name:** `act_copy_to_bronze`
- **Source:** Blob with validated ZIP
- **Sink:** Bronze container in Data Lake
- **Settings:** Extract ZIP files to individual blobs

**5b. Databricks Notebook Activity**
- **Name:** `act_run_bronze_notebook`
- **Notebook Path:** `/databricks_notebooks/ingestion/bronze_ingestion`
- **Base Parameters:**
  ```json
  {
    "file_path": "@{pipeline().parameters.zipBlobName}",
    "validation_status": "PASS"
  }
  ```

**5c. Databricks Notebook Activity**
- **Name:** `act_run_silver_notebook`
- **Notebook Path:** `/databricks_notebooks/transformation/silver_transformation`
- **Depends On:** `act_run_bronze_notebook` (Success)

**5d. Databricks Notebook Activity**
- **Name:** `act_run_gold_notebook`
- **Notebook Path:** `/databricks_notebooks/aggregation/gold_aggregation`
- **Depends On:** `act_run_silver_notebook` (Success)

#### Step 6: Configure FALSE Branch (FAIL)

Add these activities:

**6a. Copy Data Activity (Quarantine)**
- **Name:** `act_move_to_quarantine`
- **Source:** Failed ZIP blob
- **Sink:** `quarantine` container
- **Delete Source:** Yes (optional)

**6b. Stored Procedure Activity (Log Error)**
- **Name:** `act_log_validation_failure`
- **Stored Procedure:** `sp_log_validation_failure`
- **Parameters:**
  ```json
  {
    "fileName": "@{pipeline().parameters.zipBlobName}",
    "validationResult": "@{activity('act_validate_hash').output}",
    "timestamp": "@{utcnow()}",
    "errorMessage": "@{activity('act_validate_hash').output.message}"
  }
  ```

**6c. Web Activity (Send Alert)**
- **Name:** `act_send_email_alert`
- **URL:** Your notification endpoint (Logic App, SendGrid, etc.)
- **Method:** POST
- **Body:**
  ```json
  {
    "subject": "Data Validation Failed: @{pipeline().parameters.zipBlobName}",
    "body": "Validation failed with status: @{activity('act_validate_hash').output.status}\n\nDetails: @{activity('act_validate_hash').output.validationDetails}",
    "priority": "high"
  }
  ```

---

## Option 2: Databricks Notebook Control

If you prefer Databricks-native orchestration:

### Step 1: Create Validation Check Notebook

**File:** `databricks_notebooks/shared_notebooks/check_validation.py`

```python
# Databricks notebook source
import requests
import json
import sys

# COMMAND ----------

# Parameters
dbutils.widgets.text("zip_file_name", "", "ZIP File Name")
dbutils.widgets.text("container_name", "", "Container Name")
dbutils.widgets.text("storage_account", "", "Storage Account")

zip_file_name = dbutils.widgets.get("zip_file_name")
container_name = dbutils.widgets.get("container_name")
storage_account = dbutils.widgets.get("storage_account")

# COMMAND ----------

# Azure Function configuration
function_url = "https://func-hash-validation-dev.azurewebsites.net/api/validatehash"
function_key = dbutils.secrets.get(scope="keyvault-scope", key="validation-function-key")

# COMMAND ----------

# Build Event Grid event
event_payload = [{
    "topic": f"/subscriptions/e97fa8c6-457d-495f-aa82-0d87e72f5842/resourceGroups/rg-platform-dev/providers/Microsoft.Storage/storageAccounts/{storage_account}",
    "subject": f"/blobServices/default/containers/{container_name}/blobs/{zip_file_name}",
    "eventType": "Microsoft.Storage.BlobCreated",
    "eventTime": "2025-10-28T00:00:00.0000000Z",
    "id": "validation-check",
    "data": {
        "api": "PutBlob",
        "contentType": "application/x-zip-compressed",
        "blobType": "BlockBlob",
        "url": f"https://{storage_account}.blob.core.windows.net/{container_name}/{zip_file_name}"
    },
    "dataVersion": "",
    "metadataVersion": "1"
}]

# COMMAND ----------

# Call validation API
try:
    response = requests.post(
        f"{function_url}?code={function_key}",
        headers={"Content-Type": "application/json"},
        json=event_payload,
        timeout=300  # 5 minutes
    )

    validation_result = response.json()

    print(f"Validation Status: {validation_result['status']}")
    print(f"Exit Code: {validation_result['exitCode']}")
    print(f"Files Extracted: {validation_result['filesExtracted']}")
    print(f"OK Count: {validation_result['okCount']}")
    print(f"Fail Count: {validation_result['failCount']}")
    print(f"\nValidation Details:\n{validation_result['validationDetails']}")

    # Store result for downstream notebooks
    dbutils.jobs.taskValues.set(key="validation_status", value=validation_result['status'])
    dbutils.jobs.taskValues.set(key="validation_exit_code", value=validation_result['exitCode'])

    # CRITICAL: Exit with error if validation failed
    if validation_result['status'] != 'PASS':
        print("\n" + "="*60)
        print("❌ VALIDATION FAILED - STOPPING PIPELINE")
        print("="*60)
        dbutils.notebook.exit(json.dumps({
            "status": "FAILED",
            "reason": "Hash validation failed",
            "details": validation_result
        }))

    print("\n" + "="*60)
    print("✅ VALIDATION PASSED - PROCEEDING WITH PIPELINE")
    print("="*60)

    dbutils.notebook.exit(json.dumps({
        "status": "SUCCESS",
        "validation_result": validation_result
    }))

except Exception as e:
    print(f"❌ Error calling validation API: {str(e)}")
    dbutils.notebook.exit(json.dumps({
        "status": "ERROR",
        "reason": str(e)
    }))
    sys.exit(1)
```

### Step 2: Create Master Orchestration Notebook

**File:** `databricks_notebooks/orchestration/master_pipeline.py`

```python
# Databricks notebook source
import json

# COMMAND ----------

# Parameters
dbutils.widgets.text("zip_file_name", "", "ZIP File Name")
zip_file_name = dbutils.widgets.get("zip_file_name")

# COMMAND ----------

print("="*80)
print("STEP 1: HASH VALIDATION")
print("="*80)

# Run validation check
try:
    validation_result_json = dbutils.notebook.run(
        "/shared_notebooks/check_validation",
        timeout_seconds=600,  # 10 minutes
        arguments={
            "zip_file_name": zip_file_name,
            "container_name": "raw-data",
            "storage_account": "stdldevshared77b5h3"
        }
    )

    validation_result = json.loads(validation_result_json)

    if validation_result['status'] != 'SUCCESS':
        print("❌ Validation failed. Pipeline stopped.")
        raise Exception(f"Validation failed: {validation_result['reason']}")

    print("✅ Validation passed. Proceeding to data processing...")

except Exception as e:
    print(f"❌ Pipeline failed at validation stage: {str(e)}")
    # Log to monitoring table
    spark.sql(f"""
        INSERT INTO monitoring.pipeline_failures
        VALUES (
            current_timestamp(),
            '{zip_file_name}',
            'VALIDATION',
            '{str(e)}'
        )
    """)
    raise

# COMMAND ----------

print("="*80)
print("STEP 2: BRONZE LAYER INGESTION")
print("="*80)

try:
    bronze_result = dbutils.notebook.run(
        "/ingestion/bronze_ingestion",
        timeout_seconds=1800,
        arguments={"file_path": zip_file_name}
    )
    print("✅ Bronze ingestion completed")
except Exception as e:
    print(f"❌ Bronze ingestion failed: {str(e)}")
    raise

# COMMAND ----------

print("="*80)
print("STEP 3: SILVER LAYER TRANSFORMATION")
print("="*80)

try:
    silver_result = dbutils.notebook.run(
        "/transformation/silver_transformation",
        timeout_seconds=1800,
        arguments={"source": "bronze"}
    )
    print("✅ Silver transformation completed")
except Exception as e:
    print(f"❌ Silver transformation failed: {str(e)}")
    raise

# COMMAND ----------

print("="*80)
print("STEP 4: GOLD LAYER AGGREGATION")
print("="*80)

try:
    gold_result = dbutils.notebook.run(
        "/aggregation/gold_aggregation",
        timeout_seconds=1800,
        arguments={"source": "silver"}
    )
    print("✅ Gold aggregation completed")
except Exception as e:
    print(f"❌ Gold aggregation failed: {str(e)}")
    raise

# COMMAND ----------

print("="*80)
print("✅ PIPELINE COMPLETED SUCCESSFULLY")
print("="*80)
```

---

## Option 3: Event Grid with Custom Topics

For fully event-driven architecture:

### Architecture
```
Blob Upload → Event Grid → Validation Function
                                   ↓
                          Publish to Custom Topic
                                   ↓
                   ┌───────────────┴───────────────┐
                   │                               │
                   ▼                               ▼
            [PASS Event]                    [FAIL Event]
                   │                               │
           ┌───────┴───────┐                       ├─ Alert Logic App
           │               │                       └─ Quarantine Function
           ▼               ▼
    ADF Pipeline    Databricks Job
```

### Implementation (Event Grid Custom Topic)

This requires modifying the Azure Function to publish results to a custom topic.

**Modify:** `azure_function/ValidateHash/run.ps1`

Add at the end (before returning response):

```powershell
# Publish to Event Grid Custom Topic
$eventGridEndpoint = $env:EVENT_GRID_ENDPOINT
$eventGridKey = $env:EVENT_GRID_KEY

if ($eventGridEndpoint -and $eventGridKey) {
    $customEvent = @{
        id = [Guid]::NewGuid().ToString()
        eventType = "DataValidation.$status"
        subject = "/validation/$($blobName)"
        eventTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        data = $result
        dataVersion = "1.0"
    }

    $eventBody = ConvertTo-Json @($customEvent) -Depth 10

    Invoke-RestMethod -Uri $eventGridEndpoint `
                      -Method POST `
                      -Headers @{"aeg-sas-key" = $eventGridKey} `
                      -Body $eventBody `
                      -ContentType "application/json"
}
```

---

## Option 4: Simple Status Check API

For existing pipelines that just need a go/no-go check:

### Create Status Check Endpoint

**File:** `azure_function/CheckValidationStatus/run.ps1`

```powershell
using namespace System.Net

param($Request, $TriggerMetadata)

$blobName = $Request.Query.blobName

# Query validation results from storage table or blob
# (You'd need to store validation results somewhere)
$validationStatus = Get-ValidationStatus -BlobName $blobName

if ($validationStatus.status -eq "PASS") {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = 200
        Body = @{
            canProceed = $true
            status = "PASS"
        }
    })
} else {
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = 200
        Body = @{
            canProceed = $false
            status = "FAIL",
            reason = $validationStatus.message
        }
    })
}
```

### Usage in Pipeline

```python
# At start of pipeline
import requests

response = requests.get(
    "https://func-hash-validation-dev.azurewebsites.net/api/checkstatus",
    params={"blobName": "data_2025-10-28.zip"}
)

result = response.json()

if not result['canProceed']:
    raise Exception(f"Cannot proceed: {result['reason']}")

# Continue with pipeline...
```

---

## Recommended Approach Based on Your Setup

Based on your current architecture (ADF + Databricks), I recommend:

### **Hybrid Approach:**

1. **Event Grid** triggers validation function when ZIP uploaded
2. **Validation Function** returns PASS/FAIL
3. **ADF Pipeline** (triggered by Event Grid or schedule):
   - Calls validation API via Web Activity
   - Checks result with If Condition
   - Runs Databricks notebooks only if PASS
4. **Databricks notebooks** can also call validation for manual runs

---

## Monitoring and Alerting

### Create Monitoring Table

```sql
CREATE TABLE IF NOT EXISTS monitoring.validation_results (
    validation_timestamp TIMESTAMP,
    blob_name STRING,
    status STRING,
    exit_code INT,
    files_extracted INT,
    ok_count INT,
    fail_count INT,
    missing_count INT,
    extra_count INT,
    validation_details STRING,
    pipeline_triggered BOOLEAN,
    pipeline_status STRING
)
USING DELTA
LOCATION 'abfss://monitoring@<storage>.dfs.core.windows.net/validation_results';
```

### Log Every Validation

Add to your pipeline (ADF or Databricks):

```python
from datetime import datetime

spark.sql(f"""
    INSERT INTO monitoring.validation_results VALUES (
        '{datetime.now()}',
        '{zip_file_name}',
        '{validation_result["status"]}',
        {validation_result["exitCode"]},
        {validation_result["filesExtracted"]},
        {validation_result["okCount"]},
        {validation_result["failCount"]},
        {validation_result["missingCount"]},
        {validation_result["extraCount"]},
        '{validation_result["validationDetails"]}',
        true,
        'RUNNING'
    )
""")
```

### Create Dashboard

Query for monitoring:

```sql
-- Daily validation summary
SELECT
    DATE(validation_timestamp) as date,
    COUNT(*) as total_validations,
    SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) as passed,
    SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) as failed
FROM monitoring.validation_results
GROUP BY DATE(validation_timestamp)
ORDER BY date DESC;

-- Recent failures
SELECT *
FROM monitoring.validation_results
WHERE status = 'FAIL'
ORDER BY validation_timestamp DESC
LIMIT 10;
```

---

## Testing the Integration

### Test Scenario 1: PASS → Pipeline Runs

```bash
# 1. Upload valid data
az storage blob upload --account-name stdldevshared77b5h3 --container-name raw-data --name test_data.zip --file valid_data.zip
az storage blob upload --account-name stdldevshared77b5h3 --container-name raw-data --name test_data.hash --file valid_data.hash

# 2. Trigger ADF pipeline (manual for testing)
az datafactory pipeline create-run --factory-name <adf-name> --name pl_validate_and_process_data --parameters zipBlobName="test_data.zip"

# 3. Expected: Pipeline completes, data in Gold layer
```

### Test Scenario 2: FAIL → Pipeline Stops

```bash
# 1. Upload corrupted data
az storage blob upload --account-name stdldevshared77b5h3 --container-name raw-data --name bad_data.zip --file corrupted_data.zip
az storage blob upload --account-name stdldevshared77b5h3 --container-name raw-data --name bad_data.hash --file valid_hashes.hash

# 2. Trigger ADF pipeline
az datafactory pipeline create-run --factory-name <adf-name> --name pl_validate_and_process_data --parameters zipBlobName="bad_data.zip"

# 3. Expected: Pipeline stops at validation, alert sent, data quarantined
```

---

## Next Steps

1. **Choose your integration method** (I recommend Option 1: ADF Pipeline)
2. **Create the monitoring table** in Databricks
3. **Set up the ADF pipeline** following Step-by-Step Implementation
4. **Configure alerts** for validation failures
5. **Test both scenarios** (PASS and FAIL)
6. **Deploy to production** after successful testing

---

**Document Version:** 1.0
**Last Updated:** 2025-10-28
**Related Docs:** QUICK_START_GUIDE.md, IMPLEMENTATION_GUIDE.md
