# Current Production Architecture

**Last Updated**: 2025-01-17

---

## Data Flow Overview

```
Government of Canada
         |
         | (sends data)
         v
    Microsoft
         |
         | (routes data)
         v
CGI Azure Blob Storage
Container: dflink
├─ data.zip (zipped file)
└─ data.zip.hash (hash file for validation)
         |
         | [MANUAL STEP 1]
         | Download to F:\ drive
         v
F:\ Drive (Utility Server VM)
└─ Network file share on Windows VM
   └─ Temporary staging area
         |
         | [MANUAL STEP 2]
         | Extract ZIP manually
         v
     Extract files
         |
         | [MANUAL STEP 3]
         | Upload to blob storage
         v
CGI Azure Blob Storage
Container: day_force_templates
├─ psps/ (Company 1)
│   ├─ HR data (Excel files with multiple sheets)
│   └─ Payroll data (Excel files with multiple sheets)
└─ sspc/ (Company 2)
    ├─ HR data (Excel files with multiple sheets)
    └─ Payroll data (Excel files with multiple sheets)
         |
         | [MANUAL STEP 4]
         | Run ADF in debug mode
         v
    ADF Pipeline Processing
    ├─ ENTRY HR Pipeline
    │   └─ Iterates all files/folders
    │
    └─ CORE HR Pipeline
        └─ Extracts Excel sheets (one by one)
        └─ Saves each sheet as separate DB table
         |
         v
    Database Tables
         |
         v
    Logs + XML Output
```

---

## Components

### 1. Storage Accounts

**Landing Zone:**
- Container: `dflink`
- Purpose: Receives zipped files from Government of Canada via Microsoft
- Contents: ZIP file + Hash file

**Processing Zone:**
- Container: `day_force_templates`
- Purpose: Stores extracted Excel files for processing
- Structure:
  ```
  day_force_templates/
  ├─ psps/
  │   ├─ HR/
  │   │   └─ [Excel files with multiple sheets]
  │   └─ Payroll/
  │       └─ [Excel files with multiple sheets]
  └─ sspc/
      ├─ HR/
      │   └─ [Excel files with multiple sheets]
      └─ Payroll/
          └─ [Excel files with multiple sheets]
  ```

### 2. F:\ Drive (Utility Server VM)

**What it is:**
- Network file share hosted on a Windows Virtual Machine
- Acts as temporary staging area for manual operations

**Purpose (Legacy):**
- Download zipped files from blob storage
- Manual extraction of ZIP files
- Staging before upload to day_force_templates

**Problems:**
- Manual intervention required
- Additional infrastructure cost (VM maintenance)
- Single point of failure
- No automation
- No validation before extraction

### 3. ADF Pipelines

#### ENTRY HR Pipeline
**Purpose**: Iterate through all files and folders in day_force_templates

**Logic**:
- Scans psps/ and sspc/ folders
- Identifies HR and Payroll files
- Triggers CORE HR pipeline for each file

#### CORE HR Pipeline
**Purpose**: Extract individual sheets from Excel files and save as database tables

**Logic**:
- Receives Excel file path from ENTRY HR
- Iterates through each sheet in the Excel file (one by one)
- Extracts data from each sheet
- Saves each sheet as a separate table in database

**Note**: Built this way because ADF doesn't allow nested loops (same issue we encountered in POC)

**Output**:
- Database tables (one per Excel sheet)
- Logs
- XML files

### 4. Database

**Type**: [PENDING - need to confirm]

**Tables Created**:
- One table per Excel sheet
- Naming convention: [PENDING - need to confirm]

### 5. Logging & Monitoring

**Current Method**: ADF Debug Mode

**Limitations**:
- Manual triggering required
- No comprehensive timestamps
- No activity-level logging
- No error tracking
- No data quality metrics (row counts, validation)
- No audit trail

---

## Current Process Flow (Step-by-Step)

### Step 1: File Arrival
1. Government of Canada sends data to Microsoft
2. Microsoft routes data to CGI blob storage (dflink container)
3. Two files arrive:
   - `data.zip` (compressed data file)
   - `data.zip.hash` (hash for validation)

