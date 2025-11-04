# Self-Hosted IR Capability Test Pipelines

## Purpose
These test pipelines verify what capabilities are available on your self-hosted Integration Runtime (azc2dcuapp001).

## Pipelines

### 1. Test_CheckPowerShellVersion
**File:** `01_check_powershell_version.json`

**What it checks:**
- PowerShell version (need 5.1+ for our scripts)
- PowerShell edition (Core or Desktop)
- Temp folder creation/deletion capability
- Available disk space on C: drive
- Expand-Archive cmdlet availability (for ZIP extraction)
- Get-FileHash cmdlet availability (for SHA512 validation)

**Expected Output:**
```
=== PowerShell Version Check ===
PowerShell Version: 5.1.xxxxx
PowerShell Edition: Desktop
OS: Microsoft Windows ...
Temp folder creation: SUCCESS
C: Drive Free Space: XX.XX GB
Expand-Archive (ZIP extraction): AVAILABLE
Get-FileHash (SHA512): AVAILABLE
=== Test Complete ===
```

### 2. Test_CheckPythonVersion
**File:** `02_check_python_version.json`

**What it checks:**
- Python version (need 3.7+ for our scripts)
- Python executable path
- Platform and architecture
- Temp folder creation capability
- Required standard modules (zipfile, hashlib, json, os, shutil)
- Optional azure-storage-blob module

**Expected Output:**
```
=== Python Version Check ===
Python Version: 3.x.x
Python Executable: C:\Python3x\python.exe
Platform: Windows-...
Required Modules:
  zipfile: AVAILABLE
  hashlib: AVAILABLE
  json: AVAILABLE
  os: AVAILABLE
  shutil: AVAILABLE
  azure-storage-blob: AVAILABLE (or NOT AVAILABLE)
=== Test Complete ===
```

## How to Import and Run

### Step 1: Create Linked Service for Self-Hosted IR

Before importing these pipelines, ensure you have a linked service configured for your self-hosted IR.

**In Azure Data Factory:**
1. Go to **Manage** → **Linked services**
2. Click **+ New**
3. Search for **Integration Runtime**
4. Select your self-hosted IR from the dropdown
5. Name it: `SelfHostedIR_LinkedService`
6. Click **Create**

**OR** if you already have a linked service for the IR, note its name and update the JSON files:
- Replace `"SelfHostedIR_LinkedService"` with your actual linked service name

### Step 2: Import Pipelines

**Method A: Via ADF Studio UI**
1. Open Azure Data Factory Studio
2. Go to **Author** tab
3. Click **+** → **Pipeline** → **Import from pipeline template**
4. Select **Custom template**
5. Copy contents of `01_check_powershell_version.json` and paste
6. Click **Import**
7. Repeat for `02_check_python_version.json`

**Method B: Via ARM Template**
You can also deploy these via ARM template or Azure CLI if preferred.

### Step 3: Run the Tests

1. Open the `Test_CheckPowerShellVersion` pipeline
2. Click **Debug** (top toolbar)
3. Wait for completion (should take < 1 minute)
4. Click on the **CheckPowerShellVersion** activity
5. Go to **Output** tab to see the results

Repeat for `Test_CheckPythonVersion` pipeline.

## Decision Matrix Based on Results

### ✅ **Best Case: PowerShell 5.1+ AND Python 3.7+ Available**
→ Use PowerShell for validation, Python for extraction
→ Maximum flexibility and best performance

### ✅ **Good Case: PowerShell 5.1+ Available, No Python**
→ Use PowerShell for BOTH validation and extraction
→ PowerShell can handle ZIP, SHA512, and file operations
→ Slightly more verbose code but fully functional

### ⚠️ **Fallback: PowerShell < 5.1 or Not Available**
→ Need to use Azure Function for validation
→ Not recommended based on your colleague's confirmation that IR exists

## Notes

- **Script Activity Type:** These use `Script` activity with `NonQuery` type for PowerShell/Python execution
- **Timeout:** Set to 5 minutes (more than enough for these simple checks)
- **Logging:** Output is logged to Activity Output (viewable in ADF pipeline run details)
- **Self-Hosted IR:** Must be active and running for these tests to work
- **Permissions:** The IR service account (sa_cgi) must have permissions to execute PowerShell and Python

## Troubleshooting

### Error: "Activity type 'Script' is not supported"
- Your ADF instance may not support Script activities
- Try using **Custom Activity** or **Web Activity** to call PowerShell/Python via API

### Error: "Linked service not found"
- Update the `"referenceName"` in the JSON files to match your actual linked service name
- Check that the linked service is configured for the self-hosted IR

### Error: "Timeout expired"
- Increase the timeout in the pipeline JSON
- Check that the self-hosted IR is running and accessible

### No Output Visible
- Check **Monitor** → **Pipeline runs** → Select your run → Click on the activity
- Look in the **Output** tab for the results
- If empty, check **Error** tab for any issues

## Next Steps

Once you run these tests and get the results, share them with me and I'll:
1. Create the appropriate validation script (PowerShell or Python)
2. Create the appropriate extraction script
3. Build the full ADF pipeline with Storage Event Trigger
4. Provide deployment instructions
