-- Drop CreatedDate column from all tables for testing
-- This allows the pipeline to run without this column

USE HRPayrollDB;
GO

-- HR Tables
ALTER TABLE HR_Employees DROP COLUMN CreatedDate;
ALTER TABLE HR_Departments DROP COLUMN CreatedDate;
ALTER TABLE HR_Positions DROP COLUMN CreatedDate;
ALTER TABLE HR_Locations DROP COLUMN CreatedDate;
ALTER TABLE HR_Performance DROP COLUMN CreatedDate;

-- Payroll Tables
ALTER TABLE Payroll_Salaries DROP COLUMN CreatedDate;
ALTER TABLE Payroll_Bonuses DROP COLUMN CreatedDate;
ALTER TABLE Payroll_Deductions DROP COLUMN CreatedDate;
ALTER TABLE Payroll_Benefits DROP COLUMN CreatedDate;
ALTER TABLE Payroll_Timesheets DROP COLUMN CreatedDate;

PRINT '✓ CreatedDate column dropped from all 10 tables';
PRINT 'Pipeline can now load data without CreatedDate!';
