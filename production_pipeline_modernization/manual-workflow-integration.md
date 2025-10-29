# Hash Validation - Manual Workflow Integration

## Current Workflow (Before Validation)

```
1. Government sends ZIP file → Uploads to blob storage
2. Person downloads ZIP to F: drive
3. Person unzips manually
4. Person copies CSV files to correct folders in blob storage
5. Hope the data is good 🤞
```

## Problem

**No way to know if data is corrupted before doing all the manual work!**

---

## New Workflow (With Validation)

```
1. Government sends ZIP + hash file → Both uploaded to blob storage
2. ✅ AUTOMATIC: Validation runs (Event Grid triggers function)
3. ✅ CHECK: Person checks validation status
   │
   ├─ PASS ✅ → Download to F: drive → Unzip → Copy to folders
   │
   └─ FAIL ❌ → Stop! Contact government, reject data
```

---

## How to Check Validation Status (3 Simple Methods)

### Method 1: Azure Portal Log Stream (Easiest)

**When to Use:** Real-time validation during upload

**Steps:**
1. Open Azure Portal
2. Navigate to: `func-hash-validation-dev` → **Log stream**
3. Upload your ZIP + hash file
4. Watch logs in real-time
5. Look for:
   - ✅ `Status: PASS` → Safe to download and process
   - ❌ `Status: FAIL` → DO NOT PROCESS

**Screenshot of what to look for:**
```
2025-10-28 23:25:59 [Information] Status: PASS
2025-10-28 23:25:59 [Information] Exit Code: 0
2025-10-28 23:25:59 [Information] OK Count: 3
2025-10-28 23:25:59 [Information] Message: All files validated successfully
```

---

### Method 2: Call Validation API Manually (Recommended)

**When to Use:** Before downloading to F: drive

**Step 1: Create a simple batch script**

Save this as `C:\scripts\check_validation.bat`:

```batch
@echo off
setlocal enabledelayedexpansion

REM Usage: check_validation.bat <filename>
REM Example: check_validation.bat payroll_2025-10-28.zip

set ZIP_FILE=%1
set CONTAINER=raw-data
set STORAGE_ACCOUNT=stdldevshared77b5h3

echo.
echo ========================================
echo Checking validation status...
echo ========================================
echo File: %ZIP_FILE%
echo Container: %CONTAINER%
echo.

REM Create temporary event file
set TEMP_EVENT=%TEMP%\validation_event.json

echo [{ > "%TEMP_EVENT%"
echo   "topic": "/subscriptions/e97fa8c6-457d-495f-aa82-0d87e72f5842/resourceGroups/rg-platform-dev/providers/Microsoft.Storage/storageAccounts/%STORAGE_ACCOUNT%", >> "%TEMP_EVENT%"
echo   "subject": "/blobServices/default/containers/%CONTAINER%/blobs/%ZIP_FILE%", >> "%TEMP_EVENT%"
echo   "eventType": "Microsoft.Storage.BlobCreated", >> "%TEMP_EVENT%"
echo   "eventTime": "2025-10-28T00:00:00.0000000Z", >> "%TEMP_EVENT%"
echo   "id": "manual-check", >> "%TEMP_EVENT%"
echo   "data": { >> "%TEMP_EVENT%"
echo     "api": "PutBlob", >> "%TEMP_EVENT%"
echo     "contentType": "application/x-zip-compressed", >> "%TEMP_EVENT%"
echo     "blobType": "BlockBlob", >> "%TEMP_EVENT%"
echo     "url": "https://%STORAGE_ACCOUNT%.blob.core.windows.net/%CONTAINER%/%ZIP_FILE%" >> "%TEMP_EVENT%"
echo   }, >> "%TEMP_EVENT%"
echo   "dataVersion": "", >> "%TEMP_EVENT%"
echo   "metadataVersion": "1" >> "%TEMP_EVENT%"
echo }] >> "%TEMP_EVENT%"

REM Call validation API
curl -X POST ^
  "https://func-hash-validation-dev.azurewebsites.net/api/validatehash?code=YOUR_FUNCTION_KEY_HERE" ^
  -H "Content-Type: application/json" ^
  -d "@%TEMP_EVENT%" ^
  --silent > "%TEMP%\validation_result.json"

REM Parse result
findstr /C:"\"status\": \"PASS\"" "%TEMP%\validation_result.json" > nul
if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo     ✅ VALIDATION PASSED
    echo ========================================
    echo.
    echo Safe to download and process this file.
    echo.
    type "%TEMP%\validation_result.json"
    echo.
    exit /b 0
) else (
    echo.
    echo ========================================
    echo     ❌ VALIDATION FAILED
    echo ========================================
    echo.
    echo DO NOT PROCESS THIS FILE!
    echo Contact data provider.
    echo.
    type "%TEMP%\validation_result.json"
    echo.
    exit /b 1
)
```

