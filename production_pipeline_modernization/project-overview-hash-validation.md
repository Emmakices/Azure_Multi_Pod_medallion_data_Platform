# Government of Canada Data Pipeline - Hash Validation Implementation

**Project**: Automated Hash Validation for DataLoad5
**Client**: Government of Canada (via Dayforce GC)
**Priority**: URGENT - Required before DataLoad5 (1 week)
**Date**: January 17, 2025

---

## Executive Summary

Government of Canada will begin sending SHA-512 hash files alongside data ZIP files starting with DataLoad5 (arriving in ~1 week). We need to implement automated hash validation to verify data integrity BEFORE processing, preventing corrupted or tampered data from entering our systems.

**Current Risk**: Without validation, we could process corrupted data, causing:
- Data quality issues in SQL Server database
- Failed downstream processes
- Need to reprocess entire loads
- Potential compliance violations

**Proposed Solution**: Automated hash validation using ADF + existing PowerShell script + SQL Server logging

**Timeline**: Must be deployed in 5-6 days (before DataLoad5 arrival)

---

## Current State: Manual Process

### How Data Arrives Today

```
Government of Canada
         |
         | (sends via Microsoft)
         v
Azure Blob Storage
Container: dflink
├─ DATACONV_PSPC_LOAD4_FILES.zip (100-150 MB)
├─ DATACONV_SSC_LOAD4_ALL_FILES.zip
└─ [Other department ZIP files]
         |
         | [MANUAL STEP 1]
         | Team downloads ZIP to F:\ drive (SQLVMDATA1 VM)
         v
F:\ Drive Location
Path: F:\Data Conversion\Sent From GC\DL4\[date]\
         |
         | [MANUAL STEP 2]
         | Team extracts ZIP manually
         v
8 Excel Files Extracted:
├─ GC_HRImport_Template_with_Self_Audit_V2.xlsm (27.9 MB)
├─ GC_YTD_PayRunHistory_Template_with_Self_Audit_V2.xlsm (31.5 MB)
├─ GC_BenefitsElections_Template_with_Self_Audit_V2.xlsm (14.7 MB)
├─ GC_EmployeeDeductionBalanceAndArrearlmport_Template_V2.xlsx
├─ GC_EmployeeElection_Template_with_Self_Audit_V2.xlsm
├─ GC_EmployeeEntitlementBalancelrnport_Template_V2.xlsx
├─ GC_GarnishmentImport_Template_V2.xlsx
└─ GC_MigratedROEHistoryImport_Template_V2.xlsx
         |
         | [MANUAL STEP 3]
         | Team uploads to Azure Blob Storage
         v
Azure Blob Storage
Container: dayforce-excel-templates
├─ PSPC/
│   ├─ HR_HRI/
│   ├─ HR_HP/
│   ├─ HR_DEBUG/
│   ├─ PAY/
│   └─ PAY_DEBUG/
└─ SSC/
         |
         | [MANUAL STEP 4]
         | Team runs ADF pipeline in debug mode
         v
ADF Pipeline Processing
├─ ENTRY HR pipeline (iterates files)
└─ CORE HR pipeline (extracts Excel sheets → SQL tables)
         |
         v
SQL Server Database
└─ Tables populated with data
```

### Problems with Current Process

| Issue | Impact | Risk Level |
|-------|--------|------------|
| No hash validation | Can process corrupted/tampered data | CRITICAL |
| Manual download/extract | Slow, error-prone, requires human intervention | HIGH |
| No automated triggers | Delays in processing, requires monitoring | MEDIUM |
| Debug mode for logging | Not production-ready, limited visibility | MEDIUM |
| No error alerts | Problems not detected quickly | HIGH |

---

## New Requirement: Hash Validation (Starting DataLoad5)

### What's Changing

**Starting with DataLoad5**, Government of Canada will send:

1. **ZIP file** (as before)
   - Example: `DATACONV_PSPC_LOAD5_FILES.zip`

2. **Hash file** (NEW - format TBD)
   - Example: `DATACONV_PSPC_LOAD5_FILES.hash` (or .txt, .sha512 - not confirmed yet)
   - Contains: SHA-512 hashes of files for integrity verification

