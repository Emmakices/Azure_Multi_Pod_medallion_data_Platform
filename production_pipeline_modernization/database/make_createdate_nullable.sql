-- Make CreatedDate nullable in all tables for testing
-- This allows the pipeline to run without Excel needing this column

USE HRPayrollDB;
GO

-- HR Tables
ALTER TABLE HR_Employees ALTER COLUMN CreatedDate DATETIME2 NULL;
ALTER TABLE HR_Departments ALTER COLUMN CreatedDate DATETIME2 NULL;
ALTER TABLE HR_Positions ALTER COLUMN CreatedDate DATETIME2 NULL;
ALTER TABLE HR_Locations ALTER COLUMN CreatedDate DATETIME2 NULL;
ALTER TABLE HR_Performance ALTER COLUMN CreatedDate DATETIME2 NULL;

-- Payroll Tables
ALTER TABLE Payroll_Salaries ALTER COLUMN CreatedDate DATETIME2 NULL;
ALTER TABLE Payroll_Bonuses ALTER COLUMN CreatedDate DATETIME2 NULL;
ALTER TABLE Payroll_Deductions ALTER COLUMN CreatedDate DATETIME2 NULL;
ALTER TABLE Payroll_Benefits ALTER COLUMN CreatedDate DATETIME2 NULL;
ALTER TABLE Payroll_Timesheets ALTER COLUMN CreatedDate DATETIME2 NULL;

PRINT 'CreatedDate columns are now nullable in all 10 tables';
