# Proposed Solution Architecture

**Last Updated**: 2025-01-17
**Status**: DRAFT - Pending information from user

---

## Solution Overview

Replace manual, error-prone process with fully automated, event-driven pipeline that validates data integrity, processes files, and provides comprehensive logging.

**Key Principles**:
- Zero manual intervention
- Hash validation before processing
- Comprehensive logging at every step
- Event-driven automation
- Cost-optimized architecture
- Production-ready monitoring

---

## Modernized Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     AUTOMATED PIPELINE ARCHITECTURE                      │
└─────────────────────────────────────────────────────────────────────────┘

Government of Canada → Microsoft → Azure Blob Storage (dflink)
                                    ├─ data.zip
                                    └─ data.zip.hash
                                           |
                                           | [AUTOMATIC]
                                           | Event Grid Trigger
                                           v
                                    ADF Pipeline: Validate & Extract
                                           |
                                    ┌──────┴──────┐
                                    |             |
                                    v             v
                            Hash Validation   If Fail
                            (Azure Function)     |
                                    |            v
                                    |      Alert + Log + STOP
                            If Pass |
                                    v
                            Unzip File
                            (Azure Function or Databricks)
                                    |
                                    v
                            Determine Routing
                            (Parse file name)
                                    |
                        ┌───────────┴───────────┐
                        v                       v
                day_force_templates/psps   day_force_templates/sspc
                        |                       |
                        └───────────┬───────────┘
                                    |
                                    v
                            Trigger ENTRY HR Pipeline
                                    |
                                    v
                            ENTRY HR (Enhanced Logging)
                            ├─ Iterate files/folders
                            └─ Log each iteration
                                    |
                                    v
                            CORE HR (Enhanced Logging)
                            ├─ Extract Excel sheets
                            ├─ Load to database
                            └─ Log row counts
                                    |
                                    v
                            Database Tables + Comprehensive Logs
                                    |
                                    v
                            Monitoring Dashboard + Alerts
```

---

## Component Design

### 1. Event Grid Trigger

**Purpose**: Automatically detect file arrivals

**Configuration**:
```json
{
    "source": "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Storage/storageAccounts/{account}",
    "subject": "/blobServices/default/containers/dflink/blobs/*.zip",
    "eventType": "Microsoft.Storage.BlobCreated",
    "destination": {
        "endpointType": "AzureFunction",
        "properties": {
            "resourceId": "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Web/sites/{function-app}/functions/ValidateAndExtract"
        }
    },
    "filter": {
        "includedEventTypes": ["Microsoft.Storage.BlobCreated"],
        "subjectBeginsWith": "/blobServices/default/containers/dflink/blobs/",
        "subjectEndsWith": ".zip"
    }
}
```

**Trigger Logic**:
1. Monitor dflink container for `.zip` files
2. When ZIP arrives, trigger Azure Function
3. Pass blob URL as parameter

**Questions to Resolve**:
- Should we wait for both ZIP and hash file before triggering?
- Or trigger on ZIP and function checks for hash file?

---

### 2. Hash Validation Component

**Option A: Azure Function (Recommended)**

**Why**:
- Serverless, cost-effective
- Fast execution (< 1 minute for typical files)
- Easy to integrate with Event Grid
- Can reuse PowerShell logic in C#/Python

**Function Code Structure** (Python example):
```python
import hashlib
import json
import logging
from azure.storage.blob import BlobServiceClient
from azure.data.tables import TableServiceClient

def calculate_hash(blob_data, algorithm='sha256'):
    """Calculate hash of blob data"""
    hash_obj = hashlib.new(algorithm)
    hash_obj.update(blob_data)
    return hash_obj.hexdigest()

def main(event: dict) -> dict:
    """
    Azure Function triggered by Event Grid when ZIP file arrives

    Returns:
        dict: Validation result
    """
    logging.info("Hash validation started")

    # Extract file info from event
    blob_url = event['data']['url']
    file_name = event['data']['url'].split('/')[-1]

    # Initialize blob client
    blob_client = BlobServiceClient.from_connection_string(
        os.environ['STORAGE_CONNECTION_STRING']
    ).get_blob_client(container='dflink', blob=file_name)

    # Download ZIP file
    zip_data = blob_client.download_blob().readall()

    # Get hash file
    hash_file_name = f"{file_name}.sha256"  # Adjust based on actual naming
    hash_blob_client = BlobServiceClient.from_connection_string(
        os.environ['STORAGE_CONNECTION_STRING']
    ).get_blob_client(container='dflink', blob=hash_file_name)

    try:
        expected_hash = hash_blob_client.download_blob().readall().decode('utf-8').strip()
    except Exception as e:
        logging.error(f"Hash file not found: {hash_file_name}")
        return {
            'status': 'FAILED',
            'reason': 'HASH_FILE_NOT_FOUND',
            'file': file_name,
            'error': str(e)
        }

    # Calculate actual hash
    calculated_hash = calculate_hash(zip_data, algorithm='sha256')

    # Compare
    validation_passed = (calculated_hash.lower() == expected_hash.lower())

    # Log result to table storage or database
    log_validation_result(
        file_name=file_name,
        expected_hash=expected_hash,
        calculated_hash=calculated_hash,
        result='PASS' if validation_passed else 'FAIL'
    )

    if validation_passed:
        logging.info(f"Validation PASSED for {file_name}")
        # Trigger unzip function
        return {
            'status': 'SUCCESS',
            'file': file_name,
            'blob_url': blob_url,
            'proceed_to_unzip': True
        }
    else:
        logging.error(f"Validation FAILED for {file_name}")
        # Send alert
        send_alert(
            subject=f"Hash Validation Failed: {file_name}",
            body=f"Expected: {expected_hash}\nCalculated: {calculated_hash}"
        )
        return {
            'status': 'FAILED',
            'reason': 'HASH_MISMATCH',
            'file': file_name,
            'expected_hash': expected_hash,
            'calculated_hash': calculated_hash
        }
