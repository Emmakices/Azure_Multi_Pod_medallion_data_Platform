# Data Validation Pipeline - Setup Documentation

**Date**: 2025-11-03
**Status**: Production Ready

## Overview
This is a clean rebuild of the HR/Payroll data validation infrastructure using Azure Functions and Azure Blob Storage.

---

## Infrastructure Components

### 1. Storage Account
- **Name**: `stteststorage2025`
- **Type**: ADLS Gen2 (Hierarchical namespace enabled)
- **Location**: Same as resource group
- **Key**: `<REDACTED - Use Azure Portal to retrieve storage account key>`

#### Containers:
1. **landingtest** - Incoming data files
   - Contains: data.zip, hash files
   - Purpose: Landing zone for uploaded files

2. **processed-test** - Validated and processed data
   - Structure:
     ```
     processed-test/
     ├── company_A/
     │   ├── HR/
     │   └── payroll/
     └── company_B/
         ├── HR/
         └── payroll/
     ```

### 2. Azure Function App
- **Name**: `func-data-validation-dev`
- **Runtime**: PowerShell 7.4
- **Type**: HTTP Trigger
- **Authentication**: Function key

#### Function: data-validation
- **URL**: `https://func-data-validation-dev.azurewebsites.net/api/data-validation`
- **Access Key**: `<REDACTED - Retrieve from Azure Portal Function App Keys>`

#### Environment Variables:
- `STORAGE_ACCOUNT_KEY`: Storage account access key

#### Features:
- ✅ Downloads files from Azure Blob Storage using REST API
- ✅ Auto-detects wrapper folders in zip files
- ✅ Validates files using SHA512 hash comparison
- ✅ Returns detailed JSON response with validation results
- ✅ Fast cold start (no heavy dependencies)

---

## How It Works

### Validation Flow:
1. **Input**: HTTP request with query parameters:
   - `dataBlob`: Name of zip file (e.g., "data.zip")
   - `hashBlob`: Name of hash file (e.g., "hash-2025-10-29_11-07-36.txt")
   - `storageAccount`: Storage account name (e.g., "stteststorage2025")
   - `container`: Container name (e.g., "landingtest")

2. **Process**:
   - Downloads both files from blob storage
   - Extracts zip file to temp directory
   - Auto-detects if files are in a wrapper folder
   - Runs hash.ps1 validation script
   - Compares SHA512 hashes of all files

3. **Output**: JSON response with:
   - `status`: "success" or "validation_failed" or "error"
   - `exitCode`: 0 (success), 3 (validation failed), other (error)
   - `validationDetails`: Full validation report
   - `message`: Human-readable summary
   - `timestamp`: Validation timestamp

### Example Request:
```bash
curl "https://func-data-validation-dev.azurewebsites.net/api/data-validation?code=<FUNCTION_KEY>&dataBlob=data.zip&hashBlob=hash-2025-10-29_11-07-36.txt&storageAccount=stteststorage2025&container=landingtest"
```

### Example Response (Success):
```json
{
  "status": "success",
  "message": "Validation passed - all files are valid",
  "exitCode": 0,
  "validationDetails": "OK       : data1.txt\r\nOK       : level 1-1\\data3.txt\r\nOK       : level 1-1\\level 2-1\\data4.txt\r\nOK       : level 1-2\\data2.txt\r\n\r\nSUMMARY: OK=4 FAIL=0 MISSING=0 EXTRA=0\r\n",
  "timestamp": "2025-11-03 20:26:43"
}
```

### Example Response (Validation Failed):
```json
{
  "status": "validation_failed",
  "message": "Validation completed with issues",
  "exitCode": 3,
  "validationDetails": "FAIL     : data1.txt\r\nMISSING : data2.txt\r\nEXTRA    : extra_file.txt\r\n\r\nSUMMARY: OK=2 FAIL=1 MISSING=1 EXTRA=1\r\n",
  "timestamp": "2025-11-03 20:26:43"
}
```

---

