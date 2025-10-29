# Sample Files Folder

This folder will contain sample/example files for testing:

## File Naming Examples
Create file: `file_naming_examples.txt`
```
ZIP Files:
- PSPS_HR_2025-01-17.zip
- SSPC_Payroll_2025-01-17.zip
- [Add actual naming conventions here]

Hash Files:
- PSPS_HR_2025-01-17.zip.sha256
- [Add actual naming conventions here]

Excel Files (inside ZIP):
- Employee_Data.xlsx
- Payroll_Data.xlsx
- [Add actual file names here]
```

## Hash File Format Examples
Create file: `hash_file_format.txt`
```
Example 1: Single line with hash
abc123def456789...

Example 2: Hash with file name
abc123def456789 PSPS_HR_2025-01-17.zip

Example 3: Multiple lines
SHA256(PSPS_HR_2025-01-17.zip)= abc123def456789

[Add actual format here]
```

## Excel Structure Examples
Create file: `excel_structure.txt`
```
HR Excel File Structure:
File: Employee_Data.xlsx
├─ Sheet 1: Personal (columns: EmployeeID, Name, DOB, ...)
├─ Sheet 2: Benefits (columns: EmployeeID, PlanType, ...)
└─ Sheet 3: Emergency_Contacts (columns: EmployeeID, ContactName, ...)

Payroll Excel File Structure:
File: Payroll_Data.xlsx
├─ Sheet 1: Earnings (columns: EmployeeID, GrossPay, ...)
├─ Sheet 2: Deductions (columns: EmployeeID, TaxAmount, ...)
└─ Sheet 3: Net_Pay (columns: EmployeeID, NetAmount, ...)

[Add actual structure here]
```

## Test Data
- Create small sample ZIP files for POC testing
- Create corresponding hash files
- Create sample Excel files

---

**Status**: Awaiting samples from user

**Next**: User to provide:
1. Example file names (real naming convention)
2. Hash file format
3. Excel structure documentation
