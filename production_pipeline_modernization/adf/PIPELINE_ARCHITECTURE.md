# HR Payroll Data Pipeline Architecture

## Overview
Complete end-to-end pipeline for validating, processing, and loading HR payroll data from blob storage to Azure SQL Database.

## Data Flow

```
1. File Upload → landingtest container (hr_payroll_data.zip + hr_data.hash)
2. Blob Trigger → Azure Function (data-validation)
3. Validation Function:
   - Downloads both files
   - Validates hash
   - Returns exitCode (0=pass, 1=fail)
4. If exitCode = 0 → Trigger ADF Pipeline
5. ADF Pipeline:
   - Start Pipeline Logging
   - Copy zip to staging
   - Unzip files
   - ForEach CSV file:
     * Log activity start
     * Load to database table
     * Log activity end
   - Copy original zip to processed folder
   - End Pipeline Logging
6. If exitCode != 0 → Log error and stop
```

## File Structure

### Input (landingtest container):
```
hr_payroll_data.zip
  ├── employees.csv      (10 records)
  └── payroll.csv        (10 records)
hr_data.hash             (SHA512 hashes)
```

### Output (processed-test container):
```
processed-test/
  └── company_A/
      └── HR/
          └── hr_payroll_data.zip
```

### Database Tables:
```
Employees:
  - EmployeeID (PK)
  - FirstName
  - LastName
  - Email
  - Department
  - HireDate
  - Salary

Payroll:
  - PayrollID (PK)
  - EmployeeID (FK)
  - PayPeriod
  - GrossPay
  - Deductions
  - NetPay
  - PaymentDate

PipelineExecutionLog:
  - ExecutionID (PK)
  - PipelineRunID
  - PipelineName
  - SourceFileName
  - StartTime
  - EndTime
  - Status
  - RecordsProcessed

PipelineActivityLog:
  - ActivityLogID (PK)
  - ExecutionID (FK)
  - ActivityName
  - ActivityType
  - StartTime
  - EndTime
  - Status
  - RecordsRead
  - RecordsWritten
```

## ADF Pipeline Activities

### Pipeline: pl_HRPayroll_DataLoad

**Parameters:**
- `dataBlob` (string): Name of the zip file
- `hashBlob` (string): Name of the hash file
- `validationResult` (int): Exit code from validation function

**Activities:**

1. **Check Validation Result** (If Condition)
   - Condition: `@equals(pipeline().parameters.validationResult, 0)`
   - If True: Continue to next activities
   - If False: Execute error logging

2. **Log Pipeline Start** (Stored Procedure)
   - SP: `sp_StartPipelineExecution`
   - Inputs: PipelineRunID, PipelineName, SourceFileName
   - Output: ExecutionID

3. **Copy Zip to Staging** (Copy Data)
   - Source: landingtest container
   - Sink: staging container (temp location)

4. **Get File Metadata** (Get Metadata)
   - Get list of files in zip
   - Extract file names for looping

5. **ForEach CSV File** (ForEach Loop)
   - Items: `@activity('GetMetadata').output.childItems`

   5a. **Log Activity Start** (Stored Procedure)
       - SP: `sp_LogActivity`
       - ActivityName: Load_{fileName}
       - Status: Running

   5b. **Load CSV to Table** (Copy Data)
       - Source: CSV file from unzipped location
       - Sink: SQL table (dynamic based on file name)
       - Mapping: Auto-map columns

   5c. **Log Activity End** (Stored Procedure)
       - SP: `sp_LogActivity`
       - Status: Succeeded
       - RecordsWritten: `@activity('LoadCSV').output.rowsCopied`

6. **Copy Zip to Processed** (Copy Data)
   - Source: landingtest/hr_payroll_data.zip
   - Sink: processed-test/company_A/HR/hr_payroll_data.zip

7. **Log Pipeline End** (Stored Procedure)
   - SP: `sp_EndPipelineExecution`
   - Status: Succeeded
   - RecordsProcessed: Total records loaded

**Error Handling:**
- Each activity has failure path
- On failure: Execute `sp_LogError`
- Update pipeline status to Failed

## Linked Services

1. **LS_BlobStorage**
   - Type: AzureBlobStorage
   - Connection: stteststorage2025

2. **LS_AzureSqlDatabase**
   - Type: AzureSqlDatabase
   - Connection: sql-hrpayroll-test-2025/HRPayrollDB

3. **LS_AzureFunction**
   - Type: AzureFunction
   - Connection: func-data-validation-dev

## Datasets

1. **DS_LandingZip** - Binary dataset for zip file in landingtest
2. **DS_ProcessedZip** - Binary dataset for zip file in processed-test
3. **DS_EmployeesCSV** - DelimitedText dataset for employees.csv
4. **DS_PayrollCSV** - DelimitedText dataset for payroll.csv
5. **DS_EmployeesTable** - AzureSqlTable dataset for Employees table
6. **DS_PayrollTable** - AzureSqlTable dataset for Payroll table

## Monitoring Queries

### Check Running Pipelines
```sql
SELECT * FROM vw_RunningPipelines;
```

### Check Failed Pipelines
```sql
SELECT * FROM vw_FailedPipelines;
```

### Check Pipeline Performance
```sql
SELECT * FROM vw_PipelinePerformance WHERE PipelineName = 'pl_HRPayroll_DataLoad';
```

### Check Recent Executions
```sql
SELECT TOP 10
    ExecutionID,
    PipelineRunID,
    SourceFileName,
    StartTime,
    EndTime,
    DurationSeconds,
    Status,
    RecordsProcessed
FROM PipelineExecutionLog
ORDER BY StartTime DESC;
```

## Testing

### Test 1: Successful Load
```bash
# Upload files
az storage blob upload --account-name stteststorage2025 --container-name landingtest --file hr_payroll_data.zip --name hr_payroll_data.zip
az storage blob upload --account-name stteststorage2025 --container-name landingtest --file hr_data.hash --name hr_data.hash

# This should trigger:
# 1. Validation function (exitCode=0)
# 2. ADF pipeline execution
# 3. Data loaded to Employees and Payroll tables
# 4. Zip file copied to processed-test folder
# 5. Logs in PipelineExecutionLog and PipelineActivityLog
```

### Test 2: Validation Failure
```bash
# Upload corrupted file
# Should trigger validation function with exitCode=1
# Pipeline should log error and stop
```

## Performance Metrics

- **Expected Duration**: 30-60 seconds end-to-end
- **Validation**: ~15 seconds
- **Data Load**: ~10-15 seconds per table
- **File Copy**: ~5 seconds

## Error Scenarios

1. **Validation Fails**: Log to PipelineErrorLog, send notification
2. **CSV Format Invalid**: Log error, mark activity as failed
3. **Database Connection Fails**: Retry 3 times, then fail
4. **File Already Exists**: Overwrite or skip based on configuration
