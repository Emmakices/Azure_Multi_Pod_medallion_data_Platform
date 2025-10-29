# Requirements & Challenges

**Last Updated**: 2025-01-17
**Source**: Manager's urgent request

---

## Business Requirements

### 1. Hash Validation (CRITICAL)

**Requirement**:
When data arrives as a zipped file from Microsoft, a hash file accompanies it. Need to validate the ZIP file using the hash to ensure data integrity BEFORE unzipping and processing.

**Current State**:
- No validation happening
- Files are manually downloaded, extracted, and processed without integrity checks
- Risk of processing corrupted or tampered data

**Desired State**:
- Automated hash validation on file arrival
- If hash matches: Proceed with unzipping and processing
- If hash fails: Stop pipeline, send alert with reason, log failure
- All validation results logged

**PowerShell Script**:
- Team has existing PowerShell script for hash validation
- Need to integrate into ADF pipeline
- [PENDING: Get script from user]

**Questions**:
- What hash algorithm? (MD5, SHA256, SHA512?)
- Hash file format? (e.g., `data.zip.sha256` or embedded in manifest?)
- Where to log validation results?
- Who gets alerted on validation failure?
- What should alert contain?

---

### 2. Automated Unzipping & Upload (HIGH PRIORITY)

**Requirement**:
Eliminate manual process of downloading to F:\ drive, extracting, and uploading to blob storage. Make this fully automated.

**Current State**:
```
[MANUAL] Download ZIP from dflink → F:\ drive
[MANUAL] Extract ZIP on F:\ drive
[MANUAL] Upload extracted files to day_force_templates
[MANUAL] Trigger ADF pipeline
```

**Desired State**:
```
[AUTOMATIC] File arrives in dflink
[AUTOMATIC] Hash validation
[AUTOMATIC] Unzip directly to day_force_templates (correct folder)
[AUTOMATIC] Trigger ENTRY HR pipeline
```

**Benefits**:
- Eliminate F:\ drive VM (cost savings)
- Faster processing (no human intervention)
- Consistent routing (no human error)
- Audit trail of all operations

**Questions**:
- How to determine company (psps vs sspc) from ZIP file name?
- How to determine data type (HR vs Payroll) from ZIP contents?
- What happens if ZIP contains unexpected structure?

---

### 3. Comprehensive Logging (HIGH PRIORITY)

**Requirement**:
Replace debug mode logging with production-ready comprehensive logging system that tracks every activity with timestamps.

**Current State**:
- Using ADF debug mode for logging
- No centralized log storage
- No activity-level timestamps
- No error tracking
- No data quality metrics

**Desired State**:
- Pipeline execution log (start, end, duration, status)
- Activity-level logs (each step with timestamps)
- Hash validation results
- File processing metrics (row counts, sheets processed)
- Error details with stack traces
- Data quality checks
- SLA monitoring

**Log Storage Options**:
1. Azure Log Analytics workspace
2. Database tables (like POC logging tables)
3. Both (recommended)

**Questions**:
- Where should logs be stored?
- How long to retain logs?
- Who needs access to logs?
- Do you need real-time dashboards?
- What metrics are most important?

---

### 4. CI/CD for ADF (MEDIUM PRIORITY)

**Requirement**:
When developers make changes in Azure DevOps (ADO) repository, changes should automatically sync to ADF. Currently need to make changes twice (once in ADO, once in ADF).

**Current State**:
```
Developer makes change in ADO repo
   ↓
[MANUAL] Developer opens ADF Studio
   ↓
[MANUAL] Developer makes same change in ADF
   ↓
[MANUAL] Developer publishes in ADF
   ↓
Change deployed
```

**Desired State**:
```
Developer commits change to ADO repo
   ↓
[AUTOMATIC] Azure DevOps Pipeline triggers
   ↓
[AUTOMATIC] Validates ADF JSON
   ↓
[AUTOMATIC] Deploys to dev environment
   ↓
[MANUAL] Approval for test environment
   ↓
[AUTOMATIC] Deploys to test environment
   ↓
[MANUAL] Approval for production
   ↓
[AUTOMATIC] Deploys to production
```

**Questions**:
- Do you have ADO repository with ADF pipelines?
- Do you have service principal for ADF deployments?
- How many environments? (dev, test, prod?)
- Who approves production deployments?
- Are there linked services that need different configs per environment?

---

### 5. Event-Driven Triggering (HIGH PRIORITY)

**Requirement**:
Pipeline should automatically trigger when file arrives, not wait for manual execution.

**Current State**:
- User manually runs pipeline in debug mode

**Desired State**:
- Azure Event Grid trigger on blob storage
- Fires when `.zip` file lands in dflink container
- Automatically starts validation pipeline

**Implementation**:
```
Azure Event Grid
   ↓
Monitors: dflink container
   ↓
Event: Microsoft.Storage.BlobCreated
   ↓
Filter: *.zip files
   ↓
Action: Trigger ADF pipeline with file path parameter
```