**Step 2: Usage**

```batch
REM Check if file is safe to process
cd C:\scripts
check_validation.bat payroll_2025-10-28.zip

REM If it says "VALIDATION PASSED":
REM → Download from blob storage to F: drive
REM → Unzip
REM → Copy to correct folders

REM If it says "VALIDATION FAILED":
REM → DO NOT DOWNLOAD
REM → Contact government to resend
```

---

### Method 3: PowerShell Script (More User-Friendly)

**Step 1: Create PowerShell script**

Save this as `C:\scripts\Check-DataValidation.ps1`:

```powershell
param(
    [Parameter(Mandatory=$true)]
    [string]$ZipFileName,

    [string]$ContainerName = "raw-data",

    [string]$StorageAccount = "stdldevshared77b5h3"
)

function Show-ValidationResult {
    param($Result)

    Write-Host ""
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "  VALIDATION RESULT" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "File:            $($Result.zipFile)" -ForegroundColor White
    Write-Host "Hash File:       $($Result.hashFile)" -ForegroundColor White
    Write-Host "Timestamp:       $($Result.timestamp)" -ForegroundColor White
    Write-Host "Files Extracted: $($Result.filesExtracted)" -ForegroundColor White
    Write-Host ""

    if ($Result.status -eq "PASS") {
        Write-Host "Status:          PASS ✅" -ForegroundColor Green
        Write-Host "Exit Code:       $($Result.exitCode)" -ForegroundColor Green
        Write-Host "OK Count:        $($Result.okCount)" -ForegroundColor Green
        Write-Host "Fail Count:      $($Result.failCount)" -ForegroundColor Green
        Write-Host ""
        Write-Host $Result.message -ForegroundColor Green
        Write-Host ""
        Write-Host "======================================" -ForegroundColor Green
        Write-Host "  ✅ SAFE TO DOWNLOAD AND PROCESS" -ForegroundColor Green
        Write-Host "======================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "1. Download ZIP from blob storage to F: drive" -ForegroundColor Yellow
        Write-Host "2. Unzip the files" -ForegroundColor Yellow
        Write-Host "3. Copy CSV files to correct blob storage folders" -ForegroundColor Yellow
        Write-Host ""
        return $true
    } else {
        Write-Host "Status:          FAIL ❌" -ForegroundColor Red
        Write-Host "Exit Code:       $($Result.exitCode)" -ForegroundColor Red
        Write-Host "OK Count:        $($Result.okCount)" -ForegroundColor Red
        Write-Host "Fail Count:      $($Result.failCount)" -ForegroundColor Red
        Write-Host "Missing Count:   $($Result.missingCount)" -ForegroundColor Red
        Write-Host "Extra Count:     $($Result.extraCount)" -ForegroundColor Red
        Write-Host ""
        Write-Host $Result.message -ForegroundColor Red
        Write-Host ""
        Write-Host "Validation Details:" -ForegroundColor Yellow
        Write-Host $Result.validationDetails -ForegroundColor White
        Write-Host ""
        Write-Host "======================================" -ForegroundColor Red
        Write-Host "  ❌ DO NOT PROCESS THIS FILE" -ForegroundColor Red
        Write-Host "======================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "Action required:" -ForegroundColor Yellow
        Write-Host "1. Contact data provider (government)" -ForegroundColor Yellow
        Write-Host "2. Report which files failed validation" -ForegroundColor Yellow
        Write-Host "3. Request them to resend correct data" -ForegroundColor Yellow
        Write-Host "4. DO NOT download or process this data" -ForegroundColor Yellow
        Write-Host ""
        return $false
    }
}

# Build event payload
$eventPayload = @(
    @{
        topic = "/subscriptions/e97fa8c6-457d-495f-aa82-0d87e72f5842/resourceGroups/rg-platform-dev/providers/Microsoft.Storage/storageAccounts/$StorageAccount"
        subject = "/blobServices/default/containers/$ContainerName/blobs/$ZipFileName"
        eventType = "Microsoft.Storage.BlobCreated"
        eventTime = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        id = "manual-validation-check"
        data = @{
            api = "PutBlob"
            contentType = "application/x-zip-compressed"
            blobType = "BlockBlob"
            url = "https://$StorageAccount.blob.core.windows.net/$ContainerName/$ZipFileName"
        }
        dataVersion = ""
        metadataVersion = "1"
    }
)

Write-Host "Checking validation status for: $ZipFileName" -ForegroundColor Cyan
Write-Host "Please wait..." -ForegroundColor Cyan
Write-Host ""

try {
    $response = Invoke-RestMethod -Uri "https://func-hash-validation-dev.azurewebsites.net/api/validatehash?code=YOUR_FUNCTION_KEY_HERE" `
                                  -Method Post `
                                  -Headers @{"Content-Type" = "application/json"} `
                                  -Body (ConvertTo-Json $eventPayload -Depth 10) `
                                  -TimeoutSec 300

    $isPassed = Show-ValidationResult -Result $response

    if ($isPassed) {
        exit 0
    } else {
        exit 1
    }

} catch {
    Write-Host "❌ ERROR: Failed to check validation status" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 2
}
```

