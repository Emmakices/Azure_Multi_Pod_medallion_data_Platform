# Hash Validation Pipeline - Quick Start Guide

## Overview

This guide shows you how to run the hash validation pipeline to test your data files. The system validates ZIP files against SHA512 hash files to ensure data integrity.

---

## Prerequisites Check

Before running validation, ensure you have:

✅ **Azure CLI installed and authenticated**
```bash
# Check if Azure CLI is installed
az --version

# Login to Azure (if not already logged in)
az login
```

✅ **Access to the Azure resources**
```bash
# Verify access to storage account
az storage account show \
  --name stdldevshared77b5h3 \
  --resource-group rg-platform-dev

# Verify access to function app
az functionapp show \
  --name func-hash-validation-dev \
  --resource-group rg-platform-dev
```

✅ **PowerShell 7+ (for local testing only)**
```bash
pwsh --version
# or
powershell --version
```

---

## Method 1: Run Validation via REST API (Simplest)

### Step 1: Navigate to Project Directory

```bash
cd production_pipeline_modernization
```

### Step 2: Test with PASS Scenario (Valid Data)

```bash
curl -X POST \
  "https://func-hash-validation-dev.azurewebsites.net/api/validatehash?code=YOUR_FUNCTION_KEY_HERE" \
  -H "Content-Type: application/json" \
  -d "@test_data/test_event_pass.json"
```

**Expected Output:**
```json
{
  "status": "PASS",
  "timestamp": "2025-10-28 15:12:29",
  "filesExtracted": 3,
  "exitCode": 0,
  "okCount": 3,
  "failCount": 0,
  "message": "All files validated successfully"
}
```

### Step 3: Test with FAIL Scenario (Corrupted Data)

```bash
curl -X POST \
  "https://func-hash-validation-dev.azurewebsites.net/api/validatehash?code=YOUR_FUNCTION_KEY_HERE" \
  -H "Content-Type: application/json" \
  -d "@test_data/test_event_fail.json"
```

**Expected Output:**
```json
{
  "status": "FAIL",
  "timestamp": "2025-10-28 15:13:36",
  "filesExtracted": 3,
  "exitCode": 3,
  "okCount": 2,
  "failCount": 1,
  "message": "Validation failed: Hash mismatch or file discrepancies found",
  "validationDetails": "OK: departments.csv\nFAIL: employees.csv\nOK: payroll.csv"
}
```

---

## Method 2: Upload Your Own Files

### Step 1: Prepare Your Data

Create a ZIP file containing your CSV files:

```bash
# Example: Create a ZIP from your data files
cd your_data_folder
zip -r my_data_2025-10-28.zip *.csv
```

### Step 2: Generate Hash File

Use the provided script to generate hashes:

```bash
cd production_pipeline_modernization/test_data

# Create a script to generate hashes for your files
powershell -ExecutionPolicy Bypass -File gen_clean_hash.ps1
```

Or generate manually:

```powershell
# Generate hash file from your extracted CSV files
$files = Get-ChildItem -Path your_data_folder -File *.csv | Sort-Object Name
$hashes = @()
foreach ($file in $files) {
    $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA512).Hash.ToLower()
    $hashes += "$hash|$($file.Name)"
    Write-Host "$($file.Name): $hash"
}

# Write without BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines("my_data_2025-10-28.hash", $hashes, $utf8NoBom)
```

### Step 3: Upload to Azure Storage

```bash
# Upload your ZIP file
az storage blob upload \
  --account-name stdldevshared77b5h3 \
  --container-name test \
  --name my_data_2025-10-28.zip \
  --file my_data_2025-10-28.zip \
  --auth-mode key

# Upload your hash file
az storage blob upload \
  --account-name stdldevshared77b5h3 \
  --container-name test \
  --name my_data_2025-10-28.hash \
  --file my_data_2025-10-28.hash \
  --auth-mode key
```

### Step 4: Create Test Event

