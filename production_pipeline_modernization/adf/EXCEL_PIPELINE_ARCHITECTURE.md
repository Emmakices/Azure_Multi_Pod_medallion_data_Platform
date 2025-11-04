# Excel Multi-Sheet Data Pipeline Architecture

## Overview
Enterprise pipeline for processing HR and Payroll data from multi-sheet Excel files in blob storage to Azure SQL Database.

## Data Flow

```
1. File Upload → landingtest container
   - company_A_hr_payroll.zip (contains 2 Excel files)
   - hr_payroll_excel.hash

2. Blob Trigger → Azure Function (data-validation)
   - Downloads and validates hash
   - Returns exitCode (0=pass, 1=fail)

3. If exitCode = 0 → Trigger ADF Pipeline
   - Parameters: dataBlob, hashBlob, validationResult

4. ADF Pipeline: pl_Excel_HRPayroll_DataLoad
   ├─ Check Validation Result (If Condition)
   ├─ Log Pipeline Start
   ├─ Copy zip to staging
   ├─ Unzip files to staging/extracted/
   │  ├─ hr_data.xlsx (5 sheets)
   │  └─ payroll_data.xlsx (5 sheets)
   ├─ Process HR Data (ForEach Sheet)
   │  ├─ Sheet: Employees → Table: HR_Employees
   │  ├─ Sheet: Departments → Table: HR_Departments
   │  ├─ Sheet: Positions → Table: HR_Positions
   │  ├─ Sheet: Locations → Table: HR_Locations
   │  └─ Sheet: Performance → Table: HR_Performance
   ├─ Process Payroll Data (ForEach Sheet)
   │  ├─ Sheet: Salaries → Table: Payroll_Salaries
   │  ├─ Sheet: Bonuses → Table: Payroll_Bonuses
   │  ├─ Sheet: Deductions → Table: Payroll_Deductions
   │  ├─ Sheet: Benefits → Table: Payroll_Benefits
   │  └─ Sheet: Timesheets → Table: Payroll_Timesheets
   ├─ Copy Files to Processed Folder
   │  ├─ hr_data.xlsx → processed-test/company_A/HR/
   │  └─ payroll_data.xlsx → processed-test/company_A/Payroll/
   └─ Log Pipeline End

5. If exitCode != 0 → Log error and stop
```

## File Structure

### Input (landingtest container):
```
company_A_hr_payroll.zip
  ├─ hr_data.xlsx
  │  ├─ Employees (10 records)
  │  ├─ Departments (4 records)
  │  ├─ Positions (8 records)
  │  ├─ Locations (3 records)
  │  └─ Performance (8 records)
  └─ payroll_data.xlsx
     ├─ Salaries (10 records)
     ├─ Bonuses (6 records)
     ├─ Deductions (10 records)
     ├─ Benefits (8 records)
     └─ Timesheets (10 records)

hr_payroll_excel.hash (SHA512 hashes)
```

### Staging (staging container):
```
staging/
  ├─ company_A_hr_payroll.zip (temp copy)
  └─ extracted/
     ├─ hr_data.xlsx
     └─ payroll_data.xlsx
```

### Output (processed-test container):
```
processed-test/
  └─ company_A/
      ├─ HR/
      │  └─ hr_data.xlsx
      └─ Payroll/
          └─ payroll_data.xlsx
```

## Database Tables

All 10 tables created in HRPayrollDB:

### HR Tables:
1. **HR_Employees** - EmployeeID, FirstName, LastName, Email, Department, HireDate, Salary
2. **HR_Departments** - DepartmentID, DepartmentName, ManagerID, Location, Budget
3. **HR_Positions** - PositionID, PositionTitle, DepartmentID, MinSalary, MaxSalary
4. **HR_Locations** - LocationID, BuildingName, Address, City, State, ZipCode, Capacity
5. **HR_Performance** - ReviewID, EmployeeID, ReviewDate, Rating, Reviewer, Comments