**Issues**:
- No notification when file arrives
- No automatic validation
- No logging of file arrival

### Step 2: Manual Download (F:\ Drive)
1. User manually checks dflink container for new files
2. User downloads ZIP file to F:\ drive (utility server VM)
3. User downloads hash file to F:\ drive

**Issues**:
- Manual checking required (no automation)
- Time delay between arrival and processing
- No hash validation before download

### Step 3: Manual Extraction
1. User manually extracts ZIP file on F:\ drive
2. Identifies which company (psps or sspc) based on file contents
3. Identifies whether HR or Payroll data

**Issues**:
- No hash validation before extraction
- Manual identification of company/type
- Risk of extracting corrupted data
- No logging of extraction

### Step 4: Manual Upload to Blob Storage
1. User uploads extracted files to day_force_templates container
2. Places files in correct folder (psps/ or sspc/)
3. Places files in correct subfolder (HR/ or Payroll/)

**Issues**:
- Manual copy/paste operation
- Risk of placing files in wrong folder
- No validation of file structure
- No logging of upload

### Step 5: Manual ADF Execution
1. User opens ADF Studio
2. User runs ENTRY HR pipeline in debug mode
3. Monitors debug output for errors

**Issues**:
- Manual pipeline triggering
- Debug mode not suitable for production
- Limited logging
- No error alerts

### Step 6: Pipeline Processing
1. ENTRY HR iterates files/folders
2. CORE HR extracts Excel sheets
3. Data loaded to database tables
4. Logs and XML generated

**Issues**:
- No comprehensive logging
- No data quality checks
- No row count validation
- No SLA tracking

---

## Pain Points Summary

| Issue | Impact | Priority |
|-------|--------|----------|
| No hash validation | Risk of processing corrupted data | HIGH |
| Manual F:\ drive process | Slow, error-prone, time-consuming | HIGH |
| Manual ADF triggering | Delays processing, requires human intervention | HIGH |
| Debug mode for logging | Not production-ready, limited visibility | HIGH |
| ADO/ADF sync issues | Double work, version control problems | MEDIUM |
| No automated alerting | Errors not detected quickly | MEDIUM |
| No data quality checks | Bad data enters database | MEDIUM |

---

## Technical Debt

1. **Utility Server VM**: Unnecessary infrastructure (should be eliminated)
2. **Manual Operations**: Should be fully automated
3. **No CI/CD**: Manual changes to ADF pipelines
4. **Debug Mode**: Not suitable for production logging
5. **No Monitoring**: No dashboards, alerts, or metrics

---

## Data Characteristics

### File Sizes
- ZIP files: [PENDING - need confirmation]
- Extracted Excel files: [PENDING - need confirmation]

### File Structure
- Excel files contain multiple sheets
- Sheet names: [PENDING - need confirmation]
- Row counts per sheet: [PENDING - need confirmation]

### Data Types
- HR data: Employee information, benefits, etc.
- Payroll data: Pay information, deductions, etc.

### Processing Frequency
- [PENDING - need confirmation]
- Daily? Weekly? Ad-hoc?

---

## What Works Well (Keep These)

1. Two-pipeline design (ENTRY HR + CORE HR) - good separation of concerns
2. Folder structure for companies (psps/ sspc/) - clear organization
3. Separate HR and Payroll folders - logical segmentation
4. Excel sheet iteration logic - handles multi-sheet files

---

## What Needs Improvement

1. Hash validation (add before any processing)
2. Automation (eliminate all manual steps)
3. Logging (comprehensive, production-ready)
4. Monitoring (alerts, dashboards, metrics)
5. CI/CD (version control + automated deployment)
6. Error handling (retry logic, notifications)

---

## Questions to Answer

1. What hash algorithm is used? (MD5, SHA256, SHA512?)
2. What are the file naming conventions?
3. How often do files arrive?
4. What database is being used?
5. Can we see the PowerShell hash validation script?
6. Can we export the ADF pipeline JSON?
7. What does the logging diagram look like?
8. Who gets alerted when errors occur?
9. What are the SLA requirements?
10. Are there multiple environments (dev, test, prod)?