```

**Cost Estimate**:
- Execution time: ~30 seconds per file
- Cost per execution: ~$0.000001
- Monthly (assuming 100 files): ~$0.0001

**Option B: Databricks Notebook**
- More expensive
- Only needed if files > 1GB
- Can reuse POC infrastructure

---

### 3. File Extraction Component

**Option A: Azure Function (If ZIP < 100MB)**

**Function Code**:
```python
import zipfile
import io
from azure.storage.blob import BlobServiceClient

def unzip_to_blob(zip_blob_url, target_container, target_folder):
    """
    Unzip blob and upload contents to target location
    """
    # Download ZIP
    blob_client = BlobServiceClient...get_blob_client(...)
    zip_data = blob_client.download_blob().readall()

    # Unzip in memory
    with zipfile.ZipFile(io.BytesIO(zip_data)) as zip_ref:
        for file_info in zip_ref.filelist:
            if not file_info.is_dir():
                # Extract file
                file_data = zip_ref.read(file_info.filename)

                # Upload to target
                target_blob = f"{target_folder}/{file_info.filename}"
                target_client = BlobServiceClient...get_blob_client(
                    container=target_container,
                    blob=target_blob
                )
                target_client.upload_blob(file_data, overwrite=True)

                logging.info(f"Extracted: {file_info.filename} → {target_blob}")
```

**Option B: Databricks Notebook (If ZIP > 100MB or timeout issues)**

---

### 4. Dynamic Routing Logic

**Parse file name to determine destination**:

```python
def determine_routing(zip_file_name):
    """
    Parse ZIP file name to determine company and data type

    Examples:
        PSPS_HR_2025-01-17.zip → psps/HR/
        SSPC_Payroll_2025-01-17.zip → sspc/Payroll/

    Returns:
        tuple: (company, data_type)
    """
    # Remove .zip extension
    name = zip_file_name.replace('.zip', '')

    # Split by underscore
    parts = name.split('_')

    if len(parts) >= 2:
        company = parts[0].lower()  # 'psps' or 'sspc'
        data_type = parts[1]  # 'HR' or 'Payroll'

        return (company, data_type)
    else:
        raise ValueError(f"Unable to parse file name: {zip_file_name}")

# Usage
company, data_type = determine_routing("PSPS_HR_2025-01-17.zip")
target_folder = f"{company}/{data_type}"  # "psps/HR"
```

**NOTE**: This assumes file naming convention. Need to confirm with user.

---

### 5. Enhanced ADF Pipelines

**Modifications to ENTRY HR Pipeline**:
- Add logging at start
- Log each file/folder iteration
- Log completion
- Add error handling

**Modifications to CORE HR Pipeline**:
- Add logging before sheet extraction
- Log row counts per sheet
- Log table creation success/failure
- Add data quality checks

**New Activities to Add**:
```json
{
    "name": "Log_Pipeline_Start",
    "type": "Script",
    "typeProperties": {
        "scripts": [{
            "type": "Query",
            "text": "INSERT INTO pipeline_execution_log ..."
        }]
    }
}
```

---

### 6. Comprehensive Logging System

**Logging Tables** (Azure SQL Database or Synapse):

```sql
-- See full schema in requirements doc
CREATE TABLE pipeline_execution_log (...);
CREATE TABLE hash_validation_log (...);
CREATE TABLE file_processing_log (...);
CREATE TABLE activity_log (...);
```

**Logging Strategy**:
1. Azure Function writes to hash_validation_log
2. ADF writes to pipeline_execution_log at start
3. ADF writes to activity_log for each activity
4. CORE HR writes to file_processing_log for each sheet
5. All errors logged to respective tables

**Dual Logging**:
- Database tables (queryable, long-term retention)
- Azure Log Analytics (real-time monitoring, dashboards)

---

### 7. CI/CD Pipeline

**Azure DevOps YAML Pipeline**:

```yaml
# Filename: azure-pipelines-adf.yml