Create a JSON file (e.g., `my_test_event.json`):

```json
[
  {
    "topic": "/subscriptions/e97fa8c6-457d-495f-aa82-0d87e72f5842/resourceGroups/rg-platform-dev/providers/Microsoft.Storage/storageAccounts/stdldevshared77b5h3",
    "subject": "/blobServices/default/containers/test/blobs/my_data_2025-10-28.zip",
    "eventType": "Microsoft.Storage.BlobCreated",
    "eventTime": "2025-10-28T14:30:00.0000000Z",
    "id": "my-test-event-12345",
    "data": {
      "api": "PutBlob",
      "contentType": "application/x-zip-compressed",
      "contentLength": 824,
      "blobType": "BlockBlob",
      "url": "https://stdldevshared77b5h3.blob.core.windows.net/test/my_data_2025-10-28.zip"
    },
    "dataVersion": "",
    "metadataVersion": "1"
  }
]
```

### Step 5: Run Validation

```bash
curl -X POST \
  "https://func-hash-validation-dev.azurewebsites.net/api/validatehash?code=YOUR_FUNCTION_KEY_HERE" \
  -H "Content-Type: application/json" \
  -d "@my_test_event.json"
```

---

## Method 3: Test Locally (Without Azure Function)

### Step 1: Extract Your ZIP File

```bash
cd production_pipeline_modernization/test_data

# Create test directory
mkdir local_test
cd local_test

# Extract ZIP
unzip ../valid_data_2025-10-28.zip
```

### Step 2: Run Validation Script

```bash
# Run the validation script
powershell -ExecutionPolicy Bypass -File ../scripts/hash.ps1 \
  -Mode Validate \
  -HashFile ../valid_data_2025-10-28.hash \
  -RootPath . \
  -OutputFile validation_output.txt

# Check exit code
echo $?
```

**Exit Codes:**
- `0` = All files validated successfully ✅
- `1` = Parameter error ❌
- `2` = File not found ❌
- `3` = Validation failed (hash mismatch) ❌

### Step 3: View Results

```bash
# View validation output
cat validation_output.txt
```

---

## Understanding the Results

### Response Fields

| Field | Description | Example |
|-------|-------------|---------|
| `status` | Overall validation result | `PASS` or `FAIL` |
| `exitCode` | Script exit code | `0` (success), `3` (failed) |
| `okCount` | Number of files that passed | `3` |
| `failCount` | Number of files that failed | `1` |
| `missingCount` | Number of expected files not found | `0` |
| `extraCount` | Number of unexpected extra files | `0` |
| `filesExtracted` | Total files extracted from ZIP | `3` |
| `validationDetails` | Line-by-line validation results | See below |

### Validation Details Format

```
OK       : file1.csv
OK       : file2.csv
FAIL     : file3.csv
MISSING  : file4.csv
EXTRA    : unexpected_file.csv

SUMMARY: OK=2 FAIL=1 MISSING=1 EXTRA=1
```

### Status Interpretation

#### ✅ PASS - All Good!
```json
{
  "status": "PASS",
  "exitCode": 0,
  "okCount": 3,
  "failCount": 0,
  "missingCount": 0,
  "extraCount": 0
}
```
**Meaning:** All files validated successfully. Data integrity confirmed.

#### ❌ FAIL - Hash Mismatch
```json
{
  "status": "FAIL",
  "exitCode": 3,
  "okCount": 2,
  "failCount": 1
}
```
**Meaning:** One or more files have different content than expected. Possible data tampering or corruption.

#### ❌ FAIL - Missing Files
```json
{
  "status": "FAIL",
  "exitCode": 3,
  "missingCount": 1
}
```
**Meaning:** Expected files are missing from the ZIP.

#### ❌ FAIL - Extra Files
```json
{
  "status": "FAIL",
  "exitCode": 3,
  "extraCount": 1
}
```
**Meaning:** Unexpected files found in the ZIP.

