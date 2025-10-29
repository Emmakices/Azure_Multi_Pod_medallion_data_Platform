# Email Notification Setup for Hash Validation

## Overview

Automatically send email notifications when data validation completes, so workers know whether to process files without checking logs.

---

## Option A: Azure Logic App (No Code Required)

### Architecture
```
Validation Function → HTTP Request → Logic App → Email
```

### Step 1: Create Logic App

**Azure Portal → Create Resource → Logic App**

- **Name:** `logic-validation-notifications`
- **Region:** Same as your function app
- **Plan Type:** Consumption

### Step 2: Create Logic App Workflow

**Logic App Designer:**

#### Trigger: HTTP Request Received

```json
{
    "type": "object",
    "properties": {
        "status": {"type": "string"},
        "zipFile": {"type": "string"},
        "timestamp": {"type": "string"},
        "exitCode": {"type": "integer"},
        "okCount": {"type": "integer"},
        "failCount": {"type": "integer"},
        "validationDetails": {"type": "string"},
        "message": {"type": "string"}
    }
}
```

#### Action 1: Condition

**Condition:** `@equals(triggerBody()?['status'], 'PASS')`

##### If TRUE (PASS):

**Send Email (Office 365 or Outlook.com):**
- **To:** `data-processing-team@company.com`
- **Subject:** `✅ Data Ready to Process: @{triggerBody()?['zipFile']}`
- **Body:**
```html
<h2 style="color: green;">✅ Validation PASSED</h2>

<p><strong>File:</strong> @{triggerBody()?['zipFile']}</p>
<p><strong>Timestamp:</strong> @{triggerBody()?['timestamp']}</p>
<p><strong>Files Validated:</strong> @{triggerBody()?['okCount']}</p>

<h3>Status: SAFE TO PROCESS</h3>

<p><strong>Next Steps:</strong></p>
<ol>
  <li>Download ZIP from blob storage to F: drive</li>
  <li>Unzip the files</li>
  <li>Copy CSV files to correct folders</li>
  <li>Upload to blob storage in correct locations</li>
</ol>

<hr>
<pre>@{triggerBody()?['validationDetails']}</pre>
```

##### If FALSE (FAIL):

**Send Email (Office 365 or Outlook.com):**
- **To:** `data-processing-team@company.com` + `supervisor@company.com`
- **Subject:** `❌ DO NOT PROCESS: @{triggerBody()?['zipFile']} - VALIDATION FAILED`
- **Importance:** High
- **Body:**
```html
<h2 style="color: red;">❌ Validation FAILED</h2>

<p><strong>File:</strong> @{triggerBody()?['zipFile']}</p>
<p><strong>Timestamp:</strong> @{triggerBody()?['timestamp']}</p>
<p><strong>Files OK:</strong> @{triggerBody()?['okCount']}</p>
<p><strong>Files FAILED:</strong> @{triggerBody()?['failCount']}</p>

<h3 style="color: red;">❌ DO NOT DOWNLOAD OR PROCESS THIS FILE</h3>

<p><strong>Action Required:</strong></p>
<ol>
  <li>Contact data provider (government)</li>
  <li>Report which files failed (see details below)</li>
  <li>Request corrected data</li>
  <li>DO NOT process until new data is received and validated</li>
</ol>

<h4>Validation Details:</h4>
<pre>@{triggerBody()?['validationDetails']}</pre>

<p><strong>Error Message:</strong> @{triggerBody()?['message']}</p>
```

### Step 3: Get Logic App URL

After saving the workflow:
1. Click on the HTTP trigger
2. Copy the **HTTP POST URL**
3. It looks like: `https://prod-xx.region.logic.azure.com:443/workflows/.../triggers/manual/paths/invoke?api-version=...&sp=...&sv=...&sig=...`

### Step 4: Modify Azure Function to Call Logic App

**Edit:** `azure_function/ValidateHash/run.ps1`

Add at the end (before final response):

```powershell
# Send notification via Logic App
$logicAppUrl = $env:LOGIC_APP_NOTIFICATION_URL

if ($logicAppUrl) {
    try {
        $notificationBody = @{
            status = $status
            zipFile = $blobName
            hashFile = $hashFileName
            timestamp = $timestamp
            exitCode = $exitCode
            okCount = $okCount
            failCount = $failCount
            missingCount = $missingCount
            extraCount = $extraCount
            validationDetails = $validationDetails
            message = $message
        } | ConvertTo-Json

        Invoke-RestMethod -Uri $logicAppUrl `
                          -Method Post `
                          -Body $notificationBody `
                          -ContentType "application/json" `
                          -ErrorAction SilentlyContinue

        Write-Host "Notification sent to Logic App"
    } catch {
        Write-Host "Failed to send notification: $_"
        # Don't fail the function if notification fails
    }
}
```

### Step 5: Configure Function App Setting

**Azure Portal → func-hash-validation-dev → Configuration → Application Settings**

