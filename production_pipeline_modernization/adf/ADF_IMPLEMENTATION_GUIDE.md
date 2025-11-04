# ADF Native Implementation Guide - Excel Multi-Sheet Pipeline

## Overview
This guide provides complete ADF-native solution for processing multi-sheet Excel files without external functions.

## Prerequisites
✅ Linked Services created: LS_BlobStorage, LS_AzureSqlDatabase, LS_AzureFunction
✅ Database tables created (10 total)
✅ Test data uploaded: hr_payroll_data.zip + hr_payroll_data.hash

## Problem & Solution

**Problem**: ADF's Excel connector can only read ONE sheet at a time, and needs unzipped Excel files.

**Solution**:
1. Use Copy Activity to unzip (ADF native)
2. Use ForEach loops with parameterized datasets
3. Direct Excel → SQL copy for each sheet

## Step 1: Create Datasets

### 1.1 Excel Source Dataset (ds_excel_source)
**Location**: `adf/datasets/ds_excel_source.json`
Already created - Parameterized with company, fileName, sheetName

### 1.2 SQL Sink Dataset (ds_sql_sink)
**Location**: `adf/datasets/ds_sql_sink.json`
Already created - Parameterized with tableName

### 1.3 Binary Datasets for Zip Operations

Create these via Azure Portal or CLI:

**ds_landing_zip**: Binary dataset pointing to landingtest container
**ds_staging_binary**: Binary dataset pointing to staging container

##Step 2: Create the Main Pipeline

### Pipeline Name: pl_HRPayroll_ExcelLoad

### Pipeline Parameters:
```json
{
  "dataBlob": "hr_payroll_data.zip",
  "hashBlob": "hr_payroll_data.hash",
  "validationResult": 0
}
```

### Pipeline Variables:
```json
{
  "companies": ["company_A", "company_B"],
  "hrSheets": [
    {"sheet": "Employees", "table": "HR_Employees"},
    {"sheet": "Departments", "table": "HR_Departments"},
    {"sheet": "Positions", "table": "HR_Positions"},
    {"sheet": "Locations", "table": "HR_Locations"},
    {"sheet": "Performance", "table": "HR_Performance"}
  ],
  "payrollSheets": [
    {"sheet": "Salaries", "table": "Payroll_Salaries"},
    {"sheet": "Bonuses", "table": "Payroll_Bonuses"},
    {"sheet": "Deductions", "table": "Payroll_Deductions"},
    {"sheet": "Benefits", "table": "Payroll_Benefits"},
    {"sheet": "Timesheets", "table": "Payroll_Timesheets"}
  ]
}
```

### Activities Flow:

```
1. Check Validation Result (If Condition)
   ├─ True: Continue
   └─ False: Log Error & Stop

2. Log Pipeline Start (Stored Procedure)
   - Call: sp_StartPipelineExecution

3. Copy Zip to Staging (Copy Activity)
   - Source: landingtest/hr_payroll_data.zip
   - Sink: staging/hr_payroll_data.zip

4. Extract Zip (ForEach)
   - Items: @pipeline().parameters.dataBlob
   - Use ZipDeflate extraction

5. ForEach Company (ForEach Loop)
   - Items: @variables('companies')

   5a. ForEach HR Sheet (ForEach Loop)
       - Items: @variables('hrSheets')

       5a.1 Copy HR Sheet to SQL (Copy Activity)
            - Source: Excel dataset
              * company: @item() from parent
              * fileName: "hr_data.xlsx"
              * sheetName: @item().sheet
            - Sink: SQL dataset
              * tableName: @item().table
            - Write Method: Append

   5b. ForEach Payroll Sheet (ForEach Loop)
       - Items: @variables('payrollSheets')

       5b.1 Copy Payroll Sheet to SQL (Copy Activity)
            - Source: Excel dataset
              * company: @item() from parent
              * fileName: "payroll_data.xlsx"
              * sheetName: @item().sheet
            - Sink: SQL dataset
              * tableName: @item().table
            - Write Method: Append

6. Log Pipeline End (Stored Procedure)
   - Call: sp_EndPipelineExecution
```

## Step 3: Simplified Approach (Recommended for Testing)

Since the full nested ForEach can be complex, start with a simpler version:

