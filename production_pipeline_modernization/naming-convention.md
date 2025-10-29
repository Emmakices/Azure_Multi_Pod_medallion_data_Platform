# Hash File and ZIP File Naming Convention

## Overview

The Azure Function hash validation pipeline requires that hash files and ZIP files follow a **matching name convention**. This document explains why this design exists and how to modify it if needed.

---

## Current Implementation

### Automatic Name Pairing

In the Azure Function (`azure_function/ValidateHash/run.ps1`), the hash filename is automatically derived from the ZIP filename:

```powershell
# Extract hash filename from blob name (replace .zip with .hash)
$hashFileName = $blobName -replace '\.zip$', '.hash'
```

### Example

When Event Grid triggers on a blob upload:

**Event Grid Event:**
```json
{
  "subject": "/blobServices/default/containers/data/blobs/payroll_2025-10-28.zip"
}
```

**Automatic Behavior:**
- ZIP file detected: `payroll_2025-10-28.zip`
- Hash file expected: `payroll_2025-10-28.hash` (automatically derived)
- System downloads both files
- Validates ZIP contents against hash file

---

## Why This Design?

### Advantages

1. **Simplicity**
   - Event Grid only needs to trigger on the ZIP file
   - No need to specify hash file location in the event
   - Reduces configuration complexity

2. **Automatic Pairing**
   - No risk of validating against the wrong hash file
   - Clear 1:1 relationship between data and validation file
   - Prevents human error in file selection

3. **Convention Over Configuration**
   - Enforces a predictable naming pattern
   - Easier to understand data flow
   - Self-documenting file relationships

4. **Industry Standard Practice**
   - Common pattern in data integrity verification
   - Similar to `.md5` / `.sha256` checksum files
   - Matches how most data providers deliver files

### Real-World Scenario Example

```
Data Provider Sends:
├── employee_data_2025_Q1.zip          (actual data)
└── employee_data_2025_Q1.hash         (trusted hashes from source)

System Behavior:
1. ZIP file uploaded → Event Grid triggers
2. Function automatically looks for matching .hash file
3. Validates ZIP contents against expected hashes
4. Returns PASS/FAIL based on integrity check
```

---

## Alternative Designs (If Requirements Change)

If your data provider uses a different delivery pattern, you can modify the Azure Function code.

### Option 1: Fixed Hash Filename

Use when the data provider **always** sends the same hash file name regardless of data file.

**Scenario:**
```
Data Provider Sends:
├── daily_data_2025-10-28.zip
├── daily_data_2025-10-29.zip
└── official_hashes.hash              ← Always the same name
```

**Code Change (run.ps1):**
```powershell
# OLD: Derive hash name from ZIP name
# $hashFileName = $blobName -replace '\.zip$', '.hash'

# NEW: Always use fixed hash filename
$hashFileName = "official_hashes.hash"
```

**Pros:**
- One "master" hash file validates all deliveries
- Reduces file uploads (only update hash when needed)

**Cons:**
- Hash file must contain hashes for ALL possible files
- Cannot have different expected hashes per delivery
- More complex hash file management

---

### Option 2: Hash Filename from Event Metadata

Use when hash filename varies and cannot be predicted from ZIP name.

**Scenario:**
```
Data Provider Sends:
├── data_20251028_v2.zip
└── validation_hashes_final.hash      ← Non-standard name
```

**Code Change (run.ps1):**
```powershell
# Read hash filename from Event Grid metadata
$hashFileName = $eventGridEvent.data.metadata.hashFile

# Fallback to matching name if not specified
if (-not $hashFileName) {
    $hashFileName = $blobName -replace '\.zip$', '.hash'
}
```

**Event Grid Event:**
```json
{
  "data": {
    "url": "https://storage.blob.core.windows.net/data/data_20251028_v2.zip",
    "metadata": {
      "hashFile": "validation_hashes_final.hash"
    }
  }
}
```

**Pros:**
- Maximum flexibility
- Supports any naming pattern
- Backward compatible (fallback to matching name)

**Cons:**
- Requires metadata in blob upload
- More complex event configuration
- Additional validation needed