### Hash Validation Script (Already Available)

We have a PowerShell script (`hash.ps1`) that can:
- **Generate** SHA-512 hashes for files
- **Validate** files against a hash file
- **Report** results: OK, FAIL, MISSING, EXTRA files

**Script Exit Codes**:
- `0` = SUCCESS (all files valid)
- `1` = Usage error
- `2` = File not found
- `3` = VALIDATION FAILED (hash mismatch, missing files, extra files)

**Hash File Format** (Expected):
```
# Root: folder_name
abc123def456789abcdef123456789abcdef...|GC_HRImport_Template_V2.xlsm
def456789abc123def456789abc123def456...|GC_YTD_PayRunHistory_V2.xlsm
[more hashes for each file...]
```

### Manager's Requirement

**"Validate hash BEFORE unzipping. If validation fails, stop processing and alert us."**

---

## Proposed Solution: Automated Hash Validation Pipeline

### Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                 AUTOMATED HASH VALIDATION PIPELINE                    │
│                 (ADF + PowerShell + SQL Server ONLY)                  │
└──────────────────────────────────────────────────────────────────────┘

STEP 1: File Arrival Detection
────────────────────────────────
Government of Canada → Microsoft → Azure Blob (dflink)
                                    ├─ DATACONV_PSPC_LOAD5_FILES.zip
                                    └─ DATACONV_PSPC_LOAD5_FILES.hash
                                           |
                                           | [AUTOMATIC]
                                           | Event Grid Trigger (or Schedule)
                                           v

STEP 2: Download Files to F:\ Drive
────────────────────────────────────────
ADF Pipeline Activity: Copy Data
├─ Source: dflink container
├─ Destination: F:\Data Conversion\Validation\[date]\
└─ Files copied:
    ├─ ZIP file
    └─ Hash file
           |
           v

STEP 3: Hash Validation (PowerShell Script via ADF)
─────────────────────────────────────────────────────
ADF Pipeline Activity: Execute PowerShell
├─ Uses: Self-Hosted Integration Runtime (on SQL Server VM)
├─ Runs: hash.ps1 -Mode Validate -HashFile [hash_file] -RootPath [folder]
└─ Returns: Exit code (0 = success, 3 = failed)
           |
           ├──────────────┬──────────────┐
           |              |              |
           v              v              v
     Exit Code 0    Exit Code 3    Exit Code 2
     (SUCCESS)      (FAILED)       (ERROR)
           |              |              |
           |              |              |
           v              v              v

STEP 4a: If Validation PASSES (Exit Code 0)
────────────────────────────────────────────
├─ Log success to SQL Server (logging table)
├─ Unzip files to F:\ drive
├─ Upload Excel files to dayforce-excel-templates container
├─ Route files to correct folders (PSPC/HR_DEBUG, PSPC/PAY, etc.)
├─ Archive ZIP + hash files
└─ Trigger ENTRY HR pipeline
           |
           v
    Existing Pipeline Processing Continues


STEP 4b: If Validation FAILS (Exit Code 3)
───────────────────────────────────────────
├─ Log failure to SQL Server with details:
│   ├─ Which files failed hash check
│   ├─ Which files are missing
│   ├─ Which files are extra (not in hash file)
│   └─ Timestamp, ZIP file name
│
├─ Send email alert to team:
│   ├─ Subject: "CRITICAL: Hash Validation Failed for [file_name]"
│   ├─ Body: Detailed error report
│   └─ Recipients: [Manager email list - TBD]
│
└─ STOP PROCESSING (do not unzip, do not process)
           |
           v
    Manual intervention required