### Simplified Pipeline: pl_HRPayroll_Simple

**Test with just Company A, HR Data only:**

```
1. Copy Zip to Staging
2. Extract Zip
3. Copy Activity: Employees sheet → HR_Employees
   - Source: ds_excel_source
     * company: "company_A"
     * fileName: "hr_data.xlsx"
     * sheetName: "Employees"
   - Sink: ds_sql_sink
     * tableName: "HR_Employees"

4. Repeat for other 4 HR sheets
5. Test and verify
```

## Step 4: Unzip Challenge & Solution

**Problem**: ADF doesn't have native "unzip" activity.

**Solutions**:

### Option A: Use Copy Activity with Compression Type
```json
{
  "type": "Copy",
  "inputs": [{"referenceName": "ds_landing_zip"}],
  "outputs": [{"referenceName": "ds_staging_binary"}],
  "typeProperties": {
    "source": {
      "type": "BinarySource",
      "storeSettings": {
        "type": "AzureBlobStorageReadSettings"
      }
    },
    "sink": {
      "type": "BinarySink",
      "storeSettings": {
        "type": "AzureBlobStorageWriteSettings"
      }
    },
    "preserveCompressionFileNameAsFolder": false
  }
}
```

### Option B: Azure Function for Unzip (Recommended)
Create a simple PowerShell Azure Function:

```powershell
# unzip-function/run.ps1
param($Request)

$zipBlob = $Request.Query.zipBlob
$container = $Request.Query.container

# Download zip
# Extract to staging
# Return success
```

Then call it from ADF using Azure Function activity.

### Option C: Manual Unzip for Testing
For initial testing, manually unzip and upload files to staging:
```
staging/
  ├─ company_A/
  │  ├─ hr_data.xlsx
  │  └─ payroll_data.xlsx
  └─ company_B/
     ├─ hr_data.xlsx
     └─ payroll_data.xlsx
```

## Step 5: Create Datasets in ADF

Use Azure CLI to create datasets:

```bash
# Create Excel source dataset
az datafactory dataset create \
  --resource-group rg-platform-dev \
  --factory-name adf-dev-platform \
  --name ds_excel_source \
  --properties @adf/datasets/ds_excel_source.json

# Create SQL sink dataset
az datafactory dataset create \
  --resource-group rg-platform-dev \
  --factory-name adf-dev-platform \
  --name ds_sql_sink \
  --properties @adf/datasets/ds_sql_sink.json
```

## Step 6: Testing Strategy

### Test 1: Single Sheet Copy
Test copying just one sheet to verify connectivity:
- Company A → HR Data → Employees sheet → HR_Employees table

### Test 2: All HR Sheets for Company A
Test all 5 HR sheets for one company

### Test 3: Full Company A
Test both HR and Payroll for Company A

### Test 4: Both Companies
Test complete pipeline with both companies

## Alternative: Use ADF UI

Instead of JSON files, you can build everything in Azure Data Factory Studio UI:

1. Go to https://adf.azure.com
2. Select adf-dev-platform
3. Create datasets visually
4. Create pipeline visually
5. Test directly

## Next Steps

1. **Immediate**: Manually unzip test files to staging container
2. **Create**: Simple pipeline with 1 sheet copy
3. **Test**: Verify data loads correctly
4. **Expand**: Add ForEach loops
5. **Complete**: Add all sheets and companies

## Key Mapping Reference

### Company A - HR Data
| Sheet | Table |
|-------|-------|
| Employees | HR_Employees |
| Departments | HR_Departments |
| Positions | HR_Positions |
| Locations | HR_Locations |
| Performance | HR_Performance |

### Company A - Payroll Data
| Sheet | Table |
|-------|-------|
| Salaries | Payroll_Salaries |
| Bonuses | Payroll_Bonuses |
| Deductions | Payroll_Deductions |
| Benefits | Payroll_Benefits |
| Timesheets | Payroll_Timesheets |

*(Same for Company B)*

## Troubleshooting

**Error: "Cannot read Excel file"**
- Ensure file is unzipped in staging
- Verify file path and sheet name

**Error: "Table not found"**
- Verify table names match exactly (case-sensitive)
- Check database connection

**Error: "Column mismatch"**
- Excel headers must match SQL column names exactly
- Use column mapping if needed