Add new setting:
- **Name:** `LOGIC_APP_NOTIFICATION_URL`
- **Value:** (Paste the Logic App HTTP POST URL from Step 3)

**Save** and **Restart** function app.

---

## Option B: SendGrid Email (Simpler)

### Prerequisites
- SendGrid account (free tier: 100 emails/day)
- API key

### Step 1: Get SendGrid API Key

1. Sign up: https://sendgrid.com/
2. Create API Key: Settings → API Keys → Create API Key
3. Copy the API key

### Step 2: Modify Azure Function

**Edit:** `azure_function/ValidateHash/run.ps1`

Add at the end:

```powershell
# Send email notification via SendGrid
$sendGridKey = $env:SENDGRID_API_KEY
$fromEmail = $env:NOTIFICATION_FROM_EMAIL
$toEmails = $env:NOTIFICATION_TO_EMAILS  # Comma-separated

if ($sendGridKey -and $fromEmail -and $toEmails) {
    try {
        $toEmailList = $toEmails -split ','

        if ($status -eq "PASS") {
            $subject = "✅ Data Ready to Process: $blobName"
            $htmlContent = @"
<h2 style="color: green;">✅ Validation PASSED</h2>
<p><strong>File:</strong> $blobName</p>
<p><strong>Timestamp:</strong> $timestamp</p>
<p><strong>Files Validated:</strong> $okCount</p>
<h3>Status: SAFE TO PROCESS</h3>
<p><strong>Next Steps:</strong></p>
<ol>
  <li>Download ZIP from blob storage to F: drive</li>
  <li>Unzip the files</li>
  <li>Copy CSV files to correct folders</li>
</ol>
<hr>
<pre>$validationDetails</pre>
"@
        } else {
            $subject = "❌ DO NOT PROCESS: $blobName - VALIDATION FAILED"
            $htmlContent = @"
<h2 style="color: red;">❌ Validation FAILED</h2>
<p><strong>File:</strong> $blobName</p>
<p><strong>Timestamp:</strong> $timestamp</p>
<p><strong>Files FAILED:</strong> $failCount</p>
<h3 style="color: red;">❌ DO NOT DOWNLOAD OR PROCESS THIS FILE</h3>
<p><strong>Action Required:</strong></p>
<ol>
  <li>Contact data provider</li>
  <li>Report which files failed</li>
  <li>Request corrected data</li>
</ol>
<h4>Validation Details:</h4>
<pre>$validationDetails</pre>
"@
        }

        $emailBody = @{
            personalizations = @(
                @{
                    to = @($toEmailList | ForEach-Object { @{ email = $_.Trim() } })
                    subject = $subject
                }
            )
            from = @{
                email = $fromEmail
                name = "Data Validation System"
            }
            content = @(
                @{
                    type = "text/html"
                    value = $htmlContent
                }
            )
        } | ConvertTo-Json -Depth 10

        Invoke-RestMethod -Uri "https://api.sendgrid.com/v3/mail/send" `
                          -Method Post `
                          -Headers @{
                              "Authorization" = "Bearer $sendGridKey"
                              "Content-Type" = "application/json"
                          } `
                          -Body $emailBody `
                          -ErrorAction SilentlyContinue

        Write-Host "Email notification sent via SendGrid"
    } catch {
        Write-Host "Failed to send email: $_"
    }
}
```

### Step 3: Configure Function App Settings

**Azure Portal → func-hash-validation-dev → Configuration → Application Settings**

Add:
- **SENDGRID_API_KEY:** (Your SendGrid API key)
- **NOTIFICATION_FROM_EMAIL:** `noreply@yourcompany.com`
- **NOTIFICATION_TO_EMAILS:** `worker1@company.com,worker2@company.com,supervisor@company.com`

**Save** and **Restart**.

---

## Option C: Microsoft Teams Notification

### Step 1: Create Teams Incoming Webhook

1. Open Microsoft Teams
2. Go to channel where you want notifications
3. Click ⋯ → Connectors → Incoming Webhook
4. Name: "Data Validation Alerts"
5. Copy webhook URL

### Step 2: Modify Azure Function

**Edit:** `azure_function/ValidateHash/run.ps1`

Add:

```powershell
# Send Teams notification
$teamsWebhookUrl = $env:TEAMS_WEBHOOK_URL

if ($teamsWebhookUrl) {
    try {
        if ($status -eq "PASS") {
            $color = "00FF00"  # Green
            $title = "✅ Data Ready to Process"
        } else {
            $color = "FF0000"  # Red
            $title = "❌ DO NOT PROCESS - Validation Failed"
        }

        $teamsMessage = @{
            "@type" = "MessageCard"
            "@context" = "https://schema.org/extensions"
            themeColor = $color
            title = $title
            summary = "$blobName validation: $status"
            sections = @(
                @{
                    activityTitle = "File: $blobName"
                    activitySubtitle = "Timestamp: $timestamp"
                    facts = @(
                        @{ name = "Status"; value = $status }
                        @{ name = "Exit Code"; value = $exitCode }
                        @{ name = "Files OK"; value = $okCount }
                        @{ name = "Files Failed"; value = $failCount }
                    )
                    text = "``````$validationDetails``````"
                }
            )
        } | ConvertTo-Json -Depth 10

        Invoke-RestMethod -Uri $teamsWebhookUrl `
                          -Method Post `
                          -Body $teamsMessage `
                          -ContentType "application/json" `
                          -ErrorAction SilentlyContinue

        Write-Host "Teams notification sent"
    } catch {
        Write-Host "Failed to send Teams notification: $_"
    }
}
```

