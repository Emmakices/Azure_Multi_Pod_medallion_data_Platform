# email notifications - complete implementation guide

**written by**: emmanuel ihetu
**date**: october 29, 2025
**what this covers**: how we got email alerts working after teams webhooks failed

---

## the journey (what actually happened)

started with teams notifications, but hit authentication roadblocks. switched to email via logic apps, and everything just worked. sometimes the simpler path is the better one.

### problems we ran into:
- teams power automate workflow: kept throwing 403 "insufficient authentication scopes" errors
- gmail connector in logic apps: same authentication nightmare
- solution: office 365 outlook in logic apps - worked immediately, zero auth issues

**takeaway**: when something's fighting you, try a different approach. we wasted 30 minutes on teams before pivoting to email.

---

## how it works now

```
validation finishes → function posts json to logic app → logic app formats email → outlook sends it → team gets notified
```

**the players**:
- azure function: does the file validation, creates the results
- azure logic app: takes results, turns them into a nice email
- office 365 outlook: built-in email service (no extra setup needed)
- recipients: currently just ihetuemmanuel@gmail.com

---

## step-by-step: what we built

### step 1: created the logic app shell

first, we needed infrastructure. used terraform because infrastructure-as-code is the way.

**created file**: `terraform/04-logic-app-email.tf`

```hcl
resource "azurerm_logic_app_workflow" "email_notifications" {
  name                = "logic-hash-validation-email-dev"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = {
    environment = var.environment
    project     = "hash-validation"
    purpose     = "email-notifications"
  }
}
```

**deployed it**:
```bash
cd terraform
terraform apply -auto-approve
```

this creates an empty logic app. think of it like buying a car - you have the vehicle, but you still need to put gas in and configure the radio.

---

### step 2: configured the logic app (the fun part)

opened azure portal and built the workflow visually. way easier than trying to code it all in terraform.

**how to get there**:
1. azure portal → resource groups → rg-platform-dev
2. click `logic-hash-validation-email-dev`
3. click "logic app designer" in sidebar
4. select "blank logic app" template

**added the http trigger**:

this is how the function will talk to the logic app. we're basically saying "hey logic app, listen for incoming data that looks like this":

1. search for "http" in the connector search
2. select "when a http request is received"
3. click "use sample payload to generate schema"
4. pasted this json (teaches logic app what to expect):

```json
{
  "status": "PASS",
  "timestamp": "2025-10-28 15:30:00",
  "zipFile": "valid_data_2025-10-28.zip",
  "hashFile": "valid_data_2025-10-28.hash",
  "filesExtracted": 3,
  "exitCode": 0,
  "okCount": 3,
  "failCount": 0,
  "missingCount": 0,
  "extraCount": 0,
  "message": "All files validated successfully",
  "validationDetails": "OK: file1.csv\nOK: file2.csv"
}
```

5. clicked "done"

**why this matters**: without the schema, logic app would just see raw json. with the schema, it can extract specific fields like "status" or "zipFile" and use them in the email.

---

**added the email action**:

this is where we actually send the email.

1. clicked "+ new step"
2. searched for "office 365 outlook"
3. selected "send an email (v2)"
4. signed in with: ikechukwuemmanuelihetu82@gmail.com (this is the "from" address)
5. filled in the email template:

**to**: `ihetuemmanuel@gmail.com`

**subject**: `hash validation alert - [status] - [zipFile]`
- use the lightning bolt ⚡ to insert dynamic fields from the json payload

**body**:
```
validation status: [status]
file name: [zipFile]
hash file: [hashFile]
timestamp: [timestamp]

results:
files extracted: [filesExtracted]
files ok: [okCount]
files failed: [failCount]
files missing: [missingCount]
extra files: [extraCount]

message:
[message]

validation details:
[validationDetails]
```

clicked "save"

