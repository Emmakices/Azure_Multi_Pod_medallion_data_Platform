-- ============================================
-- Add Company Column to All Tables
-- ============================================
-- This script adds a Company discriminator column to all 10 tables
-- to distinguish between company_A and company_B data
-- ============================================

USE HRPayrollDB;
GO

-- Check if columns already exist, add if not
PRINT 'Adding Company column to HR tables...';

-- HR_Employees
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.HR_Employees') AND name = 'Company')
BEGIN
    ALTER TABLE dbo.HR_Employees ADD Company NVARCHAR(50) NOT NULL DEFAULT 'company_A';
    PRINT '✓ Added Company to HR_Employees';
END
ELSE
    PRINT '  HR_Employees.Company already exists';

-- HR_Departments
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.HR_Departments') AND name = 'Company')
BEGIN
    ALTER TABLE dbo.HR_Departments ADD Company NVARCHAR(50) NOT NULL DEFAULT 'company_A';
    PRINT '✓ Added Company to HR_Departments';
END
ELSE
    PRINT '  HR_Departments.Company already exists';

-- HR_Positions
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.HR_Positions') AND name = 'Company')
BEGIN
    ALTER TABLE dbo.HR_Positions ADD Company NVARCHAR(50) NOT NULL DEFAULT 'company_A';
    PRINT '✓ Added Company to HR_Positions';
END
ELSE
    PRINT '  HR_Positions.Company already exists';

-- HR_Locations
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.HR_Locations') AND name = 'Company')
BEGIN
    ALTER TABLE dbo.HR_Locations ADD Company NVARCHAR(50) NOT NULL DEFAULT 'company_A';
    PRINT '✓ Added Company to HR_Locations';
END
ELSE
    PRINT '  HR_Locations.Company already exists';

-- HR_Performance
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.HR_Performance') AND name = 'Company')
BEGIN
    ALTER TABLE dbo.HR_Performance ADD Company NVARCHAR(50) NOT NULL DEFAULT 'company_A';
    PRINT '✓ Added Company to HR_Performance';
END
ELSE
    PRINT '  HR_Performance.Company already exists';

PRINT '';
PRINT 'Adding Company column to Payroll tables...';

-- Payroll_Salaries
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Payroll_Salaries') AND name = 'Company')
BEGIN
    ALTER TABLE dbo.Payroll_Salaries ADD Company NVARCHAR(50) NOT NULL DEFAULT 'company_A';
    PRINT '✓ Added Company to Payroll_Salaries';
END
ELSE
    PRINT '  Payroll_Salaries.Company already exists';

-- Payroll_Bonuses
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Payroll_Bonuses') AND name = 'Company')
BEGIN
    ALTER TABLE dbo.Payroll_Bonuses ADD Company NVARCHAR(50) NOT NULL DEFAULT 'company_A';
    PRINT '✓ Added Company to Payroll_Bonuses';
END
ELSE
    PRINT '  Payroll_Bonuses.Company already exists';

-- Payroll_Deductions
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Payroll_Deductions') AND name = 'Company')
BEGIN
    ALTER TABLE dbo.Payroll_Deductions ADD Company NVARCHAR(50) NOT NULL DEFAULT 'company_A';
    PRINT '✓ Added Company to Payroll_Deductions';
END
ELSE
    PRINT '  Payroll_Deductions.Company already exists';

-- Payroll_Benefits
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Payroll_Benefits') AND name = 'Company')
BEGIN
    ALTER TABLE dbo.Payroll_Benefits ADD Company NVARCHAR(50) NOT NULL DEFAULT 'company_A';
    PRINT '✓ Added Company to Payroll_Benefits';
END
ELSE
    PRINT '  Payroll_Benefits.Company already exists';

-- Payroll_Timesheets
IF NOT EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Payroll_Timesheets') AND name = 'Company')
BEGIN
    ALTER TABLE dbo.Payroll_Timesheets ADD Company NVARCHAR(50) NOT NULL DEFAULT 'company_A';
    PRINT '✓ Added Company to Payroll_Timesheets';
END
ELSE
    PRINT '  Payroll_Timesheets.Company already exists';

GO

PRINT '';
PRINT '============================================';
PRINT 'Creating indexes on Company columns...';
PRINT '============================================';

-- Create non-clustered indexes on Company column for better query performance
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HR_Employees_Company' AND object_id = OBJECT_ID('dbo.HR_Employees'))
    CREATE NONCLUSTERED INDEX IX_HR_Employees_Company ON dbo.HR_Employees(Company);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HR_Departments_Company' AND object_id = OBJECT_ID('dbo.HR_Departments'))
    CREATE NONCLUSTERED INDEX IX_HR_Departments_Company ON dbo.HR_Departments(Company);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HR_Positions_Company' AND object_id = OBJECT_ID('dbo.HR_Positions'))
    CREATE NONCLUSTERED INDEX IX_HR_Positions_Company ON dbo.HR_Positions(Company);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HR_Locations_Company' AND object_id = OBJECT_ID('dbo.HR_Locations'))
    CREATE NONCLUSTERED INDEX IX_HR_Locations_Company ON dbo.HR_Locations(Company);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HR_Performance_Company' AND object_id = OBJECT_ID('dbo.HR_Performance'))
    CREATE NONCLUSTERED INDEX IX_HR_Performance_Company ON dbo.HR_Performance(Company);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payroll_Salaries_Company' AND object_id = OBJECT_ID('dbo.Payroll_Salaries'))
    CREATE NONCLUSTERED INDEX IX_Payroll_Salaries_Company ON dbo.Payroll_Salaries(Company);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payroll_Bonuses_Company' AND object_id = OBJECT_ID('dbo.Payroll_Bonuses'))
    CREATE NONCLUSTERED INDEX IX_Payroll_Bonuses_Company ON dbo.Payroll_Bonuses(Company);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payroll_Deductions_Company' AND object_id = OBJECT_ID('dbo.Payroll_Deductions'))
    CREATE NONCLUSTERED INDEX IX_Payroll_Deductions_Company ON dbo.Payroll_Deductions(Company);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payroll_Benefits_Company' AND object_id = OBJECT_ID('dbo.Payroll_Benefits'))
    CREATE NONCLUSTERED INDEX IX_Payroll_Benefits_Company ON dbo.Payroll_Benefits(Company);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payroll_Timesheets_Company' AND object_id = OBJECT_ID('dbo.Payroll_Timesheets'))
    CREATE NONCLUSTERED INDEX IX_Payroll_Timesheets_Company ON dbo.Payroll_Timesheets(Company);

PRINT '✓ Indexes created successfully';

GO

PRINT '';
PRINT '============================================';
PRINT 'Verification - List all tables with Company column';
PRINT '============================================';

SELECT
    t.TABLE_NAME as TableName,
    c.COLUMN_NAME as ColumnName,
    c.DATA_TYPE as DataType,
    c.CHARACTER_MAXIMUM_LENGTH as MaxLength,
    c.IS_NULLABLE as IsNullable
FROM INFORMATION_SCHEMA.TABLES t
JOIN INFORMATION_SCHEMA.COLUMNS c ON t.TABLE_NAME = c.TABLE_NAME
WHERE t.TABLE_SCHEMA = 'dbo'
    AND t.TABLE_TYPE = 'BASE TABLE'
    AND (t.TABLE_NAME LIKE 'HR_%' OR t.TABLE_NAME LIKE 'Payroll_%')
    AND c.COLUMN_NAME = 'Company'
ORDER BY t.TABLE_NAME;

PRINT '';
PRINT '============================================';
PRINT 'Company column migration complete!';
PRINT '============================================';