**Questions**:
- Should trigger fire immediately on file arrival?
- Or wait for both ZIP + hash file to arrive?
- What if only ZIP arrives without hash file?

---

## Technical Challenges

### Challenge 1: Hash Validation in ADF

**Problem**: ADF doesn't have built-in hash validation activity

**Options**:
1. **Azure Function** (Recommended)
   - Trigger on blob creation
   - Calculate hash using C#/Python
   - Compare with hash file
   - Return success/failure to ADF
   - Pros: Serverless, scalable, cost-effective
   - Cons: Additional component to maintain

2. **Databricks Notebook**
   - Use Python hashlib library
   - Calculate and compare hashes
   - Pros: Familiar environment (we use in POC)
   - Cons: Overkill for simple hash check, more expensive

3. **ADF Web Activity + Custom API**
   - Call custom validation API
   - Pros: Centralized validation logic
   - Cons: Need to build and host API

4. **PowerShell Script in Azure Automation**
   - Run existing PowerShell script
   - Pros: Reuse existing script
   - Cons: Azure Automation costs, scheduling complexity

**Recommendation**: Azure Function (Option 1)
- Best balance of cost, performance, and maintainability
- Can reuse PowerShell logic in C# or Python

---

### Challenge 2: Unzipping Files in Azure

**Problem**: ADF Copy Activity can't unzip files

**Options**:
1. **Azure Function** (Recommended)
   - Triggered after successful hash validation
   - Unzip file to target container
   - Pros: Serverless, fast, cost-effective
   - Cons: Azure Function 5-minute execution limit (check ZIP size)

2. **Databricks Notebook**
   - Use Python zipfile library
   - Unzip and write to blob storage
   - Pros: No time limit, handles large files
   - Cons: More expensive (ephemeral cluster cost)

3. **Azure Logic Apps**
   - Has unzip connector
   - Pros: Low-code, visual designer
   - Cons: Limited to 100MB files

4. **ADF Data Flow**
   - Can decompress files
   - Pros: Native ADF component
   - Cons: Expensive, overkill for simple unzip

**Recommendation**:
- If ZIP files < 100MB: Azure Function (Option 1)
- If ZIP files > 100MB: Databricks Notebook (Option 2)

**Question**: What's the typical ZIP file size?

---

### Challenge 3: Dynamic Folder Routing

**Problem**: Need to automatically route files to correct folder (psps vs sspc, HR vs Payroll)

**Options**:
1. **File naming convention**
   - ZIP file name contains company and type
   - Example: `PSPS_HR_2025-01-17.zip`
   - Parse name to determine routing
   - Pros: Simple, reliable
   - Cons: Requires consistent naming from source

2. **Metadata file inside ZIP**
   - Include manifest.json with routing info
   - Example: `{"company": "psps", "type": "HR"}`
   - Pros: Flexible, doesn't rely on file name
   - Cons: Need to peek inside ZIP before full extraction

3. **Manual configuration table**
   - Lookup table maps file name patterns to folders
   - Pros: Flexible, can change routing without code changes
   - Cons: Additional maintenance

**Recommendation**: Option 1 (file naming convention)
- Simplest and most reliable if naming is consistent

**Question**: What are the ZIP file naming conventions?

---

### Challenge 4: Comprehensive Logging Schema

**Need to design logging tables similar to POC**:

```sql
-- Pipeline Execution Log
CREATE TABLE pipeline_execution_log (
    execution_id VARCHAR(100) PRIMARY KEY,
    pipeline_name VARCHAR(100),
    trigger_type VARCHAR(50),  -- 'event_grid', 'manual', 'scheduled'
    file_name VARCHAR(255),
    status VARCHAR(50),  -- 'RUNNING', 'SUCCESS', 'FAILED', 'HASH_VALIDATION_FAILED'
    start_time DATETIME,
    end_time DATETIME,
    duration_seconds INT,
    error_message TEXT,
    metadata JSON
);

-- Hash Validation Log
CREATE TABLE hash_validation_log (
    validation_id VARCHAR(100) PRIMARY KEY,
    execution_id VARCHAR(100),  -- FK to pipeline_execution_log
    file_name VARCHAR(255),
    hash_algorithm VARCHAR(20),  -- 'SHA256', 'MD5', etc.
    expected_hash VARCHAR(255),
    calculated_hash VARCHAR(255),
    validation_result VARCHAR(20),  -- 'PASS', 'FAIL'
    validation_time DATETIME,
    error_details TEXT
);

-- File Processing Log
CREATE TABLE file_processing_log (
    processing_id VARCHAR(100) PRIMARY KEY,
    execution_id VARCHAR(100),  -- FK to pipeline_execution_log
    company VARCHAR(50),  -- 'psps', 'sspc'
    data_type VARCHAR(50),  -- 'HR', 'Payroll'
    excel_file_name VARCHAR(255),
    sheet_name VARCHAR(100),
    rows_processed INT,
    rows_failed INT,
    table_name VARCHAR(100),
    processing_time DATETIME,
    status VARCHAR(50)
);

-- Activity Log (detailed step tracking)
CREATE TABLE activity_log (
    activity_id VARCHAR(100) PRIMARY KEY,
    execution_id VARCHAR(100),  -- FK to pipeline_execution_log
    activity_name VARCHAR(100),
    activity_type VARCHAR(50),  -- 'hash_validation', 'unzip', 'copy', 'transform'
    status VARCHAR(50),
    start_time DATETIME,
    end_time DATETIME,
    input_parameters JSON,
    output_results JSON,
    error_message TEXT
);
```