### Payroll Tables:
6. **Payroll_Salaries** - PayrollID, EmployeeID, PayPeriod, GrossPay, Deductions, NetPay, PaymentDate
7. **Payroll_Bonuses** - BonusID, EmployeeID, BonusType, Amount, BonusDate, Reason
8. **Payroll_Deductions** - DeductionID, EmployeeID, DeductionType, Amount, DeductionDate
9. **Payroll_Benefits** - BenefitID, EmployeeID, BenefitType, Provider, MonthlyPremium, StartDate
10. **Payroll_Timesheets** - TimesheetID, EmployeeID, WeekEnding, RegularHours, OvertimeHours, TotalHours

## ADF Pipeline Components

### Pipeline: pl_Excel_HRPayroll_DataLoad

**Parameters:**
- `dataBlob` (string): company_A_hr_payroll.zip
- `hashBlob` (string): hr_payroll_excel.hash
- `validationResult` (int): Exit code from validation function (0=pass, 1=fail)

**Activities:**

1. **Check Validation Result** (If Condition)
   - Condition: `@equals(pipeline().parameters.validationResult, 0)`
   - If True: Continue to processing
   - If False: Execute error logging

2. **Log Pipeline Start** (Stored Procedure)
   - SP: `sp_StartPipelineExecution`
   - Inputs: PipelineRunID, PipelineName, SourceFileName

3. **Copy Zip to Staging** (Copy Data)
   - Source: landingtest/company_A_hr_payroll.zip
   - Sink: staging/company_A_hr_payroll.zip

4. **Unzip Files** (Custom Activity or Azure Function)
   - Input: staging/company_A_hr_payroll.zip
   - Output: staging/extracted/hr_data.xlsx, staging/extracted/payroll_data.xlsx

5. **Process HR Data** (ForEach Loop)
   - Items: Array of HR sheet configurations
   ```json
   [
     {"sheet": "Employees", "table": "HR_Employees"},
     {"sheet": "Departments", "table": "HR_Departments"},
     {"sheet": "Positions", "table": "HR_Positions"},
     {"sheet": "Locations", "table": "HR_Locations"},
     {"sheet": "Performance", "table": "HR_Performance"}
   ]
   ```

   For each item:
   - 5a. **Log Activity Start** (Stored Procedure)
   - 5b. **Load Excel Sheet to Table** (Copy Data)
        - Source: Excel dataset (staging/extracted/hr_data.xlsx, sheet name)
        - Sink: SQL table (dynamic table name)
   - 5c. **Log Activity End** (Stored Procedure)

6. **Process Payroll Data** (ForEach Loop)
   - Items: Array of Payroll sheet configurations
   ```json
   [
     {"sheet": "Salaries", "table": "Payroll_Salaries"},
     {"sheet": "Bonuses", "table": "Payroll_Bonuses"},
     {"sheet": "Deductions", "table": "Payroll_Deductions"},
     {"sheet": "Benefits", "table": "Payroll_Benefits"},
     {"sheet": "Timesheets", "table": "Payroll_Timesheets"}
   ]
   ```

7. **Copy HR File to Processed** (Copy Data)
   - Source: staging/extracted/hr_data.xlsx
   - Sink: processed-test/company_A/HR/hr_data.xlsx

8. **Copy Payroll File to Processed** (Copy Data)
   - Source: staging/extracted/payroll_data.xlsx
   - Sink: processed-test/company_A/Payroll/payroll_data.xlsx

9. **Log Pipeline End** (Stored Procedure)
   - SP: `sp_EndPipelineExecution`
   - Status: Succeeded
   - RecordsProcessed: Total records loaded

**Error Handling:**
- Each activity has failure path
- On failure: Execute `sp_LogError`
- Update pipeline status to Failed

## Linked Services (Already Created)

