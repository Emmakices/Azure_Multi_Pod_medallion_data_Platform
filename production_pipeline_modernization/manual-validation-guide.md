# Manual Data Validation - Azure Portal Step-by-Step Guide

## Overview

This guide walks you through **manually validating your data files** using the Azure Portal interface. Perfect for on-demand testing without automation or command line.

---

## What You'll Do

1. ✅ Upload your ZIP and hash files to Azure Storage
2. ✅ Manually trigger the validation function
3. ✅ View validation results in real-time
4. ✅ Interpret the results (PASS or FAIL)

**Time Required:** 5-10 minutes

---

## Prerequisites

Before starting, ensure you have:
- ✅ Access to Azure Portal (https://portal.azure.com)
- ✅ Your data ZIP file
- ✅ Corresponding hash file (or we'll generate it)
- ✅ Permissions to access the storage account and function app

---

## Part 1: Prepare Your Files

### Option A: Use Existing Test Files

The test files are already uploaded to Azure:
- `valid_data_2025-10-28.zip` (PASS scenario)
- `corrupted_data_2025-10-28.zip` (FAIL scenario)

**Skip to Part 2 if using these files.**

### Option B: Prepare Your Own Files

#### Step 1: Create Hash File from Your Data

**On Windows:**

1. Open **PowerShell** (Start → type "PowerShell" → Right-click → Run as Administrator)

2. Navigate to your data folder:
```powershell
cd "C:\path\to\your\data\folder"
```

3. Run this script to generate hashes:
```powershell
# List your CSV files
Get-ChildItem *.csv | Sort-Object Name

# Generate hash file
$files = Get-ChildItem *.csv | Sort-Object Name
$hashes = @()
foreach ($file in $files) {
    $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA512).Hash.ToLower()
    $hashes += "$hash|$($file.Name)"
    Write-Host "$($file.Name): $hash"
}

# Save to file (without BOM)
$hashFileName = "mydata_2025-10-28.hash"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines("$PWD\$hashFileName", $hashes, $utf8NoBom)

Write-Host "`nHash file created: $hashFileName" -ForegroundColor Green
```

4. Verify the hash file was created:
```powershell
dir *.hash
```

#### Step 2: Create ZIP File

**Option 1 - Using Windows Explorer:**
1. Select all your CSV files
2. Right-click → **"Send to"** → **"Compressed (zipped) folder"**
3. Rename to match your hash file: `mydata_2025-10-28.zip`

**Option 2 - Using PowerShell:**
```powershell
# Create ZIP file
Compress-Archive -Path *.csv -DestinationPath "mydata_2025-10-28.zip"
```

#### Step 3: Verify File Names Match

**CRITICAL:** Your files must have matching names:
- ✅ `mydata_2025-10-28.zip`
- ✅ `mydata_2025-10-28.hash`

**Not:**
- ❌ `mydata.zip` and `mydata_2025-10-28.hash`
- ❌ `mydata_2025-10-28.zip` and `hashes.hash`

---

## Part 2: Upload Files to Azure Storage

### Step 1: Login to Azure Portal

1. Open your web browser
2. Go to: **https://portal.azure.com**
3. Sign in with your Azure credentials
4. Wait for the portal to load

### Step 2: Navigate to Storage Account

**Click-by-Click:**

1. In the top search bar, type: **`stdldevshared77b5h3`**
2. Click on **"stdldevshared77b5h3 (Storage account)"** from results

   *Alternative Path:*
   - Click **"Resource groups"** in left sidebar
   - Click **"rg-platform-dev"**
   - Click **"stdldevshared77b5h3"**

### Step 3: Open Test Container

1. In the left menu, scroll down to **"Data storage"** section
2. Click **"Containers"**
3. You'll see a list of containers
4. Click on **"test"** container

### Step 4: Upload ZIP File

1. Click **"Upload"** button at the top of the page
2. A panel will slide in from the right
3. Click **"Browse for files"** (or drag and drop)
4. Navigate to your ZIP file and select it
5. **Verify the settings:**
   - **Block blob** (default)
   - **Block size:** 4 MiB (default)
   - **Access tier:** Hot (default)
6. Click **"Upload"** button at bottom
7. Wait for green checkmark: **"Upload complete"**
8. Click **"X"** to close the upload panel

### Step 5: Upload Hash File

1. Click **"Upload"** button again
2. Click **"Browse for files"**
3. Select your hash file (e.g., `mydata_2025-10-28.hash`)
4. Click **"Upload"**
5. Wait for completion

### Step 6: Verify Both Files Are Present

1. Look at the file list in the container
2. You should see both files:
   - `mydata_2025-10-28.zip` (with size)
   - `mydata_2025-10-28.hash` (small file ~1 KB)
3. Note the exact file names - you'll need them!

**Troubleshooting:**
- **Don't see files?** Click **"Refresh"** button at top
- **Wrong name?** Click the file → Click **"..."** → **"Rename"**

---

## Part 3: Manually Trigger Validation

### Step 1: Navigate to Function App

1. Click on **"Home"** at the top of the portal
2. In the search bar, type: **`func-hash-validation-dev`**
3. Click on **"func-hash-validation-dev (Function App)"** from results

   *Alternative Path:*
   - Go to **Resource groups** → **"rg-platform-dev"**
   - Click **"func-hash-validation-dev"**

### Step 2: Open the Validation Function

1. In the left menu, scroll to **"Functions"** section
2. Click **"Functions"**
3. You'll see a list of functions
4. Click on **"validatehash"**

### Step 3: Open Code + Test Interface

1. In the left menu, click **"Code + Test"**
2. You'll see the function code in the editor
3. At the top, click **"Test/Run"** button
4. A panel will slide in from the right

### Step 4: Configure the Test

**Input Tab:**

1. **HTTP method:** Should already be **"POST"** (if not, select it)
2. **Key:** Should show **"default (function key)"** ✅
3. Leave **Headers** as is

### Step 5: Prepare Request Body

1. Click on the **"Body"** text area
2. **Delete any existing content**
3. Copy this template:

```json
[
  {
    "topic": "/subscriptions/e97fa8c6-457d-495f-aa82-0d87e72f5842/resourceGroups/rg-platform-dev/providers/Microsoft.Storage/storageAccounts/stdldevshared77b5h3",
    "subject": "/blobServices/default/containers/test/blobs/YOUR_FILE_NAME.zip",
    "eventType": "Microsoft.Storage.BlobCreated",
    "eventTime": "2025-10-28T14:30:00.0000000Z",
    "id": "manual-test-001",
    "data": {
      "api": "PutBlob",
      "contentType": "application/x-zip-compressed",
      "contentLength": 824,
      "blobType": "BlockBlob",
      "url": "https://stdldevshared77b5h3.blob.core.windows.net/test/YOUR_FILE_NAME.zip"
    },
    "dataVersion": "",
    "metadataVersion": "1"
  }
]
```

4. **IMPORTANT:** Replace **`YOUR_FILE_NAME.zip`** with your actual file name in TWO places:
   - Line 4: `"subject": "...blobs/mydata_2025-10-28.zip"`
   - Line 12: `"url": "...test/mydata_2025-10-28.zip"`

**Example for testing valid data:**
```json
"subject": "/blobServices/default/containers/test/blobs/valid_data_2025-10-28.zip",
"url": "https://stdldevshared77b5h3.blob.core.windows.net/test/valid_data_2025-10-28.zip"
```

5. Paste the modified JSON into the Body field

### Step 6: Run the Validation

1. Double-check your file name is correct in the JSON
2. Click **"Run"** button at the bottom
3. Watch the execution:
   - Status will show **"Running..."**
   - This may take 10-30 seconds
   - Wait patiently

### Step 7: View the Results

The **"Output"** tab will show the response:

**Success (PASS) Response:**
```json
{
  "status": "PASS",
  "timestamp": "2025-10-28 15:12:29",
  "filesExtracted": 3,
  "zipFile": "valid_data_2025-10-28.zip",
  "hashFile": "valid_data_2025-10-28.hash",
  "exitCode": 0,
  "okCount": 3,
  "failCount": 0,
  "missingCount": 0,
  "extraCount": 0,
  "message": "All files validated successfully",
  "validationDetails": "OK       : departments.csv\r\nOK       : employees.csv\r\nOK       : payroll.csv\r\n\r\nSUMMARY: OK=3 FAIL=0 MISSING=0 EXTRA=0\r\n"
}
```

**Failure (FAIL) Response:**
```json
{
  "status": "FAIL",
  "timestamp": "2025-10-28 15:13:36",
  "filesExtracted": 3,
  "zipFile": "corrupted_data_2025-10-28.zip",
  "hashFile": "corrupted_data_2025-10-28.hash",
  "exitCode": 3,
  "okCount": 2,
  "failCount": 1,
  "missingCount": 0,
  "extraCount": 0,
  "message": "Validation failed: Hash mismatch or file discrepancies found",
  "validationDetails": "OK       : departments.csv\r\nFAIL     : employees.csv\r\nOK       : payroll.csv\r\n\r\nSUMMARY: OK=2 FAIL=1 MISSING=0 EXTRA=0\r\n"
}
```

---

## Part 4: View Detailed Logs

### Step 1: Open Log Stream

1. While still in the Function App, click **"Log stream"** in the left menu
2. Wait for **"Connected!"** message
3. Logs will appear below

### Step 2: Run Validation Again

1. Go back to **"Code + Test"**
2. Click **"Test/Run"**
3. Click **"Run"** again
4. Switch to **"Log stream"** tab
5. Watch real-time logs appear

### Step 3: Read the Logs

**What to Look For:**

**Successful Validation Logs:**
```
[2025-10-28T15:12:29] Executing 'Functions.validatehash' (Reason='This function was programmatically called via the host APIs.', Id=abc123)
[2025-10-28T15:12:29] Received request to validate: valid_data_2025-10-28.zip
[2025-10-28T15:12:29] Downloading ZIP file from: test/valid_data_2025-10-28.zip
[2025-10-28T15:12:29] ZIP file downloaded: 824 bytes
[2025-10-28T15:12:29] Downloading hash file: test/valid_data_2025-10-28.hash
[2025-10-28T15:12:30] Hash file downloaded
[2025-10-28T15:12:30] Extracting ZIP to: C:\home\temp\abc123\extracted
[2025-10-28T15:12:30] Extracted 3 files
[2025-10-28T15:12:30] Running validation script...
[2025-10-28T15:12:31] Validation script exit code: 0
[2025-10-28T15:12:31] Status: PASS
[2025-10-28T15:12:31] Executed 'Functions.validatehash' (Succeeded, Id=abc123, Duration=2345ms)
```

**Failed Validation Logs:**
```
[2025-10-28T15:13:36] Running validation script...
[2025-10-28T15:13:37] Validation script exit code: 3
[2025-10-28T15:13:37] Status: FAIL
[2025-10-28T15:13:37] Validation details: OK       : departments.csv
FAIL     : employees.csv
OK       : payroll.csv
```

---

## Part 5: Understanding the Results

### Result Fields Explained

| Field | Meaning | Good Value | Bad Value |
|-------|---------|------------|-----------|
| **status** | Overall result | `PASS` | `FAIL` |
| **exitCode** | Script exit code | `0` | `1`, `2`, or `3` |
| **okCount** | Files that passed | Number > 0 | `0` |
| **failCount** | Files that failed | `0` | Number > 0 |
| **missingCount** | Expected files not found | `0` | Number > 0 |
| **extraCount** | Unexpected extra files | `0` | Number > 0 |
| **filesExtracted** | Total files in ZIP | Matches expected | Different |

### Exit Code Reference

| Exit Code | Meaning | What Happened |
|-----------|---------|---------------|
| **0** | Success | ✅ All files validated successfully |
| **1** | Parameter Error | ❌ Script error or invalid parameters |
| **2** | File Not Found | ❌ ZIP or hash file not found in storage |
| **3** | Validation Failed | ❌ Hash mismatch, missing, or extra files |

### Validation Details Breakdown

The `validationDetails` field shows line-by-line results:

```
OK       : file1.csv          ← Hash matches ✅
OK       : file2.csv          ← Hash matches ✅
FAIL     : file3.csv          ← Hash MISMATCH ❌
MISSING  : file4.csv          ← Expected but not in ZIP ⚠️
EXTRA    : unexpected.csv     ← In ZIP but not in hash file ⚠️

SUMMARY: OK=2 FAIL=1 MISSING=1 EXTRA=1
```

### What Each Status Means

#### ✅ OK - File Validated Successfully
- File exists in ZIP
- Hash matches expected value
- **Action:** None needed

#### ❌ FAIL - Hash Mismatch
- File exists in ZIP
- Hash does NOT match expected value
- **Meaning:** File has been modified/corrupted
- **Action:** Investigate why file content changed

#### ⚠️ MISSING - Expected File Not Found
- Hash file expects this file
- File NOT in ZIP
- **Action:** Check if file was accidentally excluded

#### ⚠️ EXTRA - Unexpected File Found
- File in ZIP
- NOT in hash file
- **Action:** Check if this is a legitimate new file

---

## Part 6: Test Both Scenarios

### Test 1: Validate Good Data (Should PASS)

1. Upload `valid_data_2025-10-28.zip` and `valid_data_2025-10-28.hash`
2. In Test/Run, use this JSON:
```json
"subject": "/blobServices/default/containers/test/blobs/valid_data_2025-10-28.zip",
"url": "https://stdldevshared77b5h3.blob.core.windows.net/test/valid_data_2025-10-28.zip"
```
3. Click **Run**
4. **Expected Result:** `"status": "PASS"`

### Test 2: Validate Corrupted Data (Should FAIL)

1. Upload `corrupted_data_2025-10-28.zip` (already uploaded)
2. Use `corrupted_data_2025-10-28.hash` (already uploaded)
3. In Test/Run, use this JSON:
```json
"subject": "/blobServices/default/containers/test/blobs/corrupted_data_2025-10-28.zip",
"url": "https://stdldevshared77b5h3.blob.core.windows.net/test/corrupted_data_2025-10-28.zip"
```
4. Click **Run**
5. **Expected Result:** `"status": "FAIL"` with `"failCount": 1`

---

## Part 7: Verify File Contents (Optional)

### Download and Inspect Files

#### Step 1: Download ZIP from Azure

1. Go to Storage Account → Containers → test
2. Click on your ZIP file (e.g., `valid_data_2025-10-28.zip`)
3. Click **"Download"** button
4. Save to your computer

#### Step 2: Extract and View

1. Right-click the downloaded ZIP → **"Extract All"**
2. Open the extracted CSV files in Excel or text editor
3. Review the data

#### Step 3: Download Hash File

1. In the container, click on your hash file (e.g., `valid_data_2025-10-28.hash`)
2. Click **"Download"**
3. Open in Notepad

**Hash File Format:**
```
1ba3261125a64546db910bf328d67dc492bf85b1d5182b31de3871f1e5b8a6bafb28f0d2b24b663d141adf99f44e868561ec97d88ae3f655312e4e7af2c2d23e|departments.csv
c0eb9608e7f02469b5663bb4295b00c94b23b21801baacee38c20fd2ab0ecade484126c5f243b6e0ff982c1c465eb1d2ba89cc52d1f182bc70150a81150b8f71|employees.csv
e6247570a58c8f4e5f7ebe60d198653b9d005bc7436232caf44c6e93294e1de167c6e127610ba82c66adf08891588049f3c5c7d8b05119924bb93639e68970c2|payroll.csv
```

Format: `hash|filename`

#### Step 4: Manually Calculate Hash (Verify)

Open PowerShell and calculate hash of your extracted file:

```powershell
cd "C:\path\to\extracted\files"
Get-FileHash -Path employees.csv -Algorithm SHA512
```

Compare the output hash with the hash in your `.hash` file.

---

## Troubleshooting

### Problem 1: "Blob not found" Error

**Error in Output:**
```json
{
  "status": "error",
  "message": "Failed to download blob: The specified blob does not exist"
}
```

**Solution:**
1. Go to Storage Account → Containers → test
2. Verify the file exists
3. Check the file name in your JSON **exactly matches** (case-sensitive!)
4. Ensure you're using the correct container name: `test`

### Problem 2: "Hash file not found" Error

**Error:**
```json
{
  "status": "error",
  "message": "Failed to download hash file"
}
```

**Solution:**
1. Verify hash file exists with correct name
2. Hash file name must match ZIP file name (except extension):
   - ✅ `data.zip` and `data.hash`
   - ❌ `data.zip` and `hashes.hash`

### Problem 3: All Files Show FAIL (But Should Pass)

**Possible Causes:**

**A. BOM in Hash File**
- Hash file has Byte Order Mark (BOM)
- **Fix:** Regenerate hash file using the PowerShell script above

**B. Wrong Line Endings**
- Hash file has incorrect line endings
- **Fix:** Use the script with `UTF8Encoding $false`

**C. Extra Spaces**
- Hash file has spaces around the `|` separator
- **Fix:** Should be `hash|filename` not `hash | filename`

**Verification:**
```powershell
# Check for BOM
$bytes = [System.IO.File]::ReadAllBytes("mydata.hash")
$bytes[0..2]  # Should NOT be: 239, 187, 191 (BOM)
```

### Problem 4: Function Times Out

**Error:**
```
502 - Web server received an invalid response
```

**Possible Causes:**
- Function app is cold-starting (first run after idle)
- Large ZIP file

**Solution:**
1. Wait 30-60 seconds
2. Try again
3. Check Log Stream for progress

### Problem 5: Permission Denied

**Error:**
```
AuthorizationFailed: You do not have authorization to perform action
```

**Solution:**
1. Go to Storage Account → **"Access Control (IAM)"**
2. Click **"Check access"**
3. Verify you have **Storage Blob Data Contributor** role
4. If not, request access from your Azure administrator

### Problem 6: Can't See Logs

**Solution:**
1. Go to Function App → **"Application Insights"**
2. Verify it's connected (shows green checkmark)
3. Go to **"Application Insights"** → **"Logs"**
4. Run this query:
```kusto
traces
| where message contains "validatehash"
| order by timestamp desc
| take 20
```

---

## Best Practices

### File Naming

Always use descriptive, dated names:
- ✅ `employee_data_2025-10-28.zip`
- ✅ `payroll_october_2025.zip`
- ❌ `data.zip`
- ❌ `file1.zip`

### Testing Workflow

1. **Test locally first** (extract ZIP, verify CSVs look correct)
2. **Generate hash from source files** (before creating ZIP)
3. **Upload to Azure test container**
4. **Run manual validation** (using Code + Test)
5. **Verify results** (check logs)
6. **Document results** (screenshot or save JSON output)

### Security

- **Never share Function URLs** - they contain secret keys
- **Use test container for testing** - don't test in production containers
- **Review validation results** before processing data
- **Keep hash files secure** - they're the "truth" for validation

---

## Quick Reference

### Navigation Paths

**Upload Files:**
```
Portal → Search "stdldevshared77b5h3" → Containers → test → Upload
```

**Run Validation:**
```
Portal → Search "func-hash-validation-dev" → Functions → validatehash → Code + Test → Test/Run
```

**View Logs:**
```
Portal → Function App → Log stream
```

**View in Application Insights:**
```
Portal → Search "appi-platform-dev" → Logs
```

### Test JSON Template

```json
[
  {
    "topic": "/subscriptions/e97fa8c6-457d-495f-aa82-0d87e72f5842/resourceGroups/rg-platform-dev/providers/Microsoft.Storage/storageAccounts/stdldevshared77b5h3",
    "subject": "/blobServices/default/containers/test/blobs/YOUR_FILE.zip",
    "eventType": "Microsoft.Storage.BlobCreated",
    "eventTime": "2025-10-28T14:30:00.0000000Z",
    "id": "manual-test",
    "data": {
      "api": "PutBlob",
      "contentType": "application/x-zip-compressed",
      "blobType": "BlockBlob",
      "url": "https://stdldevshared77b5h3.blob.core.windows.net/test/YOUR_FILE.zip"
    },
    "dataVersion": "",
    "metadataVersion": "1"
  }
]
```

Replace `YOUR_FILE.zip` with your actual file name.

---

## Next Steps

After successful manual validation:

1. ✅ **Document your process** - Take screenshots for your team
2. ✅ **Create validation checklist** - For regular use
3. ✅ **Set up alerts** - In Application Insights for failures
4. ✅ **Consider automation** - Set up Event Grid (see AZURE_PORTAL_GUIDE.md)
5. ✅ **Train your team** - Share this guide with colleagues

---

## Support

Need help?
- **Check logs first** - Most issues show up in Log Stream
- **Review error messages** - They usually point to the problem
- **Verify file names** - 90% of issues are naming mismatches
- **Check Application Insights** - For historical validation data

**Related Guides:**
- **AZURE_PORTAL_GUIDE.md** - Complete Portal reference
- **QUICK_START_GUIDE.md** - CLI-based validation
- **IMPLEMENTATION_GUIDE.md** - Technical architecture

---

**Document Version:** 1.0
**Last Updated:** 2025-10-28
**Difficulty Level:** Beginner-Friendly
**Estimated Time:** 10 minutes for first validation