STEP 4c: If Error (Exit Code 2)
────────────────────────────────
├─ Log error to SQL Server
│   └─ Hash file not found, or ZIP not found
│
├─ Send alert email
│
└─ STOP PROCESSING
```

### Technology Stack (Approved Resources Only)

| Component | Technology | Purpose | Already Available? |
|-----------|------------|---------|-------------------|
| File landing | Azure Blob Storage (dflink) | Receive files from GC | ✅ Yes |
| Trigger | Event Grid or ADF Schedule | Detect new files | ✅ Yes (ADF feature) |
| Orchestration | Azure Data Factory | Pipeline automation | ✅ Yes |
| Hash validation | PowerShell script (hash.ps1) | Validate file integrity | ✅ Yes |
| Execution runtime | Self-Hosted Integration Runtime | Run PowerShell on SQL VM | ❓ Need to verify |
| Temporary storage | F:\ drive (SQLVMDATA1 VM) | Stage files for validation | ✅ Yes |
| Logging | SQL Server database | Log validation results | ✅ Yes |
| Alerts | ADF email notification | Alert on failures | ✅ Yes (ADF feature) |
| Target storage | dayforce-excel-templates | Store extracted files | ✅ Yes |

**NO new Azure resources required** - uses only existing approved infrastructure.

---

## Detailed Pipeline Activities

### ADF Pipeline: "Hash_Validation_and_Processing"

**Trigger Options**:
- **Option A**: Event Grid trigger (automatic - fires when ZIP arrives in dflink)
- **Option B**: Schedule trigger (runs every 4 hours to check for new files)
- **Recommended**: Option A (faster response time)

**Pipeline Parameters**:
- `zip_file_name`: Name of ZIP file (e.g., DATACONV_PSPC_LOAD5_FILES.zip)
- `hash_file_name`: Name of hash file (TBD - need format from GC)
- `department`: PSPC or SSC
- `load_number`: Load5, Load6, etc.

**Activities**:

#### Activity 1: Copy ZIP to F:\ Drive
```
Type: Copy Data
Source: Azure Blob (dflink container)
Destination: File System (F:\Data Conversion\Validation\@{formatDateTime(utcNow(),'yyyyMMdd_HHmmss')}\)
Integration Runtime: Self-Hosted IR (on SQL VM)

Files to copy:
- @{pipeline().parameters.zip_file_name}
```

#### Activity 2: Copy Hash File to F:\ Drive
```
Type: Copy Data
Source: Azure Blob (dflink container)
Destination: File System (F:\Data Conversion\Validation\@{formatDateTime(utcNow(),'yyyyMMdd_HHmmss')}\)
Integration Runtime: Self-Hosted IR (on SQL VM)

Files to copy:
- @{pipeline().parameters.hash_file_name}
```

#### Activity 3: Execute Hash Validation
```
Type: Custom Activity (or Script Activity if available)
Integration Runtime: Self-Hosted IR (on SQL VM)
Command: PowerShell

Script:
$exitCode = & "F:\Scripts\hash.ps1" `
    -Mode Validate `
    -HashFile "F:\Data Conversion\Validation\{date}\{hash_file}" `
    -RootPath "F:\Data Conversion\Validation\{date}" `
    -OutputFile "F:\Data Conversion\Validation\{date}\validation_results.txt" `
    -Silent

exit $LASTEXITCODE

Returns: Exit code (0, 1, 2, or 3)
```

#### Activity 4: Check Validation Result
```
Type: If Condition
Expression: @equals(activity('Execute_Hash_Validation').output.exitCode, 0)

If TRUE (validation passed):
    └─ Go to Activity 5 (Log Success)

If FALSE (validation failed):
    └─ Go to Activity 10 (Log Failure)
```

#### Activity 5: Log Validation Success
```
Type: Stored Procedure
Linked Service: SQL Server
Stored Procedure: [dbo].[sp_log_hash_validation]

Parameters:
- validation_id: @{guid()}
- file_name: @{pipeline().parameters.zip_file_name}
- validation_result: 'PASS'
- ok_count: [extracted from validation results file]
- fail_count: 0
- missing_count: 0
- extra_count: 0
- validation_time: @{utcNow()}
- details: 'All files validated successfully'
```

#### Activity 6: Unzip Files
```
Type: Custom Activity
Integration Runtime: Self-Hosted IR (on SQL VM)
Command: PowerShell

Script:
Expand-Archive `
    -Path "F:\Data Conversion\Validation\{date}\{zip_file}" `
    -DestinationPath "F:\Data Conversion\Extracted\{date}\" `
    -Force
