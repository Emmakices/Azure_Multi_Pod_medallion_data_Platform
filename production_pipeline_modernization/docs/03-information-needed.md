# Information Needed from User

**Last Updated**: 2025-01-17

---

## Critical Items (Need ASAP to Start Design)

### 1. PowerShell Hash Validation Script
**Status**: [PENDING]

**Why needed**:
- Understand exact hash algorithm being used
- See validation logic to replicate in Azure Function
- Identify any edge cases or special handling

**Questions**:
- Can you share the PowerShell script?
- Does it have any dependencies?
- Has it been tested with production files?

---

### 2. File Naming Conventions
**Status**: [PENDING]

**Why needed**:
- Determine how to route files to correct folders (psps vs sspc)
- Parse file names to identify data type (HR vs Payroll)
- Build dynamic pipeline logic

**Need examples of**:
- ZIP file names (e.g., `PSPS_HR_2025-01-17.zip`)
- Hash file names (e.g., `PSPS_HR_2025-01-17.zip.sha256`)
- Excel file names inside ZIP
- Any naming patterns or conventions

---

### 3. Hash Algorithm & Format
**Status**: [PENDING]

**Why needed**:
- Configure hash calculation correctly
- Parse hash file format

**Questions**:
- What hash algorithm? (MD5, SHA256, SHA512, other?)
- Hash file format examples:
  - Single line with hash value?
  - Format like: `abc123def456 data.zip`?
  - JSON format?
  - XML format?

---

### 4. File Size Estimates
**Status**: [PENDING]

**Why needed**:
- Determine if Azure Function sufficient or need Databricks
- Plan for timeout handling
- Estimate processing time

**Questions**:
- Typical ZIP file size?
- Largest ZIP file you've seen?
- Total extracted size after unzip?

---

### 5. Database Details
**Status**: [PENDING]

**Why needed**:
- Design logging tables
- Configure ADF linked service
- Plan data retention

**Questions**:
- Database type? (Azure SQL Database, SQL Server on VM, Synapse, other?)
- Connection string format?
- Authentication method? (SQL auth, managed identity, other?)
- Database name?
- Schema name for logging tables?

---

## Important Items (Needed for Complete Solution)

### 6. Current ADF Pipeline JSON
**Status**: [PENDING]

**Why needed**:
- Understand current logic
- Preserve working parts
- Plan integration points

**Request**:
- Export ENTRY HR pipeline JSON
- Export CORE HR pipeline JSON
- Any other related pipelines

**How to export**:
```
ADF Studio → Pipeline → {} (Code button) → Copy JSON
```

---

### 7. Excel File Structure
**Status**: [PENDING]

**Why needed**:
- Understand sheet names and structure
- Plan sheet iteration logic
- Design table naming

**Questions**:
- What are typical sheet names in HR Excel files?
- What are typical sheet names in Payroll Excel files?
- Are sheet names consistent across files?
- How many sheets per file typically?

Example:
```
HR_Employee_Data.xlsx:
├─ Personal
├─ Benefits
├─ Emergency_Contacts
└─ Job_History

Payroll_Data.xlsx:
├─ Earnings
├─ Deductions
└─ Taxes
```

---

### 8. Alert & Notification Requirements
**Status**: [PENDING]

**Why needed**:
- Configure alerting system
- Identify stakeholders
- Set up notification channels

**Questions**:
- Who should receive alerts on failures?
- Preferred notification method? (Email, Teams, SMS, other?)
- What should alerts contain?
- Different alerts for different error types?

---

### 9. Azure DevOps Repository
**Status**: [PENDING]

**Why needed**:
- Set up CI/CD pipeline
- Understand current structure
- Plan deployment automation

**Questions**:
- Do you have ADO repository with ADF pipelines?
- Can you share repository structure?
- Do you have service principal for deployments?
- What branch strategy? (main, dev, feature branches?)

---

### 10. Processing Frequency
**Status**: [PENDING]

**Why needed**:
- Plan trigger configuration
- Estimate monthly costs
- Design batching strategy (if applicable)

**Questions**:
- How often do files arrive? (Daily, weekly, ad-hoc?)
- Time of day files typically arrive?
- Multiple files per day?
- Peak times?

---

## Nice to Have Items (For Optimization)

### 11. Logging Diagram
**Status**: [PENDING]

**Why needed**:
- Understand current logging approach
- Identify gaps
- Plan comprehensive logging

**Request**:
- Logging diagram (if available)
- Current log/XML output examples

---

### 12. SLA Requirements
**Status**: [PENDING]

**Why needed**:
- Set performance targets
- Plan monitoring thresholds
- Design retry logic

**Questions**:
- Maximum acceptable processing time?
- Uptime requirements?
- Data freshness requirements?

---

### 13. Environment Details
**Status**: [PENDING]

**Why needed**:
- Plan multi-environment deployment
- Configure environment-specific settings
- Design promotion process

**Questions**:
- How many environments? (dev, test, prod?)
- Separate Azure subscriptions or resource groups?
- Who approves prod deployments?

---

### 14. Compliance & Security Requirements
**Status**: [PENDING]

**Why needed**:
- Plan security controls
- Design audit logging
- Ensure regulatory compliance

**Questions**:
- Data classification level? (Public, Internal, Confidential?)
- Regulatory requirements? (Privacy laws, retention policies?)
- Encryption requirements?
- Access control requirements?

---

### 15. Error Handling Preferences
**Status**: [PENDING]

**Why needed**:
- Design retry logic
- Configure failure handling
- Plan recovery procedures

**Questions**:
- How many retries on failure?
- Retry delay?
- What happens to failed files?
- Manual intervention process?

---

## How to Provide Information

### For Scripts/Code
```
Create a file: production_pipeline_modernization/scripts/hash_validation.ps1
```

### For JSON Exports
```
Create files in: production_pipeline_modernization/adf/
├─ entry_hr_pipeline.json
└─ core_hr_pipeline.json
```

### For Sample Files
```
Create folder: production_pipeline_modernization/samples/
├─ sample_file_names.txt
├─ sample_hash_file.txt
└─ sample_excel_structure.txt
```

### For Documentation
```
Update existing docs or add notes in this file
```

---

## Tracking

| Item | Priority | Status | Date Needed | Notes |
|------|----------|--------|-------------|-------|
| PowerShell script | CRITICAL | PENDING | ASAP | Blocks validation design |
| File naming | CRITICAL | PENDING | ASAP | Needed for routing logic |
| Hash algorithm | CRITICAL | PENDING | ASAP | Needed for validation |
| File sizes | CRITICAL | PENDING | ASAP | Determines tech choice |
| Database details | CRITICAL | PENDING | Week 1 | Needed for logging |
| ADF pipeline JSON | HIGH | PENDING | Week 1 | Helpful for understanding |
| Excel structure | HIGH | PENDING | Week 1 | Needed for processing |
| Alert requirements | HIGH | PENDING | Week 2 | Needed for monitoring |
| ADO repository | MEDIUM | PENDING | Week 2 | Needed for CI/CD |
| Frequency | MEDIUM | PENDING | Week 2 | Helpful for planning |
| Logging diagram | LOW | PENDING | Week 3 | Nice to have |
| SLA requirements | LOW | PENDING | Week 3 | Nice to have |
| Environments | MEDIUM | PENDING | Week 2 | Needed for deployment |
| Compliance | MEDIUM | PENDING | Week 2 | May impact design |
| Error handling | MEDIUM | PENDING | Week 2 | Needed for retry logic |

---

**Next Action**: User to provide critical items so we can start POC design.