---

## Troubleshooting

### Issue 1: "Function key is invalid"

**Error:**
```json
{
  "error": "Unauthorized"
}
```

**Solution:**
Get the current function key:
```bash
az functionapp function keys list \
  --name func-hash-validation-dev \
  --resource-group rg-platform-dev \
  --function-name validatehash
```

### Issue 2: "Blob not found"

**Error:**
```json
{
  "status": "error",
  "message": "Failed to download blob"
}
```

**Solution:**
Verify the blob exists:
```bash
az storage blob list \
  --account-name stdldevshared77b5h3 \
  --container-name test \
  --auth-mode key
```

### Issue 3: "Hash file not found"

**Error:**
```json
{
  "status": "error",
  "message": "Failed to download hash file"
}
```

**Solution:**
Ensure the hash file has the same name as the ZIP (but with `.hash` extension):
- ZIP: `my_data_2025-10-28.zip`
- Hash: `my_data_2025-10-28.hash` ← Must match!

### Issue 4: All files showing as FAIL (but should pass)

**Possible Causes:**
1. **BOM in hash file** - Regenerate hash file using the script (ensures no BOM)
2. **Wrong line endings** - Use UTF-8 without BOM
3. **Extra spaces** - Check hash file has format: `hash|filename` (no spaces)

**Solution:**
```bash
# Regenerate hash file properly
cd production_pipeline_modernization/test_data
powershell -ExecutionPolicy Bypass -File gen_clean_hash.ps1
```

### Issue 5: Function timeout or no response

**Error:**
```
502 - Web server received an invalid response
```

**Solution:**
Function may be cold-starting or restarting. Wait 15-20 seconds and try again.

Check function status:
```bash
az functionapp show \
  --name func-hash-validation-dev \
  --resource-group rg-platform-dev \
  --query "state"
```

### Issue 6: Permission denied when uploading files

**Error:**
```
ERROR: You do not have the required permissions
```

**Solution:**
Use `--auth-mode key` instead of `--auth-mode login`:
```bash
az storage blob upload \
  --account-name stdldevshared77b5h3 \
  --container-name test \
  --name my_file.zip \
  --file my_file.zip \
  --auth-mode key  # ← Add this
```

---

## Quick Reference Commands

### Check Azure Resources
```bash
# List blobs in container
az storage blob list \
  --account-name stdldevshared77b5h3 \
  --container-name test \
  --auth-mode key

# Check function app status
az functionapp show \
  --name func-hash-validation-dev \
  --resource-group rg-platform-dev
```

### View Function Logs
```bash
# Stream live logs
az webapp log tail \
  --name func-hash-validation-dev \
  --resource-group rg-platform-dev
```

### Download Validation Results
```bash
# Download a specific blob
az storage blob download \
  --account-name stdldevshared77b5h3 \
  --container-name test \
  --name my_data_2025-10-28.zip \
  --file downloaded.zip \
  --auth-mode key
```

### Generate Hash from Local Files
```bash
# Quick one-liner to generate hash file
cd your_data_folder
powershell -Command "Get-ChildItem *.csv | Sort-Object Name | ForEach-Object { $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA512).Hash.ToLower(); \"$hash|$($_.Name)\" } | Out-File -Encoding utf8 -FilePath hashes.hash"
```

---

## Common Workflows

### Workflow 1: Validate New Data Delivery

```bash
# 1. Receive ZIP file
# 2. Generate expected hashes from source
cd source_data_folder
powershell -ExecutionPolicy Bypass -File generate_hash.ps1

# 3. Upload both files to Azure
az storage blob upload --account-name stdldevshared77b5h3 --container-name test --name data.zip --file data.zip --auth-mode key
az storage blob upload --account-name stdldevshared77b5h3 --container-name test --name data.hash --file data.hash --auth-mode key

# 4. Trigger validation
curl -X POST "https://func-hash-validation-dev.azurewebsites.net/api/validatehash?code=..." -H "Content-Type: application/json" -d "@event.json"

# 5. Check result
# - PASS: Data is valid, proceed with processing
# - FAIL: Data is corrupted, reject and notify sender
```