```

#### Activity 7: Upload to dayforce-excel-templates
```
Type: ForEach
Items: List of extracted Excel files

  Inside ForEach:
    Activity: Copy Data
    Source: File System (F:\Data Conversion\Extracted\{date}\)
    Destination: Azure Blob (dayforce-excel-templates)
    Destination Path: Determined by file name pattern
      - If file contains "HR" → PSPC/HR_DEBUG/
      - If file contains "Pay" or "YTD" → PSPC/PAY/
```

#### Activity 8: Archive Files
```
Type: Copy Data
Source: F:\Data Conversion\Validation\{date}\
Destination: Azure Blob (archive container)
```

#### Activity 9: Trigger ENTRY HR Pipeline
```
Type: Execute Pipeline
Pipeline: [Existing ENTRY HR pipeline name]
Parameters: [Pass required parameters]
```

#### Activity 10: Log Validation Failure
```
Type: Stored Procedure
Linked Service: SQL Server
Stored Procedure: [dbo].[sp_log_hash_validation]

Parameters:
- validation_id: @{guid()}
- file_name: @{pipeline().parameters.zip_file_name}
- validation_result: 'FAIL'
- ok_count: [extracted from results]
- fail_count: [extracted from results]
- missing_count: [extracted from results]
- extra_count: [extracted from results]
- validation_time: @{utcNow()}
- details: [Full error details from validation_results.txt]
```

#### Activity 11: Send Alert Email
```
Type: Web Activity (or Logic Apps)
URL: [Email service endpoint]
Method: POST
Body:
{
    "to": ["manager@company.com", "team@company.com"],
    "subject": "CRITICAL: Hash Validation Failed for @{pipeline().parameters.zip_file_name}",
    "body": "Hash validation failed. Details:\n\n[error details from Activity 10]"
}
```

#### Activity 12: Fail Pipeline
```
Type: Fail Activity
Error Code: HASH_VALIDATION_FAILED
Error Message: Hash validation failed. Processing stopped. See logs for details.
```

---

## SQL Server Logging Schema

### Table: hash_validation_log

```sql
CREATE TABLE [dbo].[hash_validation_log] (
    validation_id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    file_name NVARCHAR(255) NOT NULL,
    validation_result NVARCHAR(20) NOT NULL, -- 'PASS', 'FAIL', 'ERROR'
    ok_count INT DEFAULT 0,
    fail_count INT DEFAULT 0,
    missing_count INT DEFAULT 0,
    extra_count INT DEFAULT 0,
    validation_time DATETIME2 NOT NULL DEFAULT GETDATE(),
    details NVARCHAR(MAX),
    created_date DATETIME2 NOT NULL DEFAULT GETDATE(),

    INDEX IX_validation_time (validation_time),
    INDEX IX_validation_result (validation_result)
);
```

### Stored Procedure: sp_log_hash_validation

```sql
CREATE PROCEDURE [dbo].[sp_log_hash_validation]
    @validation_id UNIQUEIDENTIFIER,
    @file_name NVARCHAR(255),
    @validation_result NVARCHAR(20),
    @ok_count INT,
    @fail_count INT,
    @missing_count INT,
    @extra_count INT,
    @validation_time DATETIME2,
    @details NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO [dbo].[hash_validation_log] (
        validation_id,
        file_name,
        validation_result,
        ok_count,
        fail_count,
        missing_count,
        extra_count,
        validation_time,
        details
    )
    VALUES (
        @validation_id,
        @file_name,
        @validation_result,
        @ok_count,
        @fail_count,
        @missing_count,
        @extra_count,
        @validation_time,
        @details
    );

    -- Return success
    SELECT @@ROWCOUNT AS rows_inserted;
END;
```

### Query Examples

**View recent validations:**
```sql
SELECT
    file_name,
    validation_result,
    ok_count,
    fail_count,
    missing_count,
    extra_count,
    validation_time
FROM hash_validation_log
ORDER BY validation_time DESC;
```

**View failures only:**
```sql
SELECT
    file_name,
    fail_count,
    missing_count,
    extra_count,
    details,
    validation_time