**Step 2: Usage**

```powershell
# Check validation before downloading
cd C:\scripts
.\Check-DataValidation.ps1 -ZipFileName "payroll_2025-10-28.zip"

# If validation passes (green output):
# → Download and process

# If validation fails (red output):
# → DO NOT process, contact sender
```

---

## Updated Manual Workflow with Validation

### Step-by-Step Process

#### Before Processing ANY File:

**1. Upload files to blob storage**
```bash
# Government uploads (or you upload when received):
az storage blob upload --account-name stdldevshared77b5h3 --container-name raw-data --name payroll_2025-10-28.zip --file payroll.zip
az storage blob upload --account-name stdldevshared77b5h3 --container-name raw-data --name payroll_2025-10-28.hash --file payroll.hash
```

**2. Wait 30 seconds for automatic validation**
- Event Grid automatically triggers validation
- Function processes the files

**3. Check validation status**
```powershell
# Using PowerShell script
.\Check-DataValidation.ps1 -ZipFileName "payroll_2025-10-28.zip"
```

**4a. If PASS ✅:**
```bash
# Download from blob storage
az storage blob download --account-name stdldevshared77b5h3 --container-name raw-data --name payroll_2025-10-28.zip --file F:\downloads\payroll.zip

# Unzip to F: drive
cd F:\downloads
unzip payroll.zip -d F:\extracted\payroll_2025-10-28

# Copy CSV files to correct folders
copy F:\extracted\payroll_2025-10-28\employees.csv F:\data\hr\employees\
copy F:\extracted\payroll_2025-10-28\departments.csv F:\data\hr\departments\

# Upload to blob storage in correct folders
az storage blob upload --account-name stdldevshared77b5h3 --container-name processed-data --name hr/employees/employees_2025-10-28.csv --file F:\data\hr\employees\employees.csv
az storage blob upload --account-name stdldevshared77b5h3 --container-name processed-data --name hr/departments/departments_2025-10-28.csv --file F:\data\hr\departments\departments.csv
```

**4b. If FAIL ❌:**
```
1. DO NOT DOWNLOAD
2. Email government contact:
   - Subject: "Data Validation Failed - payroll_2025-10-28.zip"
   - Body: Include validation details (which files failed)
   - Request: Resend corrected data
3. Log the failure in tracking spreadsheet
4. Delete the failed files from blob storage
```

---

## Quick Reference Card (Print This!)

