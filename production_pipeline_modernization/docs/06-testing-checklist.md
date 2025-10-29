# Testing Checklist

**Last Updated**: 2025-01-17

---

## Pre-Testing Setup

### POC Environment Validation
- [ ] All Azure resources deployed
- [ ] Storage accounts accessible
- [ ] Functions deployed and running
- [ ] Database tables created
- [ ] ADF pipelines imported
- [ ] Event Grid configured
- [ ] Monitoring dashboard created
- [ ] Alert rules configured

### Test Data Preparation
- [ ] Sample ZIP files created (small, medium, large)
- [ ] Sample hash files created (valid and invalid)
- [ ] Sample Excel files with multiple sheets
- [ ] Corrupted ZIP file for testing
- [ ] Files with incorrect naming
- [ ] Test database connection strings
- [ ] Test storage connection strings

---

## Test Category 1: Hash Validation

### TC1.1: Valid Hash - Success Scenario
**Objective**: Verify hash validation passes with correct hash

**Test Data**:
- File: `test_valid.zip` (5MB)
- Hash: `test_valid.zip.sha256` (correct SHA256 hash)

**Steps**:
1. Upload ZIP and hash files to dflink container
2. Verify Event Grid trigger fires
3. Verify hash validation function executes
4. Verify validation passes
5. Verify unzip process starts
6. Verify logging records validation success

**Expected Result**:
- [ ] Hash validation function returns SUCCESS
- [ ] Calculated hash matches expected hash
- [ ] hash_validation_log table shows PASS
- [ ] Unzip function triggered
- [ ] No alerts sent

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

### TC1.2: Invalid Hash - Failure Scenario
**Objective**: Verify hash validation fails with incorrect hash

**Test Data**:
- File: `test_invalid.zip` (5MB)
- Hash: `test_invalid.zip.sha256` (incorrect hash value)

**Steps**:
1. Upload ZIP and hash files to dflink container
2. Verify Event Grid trigger fires
3. Verify hash validation function executes
4. Verify validation fails
5. Verify pipeline stops
6. Verify alert sent

**Expected Result**:
- [ ] Hash validation function returns FAILED
- [ ] Calculated hash does NOT match expected hash
- [ ] hash_validation_log table shows FAIL
- [ ] Unzip function NOT triggered
- [ ] Alert email sent with details
- [ ] pipeline_execution_log shows HASH_VALIDATION_FAILED

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

### TC1.3: Missing Hash File
**Objective**: Verify error handling when hash file missing

**Test Data**:
- File: `test_no_hash.zip` (5MB)
- Hash: (not uploaded)

**Steps**:
1. Upload only ZIP file to dflink container
2. Verify Event Grid trigger fires
3. Verify hash validation function executes
4. Verify function handles missing hash file
5. Verify error logged
6. Verify alert sent

**Expected Result**:
- [ ] Hash validation function returns FAILED
- [ ] Error: HASH_FILE_NOT_FOUND
- [ ] hash_validation_log shows error
- [ ] Alert sent
- [ ] Processing stopped

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

### TC1.4: Different Hash Algorithms
**Objective**: Test support for MD5, SHA256, SHA512

**Test Data**:
- Files with MD5 hashes
- Files with SHA256 hashes
- Files with SHA512 hashes

**Steps**:
1. Test each hash algorithm
2. Verify correct algorithm detected
3. Verify validation works for each

**Expected Result**:
- [ ] All algorithms supported
- [ ] Correct validation for each

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

## Test Category 2: File Extraction

### TC2.1: Successful Unzip - PSPS HR
**Objective**: Verify ZIP extraction and routing to correct folder

**Test Data**:
- File: `PSPS_HR_2025-01-17.zip` (contains 2 Excel files)
- Hash: Valid

**Steps**:
1. Complete hash validation (passes)
2. Verify unzip function executes
3. Verify files extracted
4. Verify routing to `day_force_templates/psps/HR/`
5. Verify all files present
6. Verify logging

**Expected Result**:
- [ ] ZIP extracted successfully
- [ ] Files in correct folder: `psps/HR/`
- [ ] All Excel files present
- [ ] Archive log updated
- [ ] Original ZIP moved to archive
- [ ] ENTRY HR pipeline triggered

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

### TC2.2: Successful Unzip - SSPC Payroll
**Objective**: Verify routing to different company

**Test Data**:
- File: `SSPC_Payroll_2025-01-17.zip`
- Hash: Valid

**Steps**:
1. Complete hash validation
2. Verify extraction and routing to `sspc/Payroll/`
3. Verify files correct

**Expected Result**:
- [ ] Files routed to `sspc/Payroll/`
- [ ] All files extracted

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

### TC2.3: Corrupted ZIP File
**Objective**: Verify error handling for corrupted ZIP

**Test Data**:
- File: `corrupted.zip` (intentionally corrupted)
- Hash: Valid (hash of corrupted file)