---

### Option 3: Hash File in Different Container

Use when hash files are stored separately from data files for security.

**Scenario:**
```
Data Container:
└── sensitive_data.zip

Validation Container (read-only for data pipeline):
└── trusted_hashes.hash
```

**Code Change (run.ps1):**
```powershell
# Download hash from different container
$hashContainerName = "validation"
$hashFileName = $blobName -replace '\.zip$', '.hash'

$hashUrl = "https://$storageAccount.blob.core.windows.net/$hashContainerName/$hashFileName"
```

**Pros:**
- Enhanced security (separate access controls)
- Hash files cannot be tampered with by data uploaders
- Audit trail separation

**Cons:**
- More complex permission management
- Two containers to maintain
- Requires careful access control configuration

---

## Current Setup Summary

**Test Environment:**
- Storage Account: `stdldevshared77b5h3`
- Container: `test`
- Naming Pattern: `{basename}_2025-10-28.{zip|hash}`

**Files in Test Container:**
```
valid_data_2025-10-28.zip          → valid_data_2025-10-28.hash
corrupted_data_2025-10-28.zip      → corrupted_data_2025-10-28.hash
```

**How It Works:**
1. Event Grid triggers on `*.zip` upload
2. Function extracts base name: `valid_data_2025-10-28`
3. Function downloads matching hash: `valid_data_2025-10-28.hash`
4. Validation runs using PowerShell script
5. Result returned: PASS/FAIL

---

## Recommendations

### For Most Use Cases (Current Design)
✅ **Keep the matching name convention** if:
- Data provider sends paired files with matching names
- Each data delivery has its own expected hashes
- Simplicity is preferred over flexibility

### When to Consider Alternatives

**Option 1 (Fixed Hash File)** if:
- Hash file rarely changes
- All deliveries validated against same expected values
- You want to reduce file uploads

**Option 2 (Event Metadata)** if:
- Naming patterns are unpredictable
- Legacy system with inconsistent naming
- Need maximum flexibility

**Option 3 (Separate Container)** if:
- Security requirements mandate separation
- Compliance requires audit trail isolation
- Different teams manage data vs validation

---

## Implementation Location

The naming logic is located in:
- **File:** `azure_function/ValidateHash/run.ps1`
- **Line:** Approximately line 50-60 (search for `$hashFileName`)
- **Code:**
  ```powershell
  $hashFileName = $blobName -replace '\.zip$', '.hash'
  ```

To modify this behavior, edit the above line according to one of the alternative designs.

---

## Testing After Changes

If you modify the naming convention, update your test scenarios:

1. **Update test events** - Ensure event JSON matches new naming pattern
2. **Regenerate test files** - Create hash files with new names
3. **Update documentation** - Reflect changes in QUICK_START_GUIDE.md
4. **Test both scenarios** - Verify PASS and FAIL cases still work

**Test Commands:**
```bash
# Test with new naming pattern
curl -X POST "https://func-hash-validation-dev.azurewebsites.net/api/validatehash?code=..." \
  -H "Content-Type: application/json" \
  -d "@test_data/test_event_updated.json"
```

---

## Questions to Ask Your Data Provider

Before modifying the naming convention, clarify with your data provider:

1. **Naming Pattern:**
   - Do you send files with matching names (data.zip + data.hash)?
   - Or different naming patterns?

2. **Hash File Frequency:**
   - Is the hash file unique per delivery?
   - Or one master hash file for all deliveries?

3. **Delivery Method:**
   - Are both files uploaded simultaneously?
   - Or hash file uploaded separately?

4. **Security Requirements:**
   - Do hash files need separate access controls?
   - Any compliance requirements for separation?

---

## Related Documentation

- **QUICK_START_GUIDE.md** - How to run validation tests
- **IMPLEMENTATION_GUIDE.md** - Full architecture and deployment
- **azure_function/ValidateHash/run.ps1** - Main function code with naming logic

---

**Document Version:** 1.0
**Last Updated:** 2025-10-28
**Author:** Hash Validation Pipeline Team
