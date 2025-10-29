# Hash Validation Pipeline - Azure Portal Guide

## Overview

This guide shows you how to run the hash validation pipeline entirely through the Azure Portal (Web UI). No command line required!

---

## Table of Contents

1. [Access Azure Portal](#access-azure-portal)
2. [Upload Files via Storage Browser](#upload-files-via-storage-browser)
3. [Test Function via Portal](#test-function-via-portal)
4. [View Results and Logs](#view-results-and-logs)
5. [Monitor with Application Insights](#monitor-with-application-insights)
6. [Troubleshooting in Portal](#troubleshooting-in-portal)

---

## Access Azure Portal

### Step 1: Login to Azure Portal

1. Open your web browser
2. Navigate to: **https://portal.azure.com**
3. Sign in with your Azure credentials
4. You should see the Azure Portal dashboard

### Step 2: Navigate to Resource Group

1. In the left sidebar, click **"Resource groups"**
2. Find and click on **"rg-platform-dev"**
3. You'll see all resources in this group:
   - `stdldevshared77b5h3` (Storage Account)
   - `func-hash-validation-dev` (Function App)
   - `appi-platform-dev` (Application Insights)

---

## Upload Files via Storage Browser

### Method A: Using Storage Browser (Recommended)

#### Step 1: Open Storage Account

1. From the Resource Group, click **"stdldevshared77b5h3"** (Storage Account)
2. In the left menu, scroll down to **"Data storage"** section
3. Click **"Containers"**
4. Click on the **"test"** container

#### Step 2: Upload ZIP File

1. Click the **"Upload"** button at the top
2. Click **"Browse for files"**
3. Select your ZIP file (e.g., `valid_data_2025-10-28.zip`)
4. Click **"Upload"** button
5. Wait for the upload to complete (green checkmark appears)

#### Step 3: Upload Hash File

1. Click **"Upload"** button again
2. Click **"Browse for files"**
3. Select your hash file (e.g., `valid_data_2025-10-28.hash`)
4. **Important:** Make sure the hash file name matches the ZIP file name (except for extension)
   - ZIP: `valid_data_2025-10-28.zip`
   - Hash: `valid_data_2025-10-28.hash` ✅
5. Click **"Upload"**

#### Step 4: Verify Files are Uploaded

1. You should see both files listed in the container:
   - `valid_data_2025-10-28.zip`
   - `valid_data_2025-10-28.hash`
2. Click on each file to view properties (size, upload date, etc.)

### Method B: Using Azure Storage Explorer (Desktop App)

If you prefer a desktop application:

1. Download **Azure Storage Explorer** from: https://azure.microsoft.com/features/storage-explorer/
2. Install and launch the application
3. Sign in with your Azure account
4. Navigate to: **Storage Accounts → stdldevshared77b5h3 → Blob Containers → test**
5. Drag and drop your files into the container

---

## Test Function via Portal

### Step 1: Open Function App

1. Go back to Resource Group **"rg-platform-dev"**
2. Click on **"func-hash-validation-dev"** (Function App)
3. In the left menu, scroll down to **"Functions"** section
4. Click **"Functions"**
5. Click on **"validatehash"**

### Step 2: Get Function URL

1. Click **"Get Function Url"** button at the top
2. Select **"default (function key)"** from dropdown
3. Click **"Copy"** icon to copy the URL
4. The URL will look like:
   ```
   https://func-hash-validation-dev.azurewebsites.net/api/validatehash?code=YOUR_FUNCTION_KEY_HERE
   ```

### Step 3: Test Using Code + Test Feature

1. In the Function page, click **"Code + Test"** in the left menu
2. Click the **"Test/Run"** button at the top
3. Configure the test:
   - **HTTP method:** POST
   - **Key:** (should be auto-filled)

#### Step 4: Add Request Body

In the **"Body"** section, paste this JSON (for PASS test):

```json
[
  {
    "topic": "/subscriptions/e97fa8c6-457d-495f-aa82-0d87e72f5842/resourceGroups/rg-platform-dev/providers/Microsoft.Storage/storageAccounts/stdldevshared77b5h3",
    "subject": "/blobServices/default/containers/test/blobs/valid_data_2025-10-28.zip",
    "eventType": "Microsoft.Storage.BlobCreated",
    "eventTime": "2025-10-28T14:30:00.0000000Z",
    "id": "portal-test-12345",
    "data": {
      "api": "PutBlob",
      "contentType": "application/x-zip-compressed",
      "contentLength": 824,
      "blobType": "BlockBlob",
      "url": "https://stdldevshared77b5h3.blob.core.windows.net/test/valid_data_2025-10-28.zip"
    },
    "dataVersion": "",
    "metadataVersion": "1"
  }
]
```

**Important:** Update the `subject` and `url` fields if you're testing a different file!

#### Step 5: Run the Test

1. Click **"Run"** button
2. Wait for execution (may take 5-30 seconds)
3. View results in the **"Output"** tab

**Expected Output (PASS):**
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

### Step 6: Test FAIL Scenario

1. Upload the corrupted data files first (see Upload section above)
2. In the test body, change the file name:
   ```json
   "subject": "/blobServices/default/containers/test/blobs/corrupted_data_2025-10-28.zip",
   "url": "https://stdldevshared77b5h3.blob.core.windows.net/test/corrupted_data_2025-10-28.zip"
   ```
3. Click **"Run"**

**Expected Output (FAIL):**
```json
{
  "status": "FAIL",
  "exitCode": 3,
  "okCount": 2,
  "failCount": 1,
  "message": "Validation failed: Hash mismatch or file discrepancies found"
}
```

---

## View Results and Logs

### Method 1: View in Function Logs

#### Step 1: Open Log Stream

1. In your Function App (**func-hash-validation-dev**)
2. Click **"Log stream"** in the left menu
3. Wait for connection (shows "Connected!")
4. Logs will appear in real-time as you run tests

**What to Look For:**

**Successful Validation:**
```
[2025-10-28T15:12:29] Executing 'Functions.validatehash'
[2025-10-28T15:12:29] Downloading ZIP file: valid_data_2025-10-28.zip
[2025-10-28T15:12:30] Extracting ZIP to: C:\home\temp\extracted
[2025-10-28T15:12:30] Extracted 3 files
[2025-10-28T15:12:30] Running validation script...
[2025-10-28T15:12:31] Validation script exit code: 0
[2025-10-28T15:12:31] Status: PASS
[2025-10-28T15:12:31] Executed 'Functions.validatehash' (Succeeded)
```

**Failed Validation:**
```
[2025-10-28T15:13:36] Validation script exit code: 3
[2025-10-28T15:13:36] Status: FAIL
[2025-10-28T15:13:36] Validation details: FAIL: employees.csv
```

### Method 2: View Function Invocations

1. In Function App, go to **"Functions"** → **"validatehash"**
2. Click **"Monitor"** in the left menu
3. Click **"Invocations"** tab
4. You'll see a list of all function executions:
   - **Success** (green) - Validation completed successfully
   - **Failed** (red) - Function execution failed
5. Click on any row to see detailed logs

---

## Monitor with Application Insights

### Step 1: Open Application Insights

1. From Resource Group, click **"appi-platform-dev"**
2. Or from Function App, click **"Application Insights"** in left menu

### Step 2: View Live Metrics

1. Click **"Live metrics"** in the left menu
2. See real-time:
   - Request rate
   - Response time
   - Failure rate
   - Server metrics

### Step 3: Query Logs

1. Click **"Logs"** in the left menu
2. Close the welcome popup if it appears
3. Use this query to see validation results:

```kusto
traces
| where message contains "Status:"
| project timestamp, message
| order by timestamp desc
| take 20
```

4. Click **"Run"** button
5. View results in table format

### Step 4: View Failed Validations Only

```kusto
traces
| where message contains "Status: FAIL"
| project timestamp, message
| order by timestamp desc
```

### Step 5: View Validation Details

```kusto
traces
| where message contains "Validation details:"
| project timestamp, message
| order by timestamp desc
| take 10
```

### Step 6: Create Custom Dashboard

1. After running a query, click **"Pin to dashboard"**
2. Choose **"Create new"** or select existing dashboard
3. Name your dashboard (e.g., "Hash Validation Monitoring")
4. Click **"Pin"**
5. Access dashboards from Azure Portal home

---

## Testing Your Own Files

### Complete Workflow in Azure Portal

#### Step 1: Prepare Your Files Locally

1. Create a ZIP file with your CSV files
2. Generate hash file:
   - Open PowerShell on your computer
   - Navigate to your data folder
   - Run:
   ```powershell
   $files = Get-ChildItem *.csv | Sort-Object Name
   $hashes = @()
   foreach ($file in $files) {
       $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA512).Hash.ToLower()
       $hashes += "$hash|$($file.Name)"
   }
   $utf8NoBom = New-Object System.Text.UTF8Encoding $false
   [System.IO.File]::WriteAllLines("mydata.hash", $hashes, $utf8NoBom)
   ```

#### Step 2: Upload to Azure

1. Go to Azure Portal → Storage Account → Container "test"
2. Upload your ZIP file (e.g., `mydata_2025-10-28.zip`)
3. Upload your hash file (e.g., `mydata_2025-10-28.hash`)

#### Step 3: Create Test JSON

Copy this template and save as `mytest.json` on your computer:

```json
[
  {
    "topic": "/subscriptions/e97fa8c6-457d-495f-aa82-0d87e72f5842/resourceGroups/rg-platform-dev/providers/Microsoft.Storage/storageAccounts/stdldevshared77b5h3",
    "subject": "/blobServices/default/containers/test/blobs/YOUR_ZIP_NAME.zip",
    "eventType": "Microsoft.Storage.BlobCreated",
    "eventTime": "2025-10-28T14:30:00.0000000Z",
    "id": "my-test-12345",
    "data": {
      "api": "PutBlob",
      "contentType": "application/x-zip-compressed",
      "contentLength": 824,
      "blobType": "BlockBlob",
      "url": "https://stdldevshared77b5h3.blob.core.windows.net/test/YOUR_ZIP_NAME.zip"
    },
    "dataVersion": "",
    "metadataVersion": "1"
  }
]
```

Replace `YOUR_ZIP_NAME.zip` with your actual file name.

#### Step 4: Run Test in Portal

1. Go to Function App → validatehash → Code + Test
2. Click Test/Run
3. Paste your JSON in Body section
4. Click Run
5. Check results

---

## Troubleshooting in Portal

### Issue 1: Can't Find Files in Storage

**Check:**
1. Go to Storage Account → Containers → test
2. Verify both files are listed
3. Check file names match exactly (case-sensitive)

**Fix:**
- Re-upload files if missing
- Rename files if names don't match

### Issue 2: Function Test Returns Error

**Check Function Status:**
1. Go to Function App → Overview
2. Check **"Status"** field shows "Running"
3. If not running, click **"Start"** button

**Check Recent Errors:**
1. Go to Function App → Diagnose and solve problems
2. Click **"Function Execution and Errors"**
3. Review recent errors

### Issue 3: Test Takes Too Long

**Possible Causes:**
- Function is cold-starting (first run after idle)
- Large ZIP file

**Solution:**
- Wait 30-60 seconds for cold start
- Check file size in Storage Browser
- View Log Stream for progress

### Issue 4: Can't See Logs

**Enable Application Insights:**
1. Go to Function App → Configuration
2. Check **"APPINSIGHTS_INSTRUMENTATIONKEY"** is set
3. Go to Application Insights → Overview
4. Verify data is flowing (check graphs)

**Enable File System Logs:**
1. Go to Function App → App Service logs
2. Set **"Application logging (Filesystem)"** to **"Information"**
3. Click **"Save"**

### Issue 5: Upload Permission Denied

**Check Your Role:**
1. Go to Storage Account → Access Control (IAM)
2. Click **"Check access"**
3. Verify you have one of these roles:
   - Storage Blob Data Owner
   - Storage Blob Data Contributor

**Request Access:**
- Contact your Azure administrator
- Or use Azure CLI with `--auth-mode key` (see Quick Start Guide)

---

## Useful Portal Links

Quick navigation to key pages:

### Storage Account
- **Container:** `Portal Home → Resource Groups → rg-platform-dev → stdldevshared77b5h3 → Containers → test`
- **Upload Files:** `Container → Upload button`
- **View Files:** `Container → Click file name`

### Function App
- **Test Function:** `Function App → Functions → validatehash → Code + Test`
- **View Logs:** `Function App → Log stream`
- **Monitor:** `Function App → Functions → validatehash → Monitor`
- **Configuration:** `Function App → Configuration`

### Application Insights
- **Live Metrics:** `Application Insights → Live metrics`
- **Query Logs:** `Application Insights → Logs`
- **Failures:** `Application Insights → Failures`
- **Performance:** `Application Insights → Performance`

---

## Automated Testing (Optional)

### Set Up Event Grid Subscription

To automatically trigger validation when files are uploaded:

#### Step 1: Open Storage Account

1. Go to Storage Account (**stdldevshared77b5h3**)
2. Click **"Events"** in the left menu
3. Click **"+ Event Subscription"** at the top

#### Step 2: Configure Subscription

**Basic Settings:**
- **Name:** `hash-validation-trigger`
- **Event Schema:** Event Grid Schema
- **Topic Type:** Storage Accounts
- **System Topic Name:** `storage-events-topic`

**Event Types:**
- Check: ✅ **Blob Created**
- Uncheck all others

**Filter to Subject:**
- **Subject Begins With:** `/blobServices/default/containers/test/blobs/`
- **Subject Ends With:** `.zip`

#### Step 3: Configure Endpoint

**Endpoint Type:** Azure Function

Click **"Select an endpoint"**
- **Subscription:** (Your subscription)
- **Resource group:** rg-platform-dev
- **Function App:** func-hash-validation-dev
- **Function:** validatehash

Click **"Confirm Selection"**

#### Step 4: Create Subscription

1. Click **"Create"** button
2. Wait for deployment (1-2 minutes)
3. Verify in Events page (shows "Active")

#### Step 5: Test Automatic Trigger

1. Go to Storage Container
2. Upload a new ZIP file (e.g., `autotest_2025-10-28.zip`)
3. Upload corresponding hash file (e.g., `autotest_2025-10-28.hash`)
4. Wait 5-10 seconds
5. Check Function Monitor for automatic execution

---

## Best Practices

### File Naming Convention

Always use consistent naming:
- **Format:** `description_YYYY-MM-DD.zip` and `description_YYYY-MM-DD.hash`
- **Examples:**
  - ✅ `employee_data_2025-10-28.zip` / `employee_data_2025-10-28.hash`
  - ✅ `payroll_2025-10-28.zip` / `payroll_2025-10-28.hash`
  - ❌ `data.zip` / `hashes.hash` (too generic)

### Testing Workflow

1. **Test locally first** (if possible)
2. **Upload to Azure test container**
3. **Run manual test in Portal**
4. **Verify results in logs**
5. **Check Application Insights**
6. **Only then enable Event Grid automation**

### Security

- **Never share Function URLs** publicly (contains secret key)
- **Use SAS tokens** for temporary blob access
- **Review Access Control (IAM)** regularly
- **Enable logging** for audit trail

### Monitoring

Set up alerts in Application Insights:
1. Go to Application Insights → Alerts
2. Click **"+ Create"** → **"Alert rule"**
3. Configure:
   - **Signal:** Custom log search
   - **Query:** `traces | where message contains "Status: FAIL"`
   - **Alert logic:** When count is greater than 0
   - **Actions:** Email notification

---

## Quick Reference Card

### Upload Files
```
Portal → Storage Account → Containers → test → Upload
```

### Test Function
```
Portal → Function App → Functions → validatehash → Code + Test → Run
```

### View Logs
```
Portal → Function App → Log stream
```

### Check Status
```
Portal → Function App → Functions → validatehash → Monitor
```

### Query Logs
```
Portal → Application Insights → Logs
```

---

## Keyboard Shortcuts in Portal

- **Ctrl + /** - Open search bar
- **G + N** - Go to notifications
- **G + H** - Go to home
- **/** - Focus search

---

## Video Tutorial Outline

If creating a video tutorial, follow this flow:

1. **Introduction** (1 min)
   - What is hash validation
   - Why it's important

2. **Upload Files** (2 min)
   - Navigate to Storage Account
   - Upload ZIP and hash files

3. **Test Function** (3 min)
   - Open Function App
   - Use Code + Test feature
   - Run PASS scenario
   - Run FAIL scenario

4. **View Results** (2 min)
   - Check output in test panel
   - View logs in Log Stream

5. **Monitor** (2 min)
   - Open Application Insights
   - Run queries
   - Interpret results

6. **Troubleshooting** (2 min)
   - Common issues
   - How to fix

**Total Duration:** ~12 minutes

---

## Next Steps

After successfully running validation via Portal:

1. ✅ Review the **QUICK_START_GUIDE.md** for CLI-based testing
2. ✅ Read **IMPLEMENTATION_GUIDE.md** for technical details
3. ✅ Set up Event Grid for automation
4. ✅ Configure Application Insights alerts
5. ✅ Integrate with your data pipeline

---

## Support Resources

- **Azure Portal Help:** Click **"?"** icon in top right corner
- **Azure Documentation:** https://docs.microsoft.com/azure/
- **Function App Docs:** https://docs.microsoft.com/azure/azure-functions/
- **Storage Docs:** https://docs.microsoft.com/azure/storage/

**Document Version:** 1.0
**Last Updated:** 2025-10-28
**Related Docs:** QUICK_START_GUIDE.md, IMPLEMENTATION_GUIDE.md