### Step 3: Configure Function App Setting

Add:
- **TEAMS_WEBHOOK_URL:** (Paste Teams webhook URL)

---

## Option D: Simple Web Dashboard

Create a simple webpage that shows validation status.

### Step 1: Create Status Storage

Modify function to write status to blob:

```powershell
# Write status to blob for dashboard
$statusBlob = @{
    timestamp = $timestamp
    fileName = $blobName
    status = $status
    exitCode = $exitCode
    okCount = $okCount
    failCount = $failCount
    validationDetails = $validationDetails
} | ConvertTo-Json

$statusFileName = "validation-status/$($blobName).json"
$statusUrl = "https://$storageAccount.blob.core.windows.net/monitoring/$statusFileName"

# Upload status (using REST API)
$statusBytes = [System.Text.Encoding]::UTF8.GetBytes($statusBlob)
Invoke-RestMethod -Uri $statusUrl `
                  -Method Put `
                  -Headers $headers `
                  -Body $statusBytes
```

### Step 2: Create HTML Dashboard

**File:** `dashboard.html` (upload to blob storage as static website)

```html
<!DOCTYPE html>
<html>
<head>
    <title>Data Validation Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .status-box {
            padding: 20px;
            margin: 10px 0;
            border-radius: 5px;
            border: 2px solid #ccc;
        }
        .pass {
            background-color: #d4edda;
            border-color: #28a745;
        }
        .fail {
            background-color: #f8d7da;
            border-color: #dc3545;
        }
        h2 { margin: 0 0 10px 0; }
        .details {
            background: white;
            padding: 10px;
            margin-top: 10px;
            border-radius: 3px;
            font-family: monospace;
            white-space: pre-wrap;
        }
    </style>
</head>
<body>
    <h1>Data Validation Status Dashboard</h1>
    <div id="statuses"></div>

    <script>
        // Fetch recent validation statuses
        async function loadStatuses() {
            // List blobs in validation-status folder
            const response = await fetch('/api/list-validation-statuses');
            const statuses = await response.json();

            const container = document.getElementById('statuses');
            container.innerHTML = '';

            statuses.forEach(status => {
                const box = document.createElement('div');
                box.className = `status-box ${status.status === 'PASS' ? 'pass' : 'fail'}`;

                box.innerHTML = `
                    <h2>${status.status === 'PASS' ? '✅' : '❌'} ${status.fileName}</h2>
                    <p><strong>Timestamp:</strong> ${status.timestamp}</p>
                    <p><strong>Status:</strong> ${status.status}</p>
                    <p><strong>Files OK:</strong> ${status.okCount} | <strong>Failed:</strong> ${status.failCount}</p>
                    <div class="details">${status.validationDetails}</div>
                `;

                container.appendChild(box);
            });
        }

        // Refresh every 30 seconds
        loadStatuses();
        setInterval(loadStatuses, 30000);
    </script>
</body>
</html>
```

---

## Recommended Setup

### For Your Use Case:

**Best Option: Email Notifications (Option A or B)**

Why:
- Workers get notified automatically
- No need to check anything manually
- Clear instructions in email (process or don't process)
- Works on mobile devices
- Audit trail (email history)

**Quick Win: Teams Notification (Option C)**

Why:
- If your team already uses Teams
- Instant notifications to channel
- Everyone sees the same status
- Easy to set up (2 minutes)

---

## Testing Notifications

### Test with Good Data

```powershell
curl -X POST "https://func-hash-validation-dev.azurewebsites.net/api/validatehash?code=..." -d "@test_data/test_event_pass.json"
```

**Expected:** Email/Teams message with green ✅ "Safe to process"

### Test with Bad Data

```powershell
curl -X POST "https://func-hash-validation-dev.azurewebsites.net/api/validatehash?code=..." -d "@test_data/test_event_fail.json"
```

**Expected:** Email/Teams message with red ❌ "DO NOT PROCESS"

---

## Summary

| Option | Setup Time | Best For |
|--------|-----------|----------|
| PowerShell Script | 5 min | Manual checking |
| Logic App Email | 15 min | Automated notifications, audit trail |
| SendGrid Email | 10 min | Simple setup, no Azure Logic App needed |
| Teams Webhook | 2 min | Teams users, instant collaboration |
| Web Dashboard | 30 min | Real-time status monitoring |

**Recommendation:** Set up Teams (2 min) + Email (10 min) for redundancy.

---

**Document Version:** 1.0
**Last Updated:** 2025-10-28