```
╔════════════════════════════════════════════════════════════╗
║           DATA VALIDATION CHECKLIST                        ║
╠════════════════════════════════════════════════════════════╣
║                                                            ║
║  BEFORE PROCESSING ANY DATA:                               ║
║                                                            ║
║  □ Files uploaded to blob storage (ZIP + hash)             ║
║  □ Wait 30 seconds for automatic validation                ║
║  □ Run: .\Check-DataValidation.ps1 -ZipFileName "..."      ║
║                                                            ║
║  ✅ IF PASS:                                               ║
║     → Download to F: drive                                 ║
║     → Unzip                                                ║
║     → Copy to folders                                      ║
║     → Upload to blob storage                               ║
║                                                            ║
║  ❌ IF FAIL:                                               ║
║     → DO NOT DOWNLOAD                                      ║
║     → Email government contact                             ║
║     → Log failure                                          ║
║     → Delete from blob storage                             ║
║                                                            ║
╠════════════════════════════════════════════════════════════╣
║  Validation Check Command:                                 ║
║  .\Check-DataValidation.ps1 -ZipFileName "filename.zip"    ║
╚════════════════════════════════════════════════════════════╝
```

---

## Setup Instructions

### One-Time Setup

**1. Create scripts folder**
```powershell
mkdir C:\scripts
cd C:\scripts
```

**2. Download the PowerShell script**
Copy the `Check-DataValidation.ps1` script above to `C:\scripts\Check-DataValidation.ps1`

**3. Test with sample data**
```powershell
# Test with known good data
.\Check-DataValidation.ps1 -ZipFileName "valid_data_2025-10-28.zip" -ContainerName "test"

# Test with known bad data
.\Check-DataValidation.ps1 -ZipFileName "corrupted_data_2025-10-28.zip" -ContainerName "test"
```

**4. Create desktop shortcut (optional)**
- Right-click Desktop → New → Shortcut
- Target: `powershell.exe -ExecutionPolicy Bypass -File C:\scripts\Check-DataValidation.ps1`
- Name: "Check Data Validation"

---

## For Your Presentation

### Demo Flow:

**Scenario 1: Good Data (PASS)**
```powershell
# Show them: Government sends valid data
.\Check-DataValidation.ps1 -ZipFileName "valid_data_2025-10-28.zip" -ContainerName "test"

# Result: Green screen, "SAFE TO DOWNLOAD AND PROCESS"
# Action: Download and process normally
```

**Scenario 2: Tampered Data (FAIL)**
```powershell
# Show them: Government sends corrupted data (someone changed salaries!)
.\Check-DataValidation.ps1 -ZipFileName "corrupted_data_2025-10-28.zip" -ContainerName "test"

# Result: Red screen, "DO NOT PROCESS THIS FILE"
# Action: Reject and contact sender
```

### Key Points to Highlight:

1. **Before validation:** No way to know if data is good until after manual work
2. **After validation:** Know immediately if data is safe to process
3. **Saves time:** Don't waste time downloading and unzipping bad data
4. **Saves risk:** Don't accidentally process corrupted data
5. **Automated:** Validation runs automatically on upload
6. **Simple check:** One PowerShell command before downloading

---

## Troubleshooting

### "Cannot find file in blob storage"
- Ensure both ZIP and hash files are uploaded
- Check file names match exactly (e.g., `data.zip` and `data.hash`)

### "Validation shows FAIL but data looks fine"
- Hash file might be incorrect
- Ask data provider to regenerate hash file
- Check for BOM or encoding issues in hash file

### "Script says 'Access Denied'"
- Run PowerShell as Administrator
- Or: `Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser`

---

## Summary

**What Changed:**
- Before: Download → Unzip → Copy → Hope it's good 🤞
- After: Check validation ✅ → Only process if PASS

**Benefits:**
- ✅ Know data is good BEFORE doing manual work
- ✅ Automatic integrity checking
- ✅ Catch tampering or corruption immediately
- ✅ Simple one-command check
- ✅ No more processing bad data

**Next Steps:**
1. Set up the PowerShell script (`Check-DataValidation.ps1`)
2. Test with sample data
3. Update your manual workflow documentation
4. Train team members on the new process

---

**Document Version:** 1.0
**Last Updated:** 2025-10-28
**Related Docs:** QUICK_START_GUIDE.md, NAMING_CONVENTION.md