### Workflow 2: Test Before Production

```bash
# 1. Test locally first
cd test_data
unzip test_file.zip -d local_test
powershell -ExecutionPolicy Bypass -File ../scripts/hash.ps1 -Mode Validate -HashFile test.hash -RootPath local_test

# 2. If local test passes, test in Azure
curl -X POST "https://func-hash-validation-dev.azurewebsites.net/api/validatehash?code=..." -H "Content-Type: application/json" -d "@test_event.json"

# 3. If Azure test passes, deploy to production
```

### Workflow 3: Investigate Failed Validation

```bash
# 1. Download the failed files
az storage blob download --account-name stdldevshared77b5h3 --container-name test --name failed_data.zip --file failed.zip --auth-mode key
az storage blob download --account-name stdldevshared77b5h3 --container-name test --name failed_data.hash --file failed.hash --auth-mode key

# 2. Extract and inspect
unzip failed.zip -d investigation
cat failed.hash

# 3. Calculate actual hashes
cd investigation
for file in *.csv; do
  echo "$file:"
  powershell -Command "(Get-FileHash -Path '$file' -Algorithm SHA512).Hash.ToLower()"
done

# 4. Compare with expected hashes in failed.hash
# 5. Identify which file(s) have mismatched hashes
```

---

## Testing Checklist

Before validating important data, complete this checklist:

- [ ] Azure CLI is installed and authenticated
- [ ] Access to storage account confirmed
- [ ] Access to function app confirmed
- [ ] Test event JSON file created
- [ ] Data ZIP file prepared
- [ ] Hash file generated (without BOM)
- [ ] Both files uploaded to Azure test container
- [ ] Test with sample data successful (PASS scenario)
- [ ] Test with corrupted data successful (FAIL scenario)
- [ ] Function logs reviewed for errors
- [ ] Results interpretation understood

---

## Example: Complete End-to-End Test

Here's a complete example from start to finish:

```bash
# Navigate to project
cd C:\Users\User\Desktop\Delta_lake_project\production_pipeline_modernization

# Test PASS scenario
echo "Testing PASS scenario..."
curl -X POST \
  "https://func-hash-validation-dev.azurewebsites.net/api/validatehash?code=YOUR_FUNCTION_KEY_HERE" \
  -H "Content-Type: application/json" \
  -d "@test_data/test_event_pass.json"

# Expected: {"status": "PASS", "exitCode": 0, ...}

# Test FAIL scenario
echo "Testing FAIL scenario..."
curl -X POST \
  "https://func-hash-validation-dev.azurewebsites.net/api/validatehash?code=YOUR_FUNCTION_KEY_HERE" \
  -H "Content-Type: application/json" \
  -d "@test_data/test_event_fail.json"

# Expected: {"status": "FAIL", "exitCode": 3, "failCount": 1, ...}

echo "All tests completed!"
```

---

## Next Steps

After successfully running validation:

1. **Review the Implementation Guide** - For detailed architecture and troubleshooting: `IMPLEMENTATION_GUIDE.md`
2. **Set up Event Grid** - Automate validation on file upload (see Implementation Guide)
3. **Integrate with Data Pipeline** - Use validation results in your data processing workflow
4. **Monitor with Application Insights** - Set up alerts for validation failures

---

## Support

For issues or questions:
- Check the full **IMPLEMENTATION_GUIDE.md** for detailed troubleshooting
- Review Azure Function logs: `az webapp log tail --name func-hash-validation-dev --resource-group rg-platform-dev`
- Check Application Insights in Azure Portal

**Document Version:** 1.0
**Last Updated:** 2025-10-28
**Related Docs:** IMPLEMENTATION_GUIDE.md