## File Structure

### Local Development Files:
```
production_pipeline_modernization/
├── temp_function/                    # Function app source
│   ├── host.json                    # Function app configuration
│   ├── requirements.psd1            # PowerShell dependencies (empty)
│   ├── profile.ps1                  # Startup script
│   ├── data-validation/
│   │   ├── function.json           # HTTP trigger binding
│   │   ├── run.ps1                 # Main function logic
│   │   └── hash.ps1                # Validation script
│   └── function.zip                # Deployment package
└── scripts/
    └── hash.ps1                     # Original hash script
```

---

## Key Features

### 1. Smart Wrapper Folder Detection
The function automatically detects if the zip file has a single wrapper folder:
- If YES: Uses the wrapper folder as root for validation
- If NO: Uses the extract path as root

This handles both:
- `data.zip` containing `data/file1.txt, data/file2.txt`
- `data.zip` containing `file1.txt, file2.txt`

### 2. Fast Performance
- Uses REST API for blob downloads (no Az.Storage module)
- No heavy dependencies
- Fast cold start (~14 seconds)
- Efficient validation

### 3. Production Ready
- Proper error handling
- Detailed logging
- Clear JSON responses
- Secure (function key authentication)

---

## Testing Results

### Test Date: 2025-11-03
**Test File**: data.zip (4 files in wrapper folder)
**Hash File**: hash-2025-10-29_11-07-36.txt

**Result**: ✅ PASSED
- All 4 files validated successfully
- Exit code: 0
- Execution time: ~14 seconds

**Validation Details**:
- ✅ data1.txt
- ✅ level 1-1\data3.txt
- ✅ level 1-1\level 2-1\data4.txt
- ✅ level 1-2\data2.txt

---

## Deployment Instructions

### Prerequisites:
- Azure CLI installed
- PowerShell 7.4+
- Azure subscription access

### Deploy Function:
```powershell
# 1. Package function
cd C:\Users\User\Desktop\Delta_lake_project\production_pipeline_modernization\temp_function
Compress-Archive -Path * -DestinationPath function.zip -Force

# 2. Deploy to Azure
az functionapp deployment source config-zip `
  --resource-group rg-platform-dev `
  --name func-data-validation-dev `
  --src function.zip `
  --build-remote false

# 3. Configure storage account key
az functionapp config appsettings set `
  --resource-group rg-platform-dev `
  --name func-data-validation-dev `
  --settings "STORAGE_ACCOUNT_KEY=<your-storage-key>"
```

---

## Next Steps

1. **Upload Test Data**: Upload zip files and hash files to `landingtest` container
2. **Test Validation**: Call the function with test files
3. **Process Valid Data**: If validation passes, move files to `processed-test` container
4. **Error Handling**: If validation fails, move to error/quarantine location
5. **Automation**: Integrate with Azure Data Factory pipeline

---

## Maintenance

### View Logs:
```bash
az webapp log tail --resource-group rg-platform-dev --name func-data-validation-dev
```

### Update Function:
1. Modify files in `temp_function/`
2. Repackage: `Compress-Archive -Path * -DestinationPath function.zip -Force`
3. Redeploy: `az functionapp deployment source config-zip ...`

### Monitor:
- Azure Portal > Function App > Monitor
- Application Insights (if enabled)

---

## Troubleshooting

### Issue: Function returns 401 Unauthorized
**Solution**: Check function key in URL

### Issue: "Storage account key not found"
**Solution**: Verify STORAGE_ACCOUNT_KEY environment variable is set

### Issue: Validation fails with MISSING/EXTRA files
**Solution**: Check zip file structure matches hash file expectations

### Issue: Slow performance
**Solution**: Check cold start time, consider app service plan upgrade

---

## Change Log

### 2025-11-03 - Initial Setup
- Created stteststorage2025 storage account
- Created landingtest and processed-test containers
- Deployed func-data-validation-dev function
- Implemented smart wrapper folder detection
- Successfully tested validation