trigger:
  branches:
    include:
      - main
  paths:
    include:
      - adf/*

variables:
  - group: ADF-Variables

stages:
  - stage: Validate
    jobs:
      - job: ValidateJSON
        steps:
          - task: PowerShell@2
            displayName: 'Validate ADF JSON Files'
            inputs:
              targetType: 'inline'
              script: |
                Get-ChildItem -Path $(Build.SourcesDirectory)/adf -Filter *.json -Recurse | ForEach-Object {
                  try {
                    $json = Get-Content $_.FullName | ConvertFrom-Json
                    Write-Host "✓ Valid: $($_.Name)"
                  } catch {
                    Write-Error "✗ Invalid JSON: $($_.Name)"
                    exit 1
                  }
                }

  - stage: DeployDev
    dependsOn: Validate
    condition: succeeded()
    jobs:
      - deployment: DeployToDevice
        environment: 'ADF-Dev'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: AzureResourceManagerTemplateDeployment@3
                  displayName: 'Deploy ADF to Dev'
                  inputs:
                    deploymentScope: 'Resource Group'
                    azureResourceManagerConnection: 'ADF-ServiceConnection-Dev'
                    subscriptionId: '$(DevSubscriptionId)'
                    resourceGroupName: '$(DevResourceGroup)'
                    location: 'Canada Central'
                    templateLocation: 'Linked artifact'
                    csmFile: '$(Build.SourcesDirectory)/adf/ARMTemplateForFactory.json'
                    csmParametersFile: '$(Build.SourcesDirectory)/adf/ARMTemplateParametersForFactory.json'
                    overrideParameters: '-factoryName "$(DevFactoryName)"'

  - stage: DeployProd
    dependsOn: DeployDev
    condition: succeeded()
    jobs:
      - deployment: DeployToProduction
        environment: 'ADF-Prod'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: ManualValidation@0
                  displayName: 'Await Manager Approval'
                  inputs:
                    notifyUsers: 'manager@company.com'
                    instructions: 'Please review dev deployment and approve production deployment'
                    onTimeout: 'reject'

                - task: AzureResourceManagerTemplateDeployment@3
                  displayName: 'Deploy ADF to Prod'
                  inputs:
                    deploymentScope: 'Resource Group'
                    azureResourceManagerConnection: 'ADF-ServiceConnection-Prod'
                    subscriptionId: '$(ProdSubscriptionId)'
                    resourceGroupName: '$(ProdResourceGroup)'
                    location: 'Canada Central'
                    templateLocation: 'Linked artifact'
                    csmFile: '$(Build.SourcesDirectory)/adf/ARMTemplateForFactory.json'
                    csmParametersFile: '$(Build.SourcesDirectory)/adf/ARMTemplateParametersForFactory.json'
                    overrideParameters: '-factoryName "$(ProdFactoryName)"'
```

---

## Technology Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| File Trigger | Azure Event Grid | Event-driven, cost-effective |
| Hash Validation | Azure Function (Python) | Serverless, fast, cheap |
| File Extraction | Azure Function or Databricks | Based on file size |
| Orchestration | Azure Data Factory | Existing investment, visual designer |
| Processing | ADF (ENTRY HR, CORE HR) | Keep what works, add logging |
| Logging | Azure SQL Database | Queryable, relational |
| Monitoring | Azure Log Analytics + Dashboards | Real-time monitoring |
| CI/CD | Azure DevOps Pipelines | Standard Microsoft stack |
| Alerts | Azure Monitor Action Groups | Email, Teams, SMS |

---

## Cost Estimate (Monthly)

**Assumptions**: 100 files/month, 50MB average ZIP size

| Component | Monthly Cost |
|-----------|--------------|
| Event Grid | $0.60 (10,000 events) |
| Azure Function (hash validation) | $0.01 |
| Azure Function (unzip) | $0.05 |
| ADF Pipeline Runs | $10.00 (100 runs) |
| Azure SQL Database (logging) | $15.00 (Basic tier) |
| Log Analytics | $5.00 |
| Storage (blobs) | $3.00 |
| **Total** | **~$33.66/month** |

**Cost Savings**:
- Eliminate F:\ drive VM: -$50-100/month (est.)
- **Net Savings: ~$20-70/month**

---

## Success Metrics

| Metric | Target | How Measured |
|--------|--------|--------------|
| Automation Rate | 100% | No manual steps from file arrival to DB load |
| Hash Validation Success | 100% | All files validated before processing |
| Processing Time | < 15 min | Time from file arrival to data in DB |
| Error Detection | < 5 min | Time from error to alert sent |
| Logging Coverage | 100% | Every activity logged with timestamp |
| Deployment Time | < 10 min | ADO commit to ADF deployment complete |
| Uptime | > 99.5% | Pipeline availability |

---

## Open Questions (Need User Input)

1. **PowerShell script content** - Critical for hash validation design
2. **File naming conventions** - Critical for routing logic
3. **Hash algorithm** - Critical for validation
4. **Typical file sizes** - Determines function vs Databricks choice
5. **Database details** - Needed for logging setup
6. **Alert recipients** - Who gets notified?
7. **ADO repository structure** - For CI/CD setup

---

**Next Step**: Once critical information received, finalize design and begin POC implementation.
