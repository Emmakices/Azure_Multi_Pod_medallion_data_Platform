# Quick Start: Test Your Self-Hosted IR

## What You Need to Do

Your colleague confirmed you have a self-hosted IR on server **azc2dcuapp001**. Now we need to check if PowerShell and Python are available on it.

## Step-by-Step Instructions

### 1. Find Your Self-Hosted IR Linked Service Name

**In Azure Data Factory Studio:**
1. Click **Manage** (toolbox icon on left)
2. Click **Linked services**
3. Look for a linked service that references your self-hosted IR
   - It might be named something like:
     - `SelfHostedIR`
     - `AzureFunction`
     - `IntegrationRuntime`
     - `sa_cgi` (based on service account name)
4. **Write down the exact name**

### 2. Update the Test Pipeline Files

**If your linked service is NOT named `SelfHostedIR_LinkedService`:**

1. Open `01_check_powershell_version.json` in a text editor
2. Find this line (around line 21):
   ```json
   "referenceName": "SelfHostedIR_LinkedService",
   ```
3. Replace `SelfHostedIR_LinkedService` with your actual linked service name
4. Save the file

5. Do the same for `02_check_python_version.json`

**If your linked service IS named `SelfHostedIR_LinkedService`:**
- Skip this step, files are ready to use

### 3. Import the Test Pipelines into ADF

**In Azure Data Factory Studio:**

1. Go to **Author** tab (pencil icon on left)
2. Click the **+** button next to "Pipelines"
3. Select **Pipeline** → **Import from pipeline template**
4. Click **Use custom template**
5. Open `01_check_powershell_version.json` in a text editor
6. Copy the ENTIRE contents
7. Paste into ADF
8. Click **Import**
9. Repeat steps 2-8 for `02_check_python_version.json`

### 4. Run the PowerShell Test

1. In ADF Studio, open the `Test_CheckPowerShellVersion` pipeline
2. Click **Debug** at the top
3. Wait for it to complete (should take < 1 minute)
4. Click on the **CheckPowerShellVersion** activity box in the canvas
5. At the bottom, click the **Output** tab
6. Copy the entire output and send it to me

**Expected output looks like:**
```
=== PowerShell Version Check ===
PowerShell Version: 5.1.19041.5247
PowerShell Edition: Desktop
OS: Microsoft Windows 10.0.19045
Temp folder creation: SUCCESS (C:\Users\sa_cgi\AppData\Local\Temp\adf_test_20251031_123456)
C: Drive Free Space: 127.45 GB
Expand-Archive (ZIP extraction): AVAILABLE
Get-FileHash (SHA512): AVAILABLE
=== Test Complete ===
```

### 5. Run the Python Test

1. In ADF Studio, open the `Test_CheckPythonVersion` pipeline
2. Click **Debug** at the top
3. Wait for it to complete (should take < 1 minute)
4. Click on the **CheckPythonVersion** activity box in the canvas
5. At the bottom, click the **Output** tab
6. Copy the entire output and send it to me

**Expected output looks like:**
```
=== Python Version Check ===
Python Version: 3.9.13 (tags/v3.9.13:6de2ca5, May 17 2022, 16:36:42) [MSC v.1929 64 bit (AMD64)]
Python Executable: C:\Python39\python.exe
Platform: Windows-10-10.0.19041-SP0
Architecture: ('64bit', 'WindowsPE')
Temp folder creation: SUCCESS (C:\Users\sa_cgi\AppData\Local\Temp\adf_test_abc123)
Temp folder cleanup: SUCCESS

=== Required Modules ===
zipfile: AVAILABLE
hashlib: AVAILABLE
json: AVAILABLE
os: AVAILABLE
shutil: AVAILABLE
azure-storage-blob: AVAILABLE
=== Test Complete ===
```

**OR it might fail with:**
```
Error: Python is not recognized as an internal or external command
```

## What to Send Me

Send me the output from BOTH tests:
1. PowerShell test output
2. Python test output (or error message if it failed)

Based on the results, I'll provide you with the appropriate implementation:

### Scenario A: PowerShell 5.1+ ✅ AND Python 3.7+ ✅
→ Best case! I'll create:
- PowerShell script for SHA512 validation
- Python script for unzipping and selective extraction
- Full ADF pipeline that uses both

### Scenario B: PowerShell 5.1+ ✅ BUT Python ❌
→ Still good! I'll create:
- PowerShell script for SHA512 validation
- PowerShell script for unzipping and selective extraction (yes, PowerShell can do this!)
- Full ADF pipeline using PowerShell only

### Scenario C: PowerShell < 5.1 ❌
→ Unexpected, but we'll handle it:
- Need to install PowerShell 5.1 on the IR server
- Or use Azure Function instead

## Troubleshooting

### "I can't find the linked service"
- Check with your colleague where the self-hosted IR is configured
- Look in **Manage** → **Integration runtimes** to see the IR name
- Then check **Linked services** for any service using that IR

### "Pipeline import failed"
- Make sure you copied the ENTIRE JSON content (from first `{` to last `}`)
- Check that you updated the linked service name correctly
- Try creating a new pipeline manually and copying just the activities section

### "Activity failed with timeout"
- The self-hosted IR might be offline or busy
- Check **Manage** → **Integration runtimes** → Status should be "Running"
- Try again after a few minutes

### "Activity failed with permission denied"
- The service account (sa_cgi) might not have permissions
- This needs to be fixed at the server level by IT/DevOps
- Contact your colleague to grant necessary permissions

## Ready to Test?

Once you have the outputs from both tests, send them to me and I'll create the complete solution tailored to your exact environment!