**Steps**:
1. Hash validation passes (hash is correct for corrupted file)
2. Unzip function attempts extraction
3. Verify error caught
4. Verify alert sent
5. Verify logging

**Expected Result**:
- [ ] Unzip function catches error
- [ ] Error logged
- [ ] Alert sent
- [ ] Processing stopped
- [ ] No partial files in target

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

### TC2.4: Large File Handling
**Objective**: Test extraction of large ZIP (> 100MB)

**Test Data**:
- File: `large_file.zip` (150MB)
- Hash: Valid

**Steps**:
1. Complete hash validation
2. Verify extraction method (Function or Databricks)
3. Verify no timeout errors
4. Verify all files extracted

**Expected Result**:
- [ ] Large file extracted successfully
- [ ] No timeout errors
- [ ] All files present
- [ ] Performance acceptable

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

### TC2.5: Invalid File Naming
**Objective**: Verify error handling for unexpected file names

**Test Data**:
- File: `unknown_format.zip` (doesn't match naming convention)
- Hash: Valid

**Steps**:
1. Hash validation passes
2. Unzip function attempts routing
3. Verify error: unable to parse file name
4. Verify alert sent
5. Verify logging

**Expected Result**:
- [ ] Routing error caught
- [ ] Error logged
- [ ] Alert sent with file name
- [ ] Manual intervention requested

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

## Test Category 3: ADF Pipeline Processing

### TC3.1: ENTRY HR Pipeline
**Objective**: Verify ENTRY HR iterates correctly with logging

**Test Data**:
- 2 Excel files in `psps/HR/`
- 3 Excel files in `sspc/Payroll/`

**Steps**:
1. Trigger ENTRY HR pipeline manually
2. Verify iteration through all files
3. Verify logging at each step
4. Verify CORE HR called for each file

**Expected Result**:
- [ ] All 5 files processed
- [ ] pipeline_execution_log shows start
- [ ] activity_log shows each iteration
- [ ] CORE HR called 5 times
- [ ] pipeline_execution_log shows completion

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

### TC3.2: CORE HR Pipeline - Excel Sheet Extraction
**Objective**: Verify Excel sheets extracted to separate tables

**Test Data**:
- Excel file: `Employee_Data.xlsx`
  - Sheet 1: Personal (100 rows)
  - Sheet 2: Benefits (50 rows)
  - Sheet 3: Emergency_Contacts (30 rows)

**Steps**:
1. Trigger CORE HR with Excel file
2. Verify each sheet processed
3. Verify separate table created for each sheet
4. Verify row counts match
5. Verify logging

**Expected Result**:
- [ ] 3 tables created
- [ ] Table 1: 100 rows
- [ ] Table 2: 50 rows
- [ ] Table 3: 30 rows
- [ ] file_processing_log shows all sheets
- [ ] Row counts logged correctly

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

### TC3.3: Pipeline Error Handling
**Objective**: Verify error handling in pipeline

**Test Data**:
- Excel file with invalid schema
- Excel file with missing sheets

**Steps**:
1. Process file with errors
2. Verify error caught
3. Verify pipeline continues or stops (per design)
4. Verify error logged
5. Verify alert sent

**Expected Result**:
- [ ] Error caught gracefully
- [ ] Error details in activity_log
- [ ] Alert sent
- [ ] Other files continue processing

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

## Test Category 4: Comprehensive Logging

### TC4.1: Pipeline Execution Log
**Objective**: Verify pipeline execution logging

**Test Data**:
- Any valid file

**Steps**:
1. Trigger complete flow
2. Query pipeline_execution_log
3. Verify all fields populated

**Expected Result**:
- [ ] execution_id unique
- [ ] pipeline_name correct
- [ ] trigger_type correct
- [ ] start_time accurate
- [ ] end_time accurate
- [ ] duration_seconds calculated
- [ ] status correct (SUCCESS or FAILED)
- [ ] metadata JSON valid

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

### TC4.2: Hash Validation Log
**Objective**: Verify hash validation logging

**Test Data**:
- Valid and invalid hash files

**Steps**:
1. Process both valid and invalid files
2. Query hash_validation_log
3. Verify details captured

**Expected Result**:
- [ ] validation_id unique
- [ ] execution_id links to pipeline_execution_log
- [ ] file_name correct
- [ ] hash_algorithm identified
- [ ] expected_hash captured
- [ ] calculated_hash captured
- [ ] validation_result correct (PASS/FAIL)
- [ ] validation_time accurate

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

### TC4.3: File Processing Log
**Objective**: Verify file processing logging

**Test Data**:
- Excel with multiple sheets

**Steps**:
1. Process Excel file
2. Query file_processing_log
3. Verify all sheets logged

**Expected Result**:
- [ ] One record per sheet
- [ ] company correct
- [ ] data_type correct
- [ ] excel_file_name correct
- [ ] sheet_name correct
- [ ] rows_processed accurate
- [ ] table_name correct
- [ ] status correct

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

### TC4.4: Activity Log
**Objective**: Verify detailed activity logging

**Test Data**:
- Any valid file

**Steps**:
1. Process file
2. Query activity_log
3. Verify all activities logged

**Expected Result**:
- [ ] All activities captured
- [ ] activity_name descriptive
- [ ] activity_type correct
- [ ] start_time and end_time accurate
- [ ] input_parameters JSON valid
- [ ] output_results JSON valid

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

## Test Category 5: Monitoring & Alerts

### TC5.1: Hash Validation Failure Alert
**Objective**: Verify alert sent on hash validation failure

**Test Data**:
- Invalid hash file

**Steps**:
1. Trigger hash validation failure
2. Verify alert sent
3. Verify alert content

**Expected Result**:
- [ ] Alert sent within 2 minutes
- [ ] Alert contains file name
- [ ] Alert contains expected vs calculated hash
- [ ] Alert sent to correct recipients

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

### TC5.2: Processing Error Alert
**Objective**: Verify alert on pipeline error

**Test Data**:
- File causing pipeline error

**Steps**:
1. Trigger pipeline error
2. Verify alert sent
3. Verify alert content

**Expected Result**:
- [ ] Alert sent
- [ ] Alert contains error details
- [ ] Alert contains pipeline name
- [ ] Alert actionable

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

### TC5.3: Monitoring Dashboard
**Objective**: Verify dashboard shows correct metrics

**Steps**:
1. Process multiple files
2. Open monitoring dashboard
3. Verify metrics displayed

**Expected Result**:
- [ ] Total files processed count
- [ ] Success vs failure rate
- [ ] Average processing time
- [ ] Current running pipelines
- [ ] Recent errors
- [ ] Refresh working

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

## Test Category 6: Performance

### TC6.1: Small File Performance
**Objective**: Measure processing time for small files

**Test Data**:
- File size: 5MB
- Sheets: 2

**Steps**:
1. Process file
2. Measure end-to-end time
3. Record metrics

**Expected Result**:
- [ ] Hash validation: < 30 seconds
- [ ] Unzip: < 1 minute
- [ ] Excel processing: < 2 minutes
- [ ] Total: < 5 minutes

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

### TC6.2: Medium File Performance
**Objective**: Measure processing time for medium files

**Test Data**:
- File size: 50MB
- Sheets: 5

**Steps**:
1. Process file
2. Measure times
3. Record metrics

**Expected Result**:
- [ ] Hash validation: < 1 minute
- [ ] Unzip: < 3 minutes
- [ ] Excel processing: < 10 minutes
- [ ] Total: < 15 minutes

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

### TC6.3: Large File Performance
**Objective**: Measure processing time for large files

**Test Data**:
- File size: 150MB
- Sheets: 10

**Steps**:
1. Process file
2. Measure times
3. Verify no timeouts

**Expected Result**:
- [ ] Hash validation: < 3 minutes
- [ ] Unzip: < 10 minutes
- [ ] Excel processing: < 30 minutes
- [ ] Total: < 45 minutes
- [ ] No timeout errors

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

## Test Category 7: CI/CD

### TC7.1: Dev Deployment
**Objective**: Verify ADO pipeline deploys to dev

**Steps**:
1. Commit change to ADO repo (main branch)
2. Verify pipeline triggers
3. Verify validation passes
4. Verify deployment to dev ADF
5. Verify change reflected in dev

**Expected Result**:
- [ ] Pipeline auto-triggered
- [ ] JSON validation passes
- [ ] Deployment succeeds
- [ ] Change visible in dev ADF
- [ ] No errors

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

### TC7.2: Production Approval Gate
**Objective**: Verify production deployment requires approval

**Steps**:
1. Dev deployment succeeds
2. Verify production stage waits
3. Approve production deployment
4. Verify deployment proceeds

**Expected Result**:
- [ ] Production stage pauses
- [ ] Approval email sent to manager
- [ ] After approval, deployment proceeds
- [ ] Change deployed to production

**Actual Result**: ___________

**Status**: [ ] PASS [ ] FAIL

**Notes**: ___________

---

## Test Summary

### Test Results

| Category | Total Tests | Passed | Failed | Pass Rate |
|----------|-------------|--------|--------|-----------|
| Hash Validation | 4 | | | |
| File Extraction | 5 | | | |
| ADF Processing | 3 | | | |
| Logging | 4 | | | |
| Monitoring | 3 | | | |
| Performance | 3 | | | |
| CI/CD | 2 | | | |
| **TOTAL** | **24** | | | |

### Critical Issues Found
1. ___________
2. ___________
3. ___________

### Medium Issues Found
1. ___________
2. ___________

### Recommendations
1. ___________
2. ___________
3. ___________

### Sign-Off

**Tester**: ___________ **Date**: ___________

**Reviewer**: ___________ **Date**: ___________

**Approved for Production**: [ ] YES [ ] NO

**Notes**: ___________