FROM hash_validation_log
WHERE validation_result = 'FAIL'
ORDER BY validation_time DESC;
```

---

## Prerequisites & Dependencies

### What We Need to Confirm/Setup

#### 1. Self-Hosted Integration Runtime (CRITICAL)

**What**: Component that allows ADF to run commands on SQL Server VM

**Check if exists**:
```powershell
# On SQL Server VM (SQLVMDATA1), run:
Get-Service -Name "DIAHostService"

# If service exists → Already installed ✅
# If error → Need to install ❌
```

**If doesn't exist**, installation needed:
1. Download Self-Hosted IR installer from Azure Portal
2. Install on SQL Server VM (15 minutes)
3. Register with ADF (get authentication key from ADF)
4. Test connection

**Estimated time**: 1 hour (if not installed)

#### 2. Hash File Format Confirmation

**Status**: UNKNOWN - waiting for DataLoad5

**Need to know**:
- Hash file name pattern: `DATACONV_PSPC_LOAD5_FILES.hash`? `.sha512`? `.txt`?
- Hash file format: Does it match PowerShell script expectations?

**Mitigation**:
- Request sample hash file from Government of Canada ASAP
- Or create test hash file using our PowerShell script for testing

#### 3. File Routing Logic

**Question**: How to determine which Excel files go to which folders?

**Options**:
- **By file name pattern**:
  - Files containing "HR" → PSPC/HR_DEBUG/
  - Files containing "Pay", "YTD", "Deduction" → PSPC/PAY/
  - Files containing "Benefits", "Election" → PSPC/HR_HRI/

- **By manifest file** (if included in ZIP)

- **Manual configuration table** in SQL Server

**Need**: Confirmation on routing logic before DataLoad5

#### 4. Alert Recipients

**Who should receive alerts on validation failure?**
- Manager email: ___________
- Team email: ___________
- Other: ___________

#### 5. SQL Server Permissions

**Need to verify**:
- ADF can connect to SQL Server ✅ (already confirmed - existing pipelines work)
- ADF service account can create tables
- ADF service account can execute stored procedures

---

## Implementation Plan

### Phase 1: Setup & Preparation (Day 1-2)

**Day 1**:
- [ ] Verify Self-Hosted IR installed on SQL Server VM
  - If not installed: Install and configure (1 hour)
- [ ] Create SQL logging table (`hash_validation_log`)
- [ ] Create stored procedure (`sp_log_hash_validation`)
- [ ] Test PowerShell script on sample data
- [ ] Request sample hash file from Government of Canada

**Day 2**:
- [ ] Design ADF pipeline (all 12 activities)
- [ ] Configure pipeline parameters
- [ ] Set up Event Grid trigger (or schedule trigger)
- [ ] Configure email alert mechanism

### Phase 2: Build (Day 3-4)

**Day 3**:
- [ ] Build ADF pipeline activities 1-6 (validation + success path)
- [ ] Test with sample ZIP file (without hash for now)
- [ ] Verify files copy to F:\ drive correctly
- [ ] Test PowerShell script execution via ADF

**Day 4**:
- [ ] Build ADF pipeline activities 7-12 (failure path + alerts)
- [ ] Configure logging to SQL Server
- [ ] Set up email alerts
- [ ] Test failure scenarios

### Phase 3: Testing (Day 5)

**Test Scenarios**:
- [ ] TC1: Valid hash → Should pass, unzip, and process
- [ ] TC2: Invalid hash → Should fail, alert, and stop
- [ ] TC3: Missing hash file → Should error, alert, and stop
- [ ] TC4: Missing files in ZIP → Should detect MISSING, alert, stop
- [ ] TC5: Extra files in ZIP → Should detect EXTRA, alert, stop
- [ ] TC6: Verify SQL logging works for all scenarios
- [ ] TC7: Verify email alerts sent correctly

### Phase 4: Deployment (Day 6)

**Pre-Deployment**:
- [ ] Final review with manager
- [ ] Backup existing ADF pipelines
- [ ] Document rollback procedure

**Deployment**:
- [ ] Deploy pipeline to production ADF
- [ ] Activate Event Grid trigger
- [ ] Monitor first DataLoad5 arrival
- [ ] Stand by for issues

**Post-Deployment**:
- [ ] Monitor validation logs in SQL
- [ ] Verify alerts working
- [ ] Document any issues

---

## Timeline (6 Days)

```
┌─────────────────────────────────────────────────────────┐
│                  TIMELINE TO DATALOAD5                   │
└─────────────────────────────────────────────────────────┘