---

### Challenge 5: ADO/ADF CI/CD Setup

**Need**:
- Azure DevOps pipeline to deploy ADF pipelines
- Service principal with permissions
- Environment-specific parameter files

**Implementation**:
```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
      - main
  paths:
    include:
      - adf/*

stages:
  - stage: Build
    jobs:
      - job: Validate
        steps:
          - task: AzurePowerShell@5
            inputs:
              azureSubscription: 'ADF-ServiceConnection'
              ScriptType: 'InlineScript'
              Inline: |
                # Validate ADF JSON syntax
                Get-ChildItem -Path adf -Filter *.json | ForEach-Object {
                  $json = Get-Content $_.FullName | ConvertFrom-Json
                  Write-Host "Validated: $($_.Name)"
                }

  - stage: DeployDev
    dependsOn: Build
    jobs:
      - job: Deploy
        steps:
          - task: AzureResourceManagerTemplateDeployment@3
            inputs:
              deploymentScope: 'Resource Group'
              azureResourceManagerConnection: 'ADF-ServiceConnection'
              resourceGroupName: 'rg-adf-dev'
              location: 'Canada Central'
              templateLocation: 'Linked artifact'
              csmFile: 'adf/ARMTemplateForFactory.json'
              csmParametersFile: 'adf/ARMTemplateParametersForFactory.json'

  - stage: DeployProd
    dependsOn: DeployDev
    jobs:
      - job: Approval
        pool: server
        steps:
          - task: ManualValidation@0
            inputs:
              notifyUsers: 'manager@company.com'
              instructions: 'Please approve production deployment'

      - job: Deploy
        dependsOn: Approval
        steps:
          - task: AzureResourceManagerTemplateDeployment@3
            # ... deploy to production
```

---

## Success Criteria

### Hash Validation
- [X] ZIP file hash validated before processing
- [X] Validation results logged to database
- [X] Failed validations trigger alerts
- [X] No corrupted data processed

### Automation
- [X] Zero manual steps from file arrival to database load
- [X] F:\ drive VM eliminated
- [X] Event-driven triggering working
- [X] Files routed to correct folders automatically

### Logging
- [X] Every pipeline run logged with timestamps
- [X] Every activity logged
- [X] Hash validation results logged
- [X] Data quality metrics logged (row counts)
- [X] Errors logged with details
- [X] Logs queryable via dashboard

### CI/CD
- [X] Changes in ADO repo auto-deploy to ADF
- [X] No manual updates needed in ADF Studio
- [X] Environment promotion (dev → test → prod)
- [X] Rollback capability

### Reliability
- [X] Pipeline runs without manual intervention
- [X] Errors detected and alerted within 5 minutes
- [X] 99% success rate on valid files
- [X] Zero data corruption incidents

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| PowerShell script incompatible with Azure Function | Low | Medium | Test script conversion early in POC |
| Large ZIP files exceed function timeout | Medium | High | Implement Databricks fallback for files > 100MB |
| Hash validation breaks legitimate files | Low | Critical | Extensive testing with real production files |
| ADO/ADF deployment breaks production | Low | Critical | Test thoroughly in dev, get approval gates |
| New logging impacts performance | Low | Low | Use async logging, batch writes |
| Event Grid trigger fires before hash file arrives | Medium | High | Implement wait logic or require both files |

---

## Questions That Need Answers

### Critical (Block Implementation)
1. [ ] PowerShell hash validation script (code)
2. [ ] Hash algorithm used (MD5, SHA256, SHA512?)
3. [ ] ZIP file naming convention
4. [ ] Typical ZIP file size
5. [ ] Database type and connection details

### Important (Needed for Design)
6. [ ] Hash file format and naming
7. [ ] How often files arrive (frequency)
8. [ ] Who gets alerted on failures
9. [ ] Logging diagram (if available)
10. [ ] ADO repository structure

### Nice to Have (Optimization)
11. [ ] Current ADF pipeline JSON (ENTRY HR, CORE HR)
12. [ ] Excel file structure (sheet names)
13. [ ] SLA requirements
14. [ ] Number of environments (dev, test, prod)
15. [ ] Retention period for logs

---

**Next Step**: Get answers to critical questions, then proceed with POC design.