**got the webhook url**:
- clicked on the http trigger box at the top
- copied the "http post url" that appeared
- saved it (you'll need this next)

the url looks like:
```
https://prod-09.canadacentral.logic.azure.com:443/workflows/1ace741e203d4924908b4bb974b49406/triggers/When_an_HTTP_request_is_received/paths/invoke?api-version=2016-10-01&sp=%2Ftriggers%2FWhen_an_HTTP_request_is_received%2Frun&sv=1.0&sig=YOUR_SIGNATURE_HERE
```

---

### step 3: told the function where to send notifications

now we need to give the azure function the logic app url so it knows where to send validation results.

**added environment variable**:

```bash
az functionapp config appsettings set \
  --name func-hash-validation-dev \
  --resource-group rg-platform-dev \
  --settings "EMAIL_LOGIC_APP_URL=https://prod-09.canadacentral.logic.azure.com:443/workflows/..."
```

(paste your actual logic app url from step 2)

**what this does**: stores the url securely as an environment variable. the function can access it without hardcoding the url in the code.

---

**updated the function code**:

modified `azure_function/ValidateHash/run.ps1` to call the logic app.

**key change** (around line 213):

```powershell
# get logic app url from environment
$emailLogicAppUrl = $env:EMAIL_LOGIC_APP_URL

if ($emailLogicAppUrl) {
    try {
        write-host "sending email notification via logic app..."

        # convert validation results to json
        $emailBody = $validationResult | ConvertTo-Json -Depth 10

        # send to logic app via http post
        $emailResponse = Invoke-RestMethod -Uri $emailLogicAppUrl `
                                           -Method Post `
                                           -Body $emailBody `
                                           -ContentType "application/json" `
                                           -ErrorAction Stop

        write-host "email notification sent successfully"

    } catch {
        write-host "failed to send email: $_"
        # don't crash if email fails - validation is more important
    }
}
```

**what's happening here**:
1. function finishes validating files
2. takes all the results (status, file names, counts, errors, etc.)
3. converts to json
4. posts to the logic app url
5. logic app receives it, formats the email, sends it

---

**deployed the updated function**:

```bash
# package everything into a zip
cd azure_function
powershell -Command "Compress-Archive -Path * -DestinationPath ../function-app.zip -Force"

# deploy to azure
cd ..
az functionapp deployment source config-zip \
  --resource-group rg-platform-dev \
  --name func-hash-validation-dev \
  --src function-app.zip

# restart to load new code
az functionapp restart \
  --name func-hash-validation-dev \
  --resource-group rg-platform-dev
```

---

### step 4: tested it

always test before calling it done. we tested both pass and fail scenarios.

**tested pass scenario**:
```bash
curl -X POST "https://func-hash-validation-dev.azurewebsites.net/api/validatehash?code=YOUR_FUNCTION_KEY_HERE" \
  -H "Content-Type: application/json" \
  -d "@test_data/test_event_pass.json"
```

**got this email**:
```
subject: hash validation alert - PASS - valid_data_2025-10-28.zip

validation status: PASS
file name: valid_data_2025-10-28.zip
hash file: valid_data_2025-10-28.hash
timestamp: 2025-10-29 04:10:41

results:
files extracted: 3
files ok: 3
files failed: 0
files missing: 0
extra files: 0

message:
all files validated successfully

validation details:
OK       : departments.csv
OK       : employees.csv
OK       : payroll.csv

SUMMARY: OK=3 FAIL=0 MISSING=0 EXTRA=0
```

**what to do**: download the file, unzip it, process it. it's good to go.

---

**tested fail scenario**:
```bash
curl -X POST "https://func-hash-validation-dev.azurewebsites.net/api/validatehash?code=YOUR_FUNCTION_KEY_HERE" \
  -H "Content-Type: application/json" \
  -d "@test_data/test_event_fail.json"
```

**got this email**:
```
subject: hash validation alert - FAIL - corrupted_data_2025-10-28.zip

validation status: FAIL
file name: corrupted_data_2025-10-28.zip
hash file: corrupted_data_2025-10-28.hash
timestamp: 2025-10-29 04:10:49

results:
files extracted: 3
files ok: 2
files failed: 1
files missing: 0
extra files: 0

message:
validation failed: hash mismatch or file discrepancies found

validation details:
OK       : departments.csv
FAIL     : employees.csv
OK       : payroll.csv

SUMMARY: OK=2 FAIL=1 MISSING=0 EXTRA=0
```

**what to do**: DO NOT process this file. contact the government, tell them employees.csv is corrupted, request a new file.

both emails arrived within seconds. ✅ working perfectly.

---

## configuration summary

### environment variables in azure function

| variable | value | what it's for |
|----------|-------|---------------|
| EMAIL_LOGIC_APP_URL | logic app http url | where to send validation results |
| ALERT_EMAIL_RECIPIENTS | ihetuemmanuel@gmail.com | who gets the emails (just for reference) |
| TEAMS_WEBHOOK_URL | (old teams url) | backup if logic app fails |

**check settings**:
```bash
az functionapp config appsettings list \
  --name func-hash-validation-dev \
  --resource-group rg-platform-dev \
  --output table
```

---

### logic app details

**name**: logic-hash-validation-email-dev
**resource group**: rg-platform-dev
**location**: canada central
**trigger**: http request
**action**: office 365 outlook - send email (v2)

**connected account**: ikechukwuemmanuelihetu82@gmail.com
**recipients**: ihetuemmanuel@gmail.com

**cost**:
- first 4,000 actions/month: FREE
- after that: $0.000025 per action
- our usage: ~100 emails/month = FREE

---

## example emails

### pass email

```
subject: hash validation alert - PASS - valid_data_2025-10-28.zip

body:
validation status: PASS
file name: valid_data_2025-10-28.zip
timestamp: 2025-10-29 04:10:41
files ok: 3
files failed: 0

all files validated successfully. safe to process.
```

### fail email

```
subject: hash validation alert - FAIL - corrupted_data_2025-10-28.zip

body:
validation status: FAIL
file name: corrupted_data_2025-10-28.zip
timestamp: 2025-10-29 04:10:49
files ok: 2
files failed: 1

employees.csv failed validation. DO NOT process. contact data provider.
```

---

## troubleshooting

### no email received?

**check 1: logic app run history**

go to azure portal → logic app → runs

you should see recent runs with either:
- ✅ green checkmark = success, email was sent
- ❌ red x = failed, click to see why

**check 2: spam folder**

logic app emails sometimes land in spam at first. check spam, mark as "not spam" to train your email provider.

**check 3: function logs**

```bash
az webapp log tail \
  --name func-hash-validation-dev \
  --resource-group rg-platform-dev
```

look for:
- "sending email notification via logic app..."
- "email notification sent successfully"

if there are errors, they'll tell you what went wrong.

---

### logic app failed?

**common causes**:
1. email account disconnected - re-authenticate in logic app designer
2. invalid recipient email - check the "to" field
3. logic app url changed - if you modified the logic app, get the new url and update the function setting

**fix**:
1. go to logic app designer
2. click "send an email" action
3. click "change connection"
4. sign in again with your microsoft account

---

### email looks weird?

**likely cause**: dynamic content not mapped correctly

**fix**:
1. go to logic app designer
2. click "send an email" action
3. make sure all `[field names]` show up as blue/purple pills (dynamic content)
4. if they're just plain text, delete and re-add using the lightning bolt
5. save

---

## adding more recipients

**option 1: edit logic app (recommended)**
1. logic app designer
2. click "send an email" action
3. in "to" field, add emails separated by semicolons:
   ```
   ihetuemmanuel@gmail.com;john@company.com;jane@company.com
   ```
4. save

**option 2: use cc or bcc**
- click "show advanced options" in email action
- fill in cc or bcc fields
- use semicolons for multiple addresses

---

## customizing emails

### change subject line

edit the "subject" field in logic app designer. you can add:
- fixed text: "URGENT: " or "[production] "
- dynamic fields: use lightning bolt to insert any field
- emojis: ✅ ❌ ⚠️ work fine in subjects

### add colors (advanced)

office 365 outlook connector doesn't support html easily. to add colors:
- use html body (advanced option)
- or switch to sendgrid connector (more setup)
- or just rely on subject line (PASS vs FAIL is clear enough)

---

## costs

### current setup
- logic app runs: ~100/month
- first 4,000 actions: FREE
- cost: $0.00/month

### if usage grows
- 10,000 emails/month: $0.15
- 100,000 emails/month: $2.40

**bottom line**: email notifications are basically free

---

## what we learned

### what worked
- logic apps are easier than expected (point and click, no coding)
- office 365 integration is seamless (one login, done)
- terraform for infrastructure, portal for configuration (good balance)
- testing with curl before enabling event grid triggers (smart move)

### what didn't work
- teams power automate (authentication hell)
- gmail connector (same authentication problems)
- trying to configure logic app completely in terraform (too complex)

### what we'd do different next time
- start with email from day one instead of wasting time on teams
- document the logic app url immediately (almost lost it)
- set up email filters in outlook to auto-organize validation emails

---

## next steps (future improvements)

### 1. add email priority

for fail emails, mark as high priority:
- add "importance" field in logic app
- set to "high" when status = FAIL
- set to "normal" when status = PASS

### 2. include direct links to files

add blob storage url to email so team can download directly:
- modify function to include blob url in validation results
- update logic app schema to include "blobUrl" field
- add clickable link in email body

### 3. weekly summary reports

create second logic app that runs weekly:
- query validation history from database
- summarize: total files, success rate, common failures
- send report to managers

### 4. integrate with ticketing

when validation fails:
- auto-create ticket in your system (servicenow, jira, etc.)
- assign to data ops team
- include validation details in ticket

---

## quick reference

### all the commands we ran

```bash
# 1. create logic app
cd terraform
terraform apply -auto-approve

# 2. configure function setting
az functionapp config appsettings set \
  --name func-hash-validation-dev \
  --resource-group rg-platform-dev \
  --settings "EMAIL_LOGIC_APP_URL=https://prod-09.canadacentral.logic.azure.com:443/workflows/..."

# 3. package function
cd azure_function
powershell -Command "Compress-Archive -Path * -DestinationPath ../function-app.zip -Force"

# 4. deploy function
cd ..
az functionapp deployment source config-zip \
  --resource-group rg-platform-dev \
  --name func-hash-validation-dev \
  --src function-app.zip

# 5. restart function
az functionapp restart \
  --name func-hash-validation-dev \
  --resource-group rg-platform-dev

# 6. test pass
curl -X POST "https://func-hash-validation-dev.azurewebsites.net/api/validatehash?code=KEY" \
  -H "Content-Type: application/json" \
  -d "@test_data/test_event_pass.json"

# 7. test fail
curl -X POST "https://func-hash-validation-dev.azurewebsites.net/api/validatehash?code=KEY" \
  -H "Content-Type: application/json" \
  -d "@test_data/test_event_fail.json"
```

---

## support

**contact**: emmanuel ihetu (ihetuemmanuel@gmail.com)
**project**: government of canada data validation pipeline
**environment**: development

**resources**:
- azure portal: https://portal.azure.com
- logic app: logic-hash-validation-email-dev
- function app: func-hash-validation-dev
- resource group: rg-platform-dev

---

**status**: complete and tested ✅
**last validated**: october 29, 2025, 4:10am
**email notifications**: working perfectly