TODAY (Day 0)
├─ Project kickoff
├─ Get approvals
└─ Confirm requirements

Day 1: Setup
├─ Verify/Install Self-Hosted IR
├─ Create SQL tables
└─ Test PowerShell script

Day 2: Design
├─ Design ADF pipeline
├─ Configure triggers
└─ Set up alerts

Day 3: Build (Part 1)
├─ Build validation flow
├─ Build success path
└─ Test basic flow

Day 4: Build (Part 2)
├─ Build failure path
├─ Implement logging
└─ Configure alerts

Day 5: Testing
├─ Test all scenarios
├─ Fix issues
└─ Final validation

Day 6: Deployment
├─ Deploy to production
├─ Activate trigger
└─ Monitor

Day 7: DATALOAD5 ARRIVES
├─ Automated validation runs
├─ Monitor results
└─ Resolve any issues
```

**CRITICAL PATH**: Self-Hosted IR verification (Day 1) - if not installed, delays entire project

---

## Risks & Mitigations

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Self-Hosted IR not installed | HIGH - Can't run PowerShell | MEDIUM | Verify immediately; install if needed (1 hour) |
| Hash file format unknown | HIGH - Can't validate | HIGH | Request sample from GC; create test hash file |
| DataLoad5 delayed | LOW - More time to build | LOW | Continue building; ready when it arrives |
| PowerShell script incompatible | MEDIUM - Need to modify | LOW | Test script thoroughly on Day 1 |
| SQL permissions issues | MEDIUM - Can't log | LOW | Verify permissions on Day 1 |
| Email alerts not working | MEDIUM - Won't know failures | LOW | Test alerts thoroughly on Day 5 |
| File routing logic unclear | MEDIUM - Files in wrong folders | MEDIUM | Define clear rules; create config table |

---

## Success Criteria

### Phase 1 Success (Setup Complete)
- [ ] Self-Hosted IR installed and tested
- [ ] SQL logging table created
- [ ] PowerShell script tested manually
- [ ] Sample hash file available

### Phase 2 Success (Build Complete)
- [ ] ADF pipeline created with all 12 activities
- [ ] Validation flow works end-to-end
- [ ] Failure path triggers alerts
- [ ] Logging to SQL Server works

### Phase 3 Success (Testing Complete)
- [ ] All 7 test scenarios pass
- [ ] No critical issues found
- [ ] Performance acceptable (< 5 minutes for validation)
- [ ] Alerts deliver to correct recipients

### Phase 4 Success (Deployed)
- [ ] Pipeline deployed to production
- [ ] Trigger active and monitoring
- [ ] Ready for DataLoad5
- [ ] Team trained on monitoring logs

### DataLoad5 Success (Live)
- [ ] Hash validation runs automatically
- [ ] Validation passes (or fails with proper alert)
- [ ] Files processed correctly
- [ ] No manual intervention needed

---

## Cost Analysis

**No additional Azure costs** - using only existing approved resources:

| Resource | Cost | Notes |
|----------|------|-------|
| Azure Data Factory | $0 | Already provisioned; existing activities |
| Self-Hosted Integration Runtime | $0 | Free component; runs on existing SQL VM |
| SQL Server | $0 | Already provisioned; adding 1 table |
| Blob Storage | $0 | Already provisioned; existing containers |
| Event Grid | ~$0.60/month | 10,000 events × $0.00006 |
| **Total Additional Cost** | **~$1/month** | Negligible |

**Time Savings**: Eliminates manual download/validation step (saves ~30 minutes per load)

**Risk Reduction**: Prevents processing corrupted data (potentially saves hours of troubleshooting)

---

## Questions That Need Immediate Answers

### CRITICAL (Block Implementation)
1. [ ] Is Self-Hosted Integration Runtime installed on SQL Server VM?
   - Command to check: `Get-Service -Name "DIAHostService"`
   - If NO: Can we install it? (needs approval + 1 hour)

2. [ ] What will hash file be named?
   - Pattern: `DATACONV_PSPC_LOAD5_FILES.???`
   - Extension: `.hash`? `.txt`? `.sha512`?

3. [ ] What hash file format will Government of Canada use?
   - Can we get sample hash file ASAP?
   - Or should we create test data using our PowerShell script?

### HIGH PRIORITY (Needed for Build)
4. [ ] SQL Server connection details
   - Server name: ___________
   - Database name: ___________
   - Can we create new table? (Permissions check)

5. [ ] Who should receive validation failure alerts?
   - Email 1: ___________
   - Email 2: ___________

6. [ ] File routing rules
   - How do we know which files go to HR vs PAY folders?
   - By file name? Manifest file? Manual config?

### MEDIUM PRIORITY (Nice to Have)
7. [ ] When exactly is DataLoad5 expected?
   - Date: ___________
   - Time: ___________

8. [ ] Do we have test ZIP + hash files?
   - Can we get sample files for testing?

---

## Next Steps

### Immediate Actions Required

**From Manager/Team Lead**:
1. Approve project approach
2. Provide answers to CRITICAL questions above
3. Authorize Self-Hosted IR installation (if needed)
4. Provide SQL Server connection details
5. Provide alert recipient emails

**From Technical Team**:
1. Verify Self-Hosted IR status on SQL Server VM
2. Request sample hash file from Government of Canada
3. Prepare SQL Server for new logging table
4. Begin ADF pipeline design (can start without all answers)

**From Government of Canada** (if possible):
1. Confirm hash file naming convention
2. Provide sample hash file
3. Confirm DataLoad5 delivery date/time

---

## Contact & Support

**Project Lead**: [Your Name]
**Email**: [Your Email]
**Availability**: Immediate (urgent project)

**Escalation**: If blockers encountered, escalate immediately - 6-day timeline is tight.

---

## Appendix A: PowerShell Script Details

**Script Name**: `hash.ps1`
**Version**: 0.3
**Algorithm**: SHA-512
**Modes**: Generate, Validate

**Key Features**:
- Validates files against hash file
- Reports: OK, FAIL, MISSING, EXTRA files
- Exit codes: 0 (success), 3 (validation issues), 2 (file not found)
- Supports custom root paths (for validating on different systems)

**Example Usage**:
```powershell
# Validate ZIP contents against hash file
.\hash.ps1 `
    -Mode Validate `
    -HashFile "F:\hashes\dataload5.txt" `
    -RootPath "F:\extracted" `
    -OutputFile "F:\validation_results.txt"