1. **LS_BlobStorage** - Connection to stteststorage2025
2. **LS_AzureSqlDatabase** - Connection to HRPayrollDB
3. **LS_AzureFunction** - Connection to func-data-validation-dev

## Datasets Required

### Binary Datasets:
1. **DS_LandingZip** - Binary dataset for zip in landingtest
2. **DS_StagingZip** - Binary dataset for zip in staging
3. **DS_HRProcessed** - Binary dataset for hr_data.xlsx in processed-test/company_A/HR/
4. **DS_PayrollProcessed** - Binary dataset for payroll_data.xlsx in processed-test/company_A/Payroll/

### Excel Datasets:
5. **DS_HRExcel** - Excel dataset for hr_data.xlsx (parameterized sheet name)
6. **DS_PayrollExcel** - Excel dataset for payroll_data.xlsx (parameterized sheet name)

### SQL Datasets:
7. **DS_SQL_Dynamic** - AzureSqlTable dataset with parameterized table name

## Implementation Notes

### Excel Processing Challenge:
ADF's native Excel connector has limitations:
- Cannot directly read Excel from blob storage (needs HTTP endpoint or file share)
- Can only specify one sheet at a time

### Solution Approach:
**Option 1: Azure Function + CSV Conversion (Recommended)**
- Create Azure Function to convert Excel sheets to CSV
- Function triggered after unzip step
- Converts all sheets to individual CSV files
- ADF reads CSV files and loads to database

**Option 2: Use Binary Copy + Python Script**
- Copy Excel files as binary
- Use Python script in Azure Function or Databricks
- Python reads Excel using openpyxl
- Inserts data directly to database
- ADF just orchestrates and monitors

**Option 3: Use ADF Dataflow**
- Copy Excel files to staging
- Use Dataflow to read Excel
- Transform and load to database

For this implementation, we'll use **Option 1** as it's most scalable and maintainable.

## Enhanced Pipeline Flow with CSV Conversion

```
1. Unzip Files → staging/extracted/
2. Call Azure Function: ExcelToCSV
   Input: staging/extracted/hr_data.xlsx
   Output: staging/csv/Employees.csv, Departments.csv, etc.
3. Call Azure Function: ExcelToCSV
   Input: staging/extracted/payroll_data.xlsx
   Output: staging/csv/Salaries.csv, Bonuses.csv, etc.
4. ForEach CSV file → Load to corresponding table
5. Copy original Excel files to processed folder
6. Cleanup staging area
```

## Performance Metrics

- **Expected Duration**: 2-3 minutes end-to-end
- **Validation**: ~15 seconds
- **Unzip + Convert**: ~20 seconds
- **Data Load**: ~30 seconds per file (10 files = ~5 minutes if sequential, ~1 minute if parallel)
- **File Copy**: ~10 seconds

## Monitoring Queries

```sql
-- Check recent executions
SELECT TOP 10
    ExecutionID, PipelineName, SourceFileName,
    StartTime, EndTime, Status, RecordsProcessed
FROM PipelineExecutionLog
WHERE PipelineName = 'pl_Excel_HRPayroll_DataLoad'
ORDER BY StartTime DESC;

-- Check activity details
SELECT
    a.ActivityName, a.ActivityType,
    a.StartTime, a.EndTime, a.Status,
    a.RecordsRead, a.RecordsWritten
FROM PipelineActivityLog a
JOIN PipelineExecutionLog e ON a.ExecutionID = e.ExecutionID
WHERE e.PipelineName = 'pl_Excel_HRPayroll_DataLoad'
ORDER BY a.StartTime DESC;
```

## Next Steps

1. Create Azure Function: ExcelToCSV
   - Input: Excel file path in blob storage
   - Output: Multiple CSV files (one per sheet)

2. Create ADF Datasets for CSV files

3. Create ADF Pipeline with all activities

4. Test end-to-end flow

5. Monitor and optimize performance