# Check exit code
if ($LASTEXITCODE -eq 0) {
    Write-Host "Validation PASSED"
} elseif ($LASTEXITCODE -eq 3) {
    Write-Host "Validation FAILED"
} else {
    Write-Host "Error occurred"
}
```

---

## Appendix B: Example Hash File

**Expected format** (based on PowerShell script):
```
# Root: PSPC_LOAD5
a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2g3h4i5j6k7l8m9n0o1p2|GC_HRImport_Template_with_Self_Audit_V2.xlsm
b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2g3h4i5j6k7l8m9n0o1p2q3r4|GC_YTD_PayRunHistory_Template_with_Self_Audit_V2.xlsm
c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2g3h4i5j6k7l8m9n0o1p2q3r4s5t6|GC_BenefitsElections_Template_with_Self_Audit_V2.xlsm
[more lines for each Excel file...]
```

**Format**:
- First line: `# Root: [folder_name]`
- Subsequent lines: `[sha512_hash]|[relative_file_path]`
- Hash: 128 character SHA-512 hash (lowercase)
- Delimiter: Pipe character `|`

---

## Document Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-01-17 | [Your Name] | Initial document for manager review |

---

**END OF DOCUMENT**

**Status**: DRAFT - Awaiting approval and answers to critical questions

**Next Update**: After receiving feedback from manager/team
