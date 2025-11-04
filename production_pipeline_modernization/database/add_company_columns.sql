-- Add Company column to all HR and Payroll tables

-- HR Tables
ALTER TABLE dbo.HR_Employees ADD Company NVARCHAR(50) NOT NULL DEFAULT 'Unknown';
ALTER TABLE dbo.HR_Departments ADD Company NVARCHAR(50) NOT NULL DEFAULT 'Unknown';
ALTER TABLE dbo.HR_Positions ADD Company NVARCHAR(50) NOT NULL DEFAULT 'Unknown';
ALTER TABLE dbo.HR_Locations ADD Company NVARCHAR(50) NOT NULL DEFAULT 'Unknown';
ALTER TABLE dbo.HR_Performance ADD Company NVARCHAR(50) NOT NULL DEFAULT 'Unknown';

-- Payroll Tables
ALTER TABLE dbo.Payroll_Salaries ADD Company NVARCHAR(50) NOT NULL DEFAULT 'Unknown';
ALTER TABLE dbo.Payroll_Bonuses ADD Company NVARCHAR(50) NOT NULL DEFAULT 'Unknown';
ALTER TABLE dbo.Payroll_Deductions ADD Company NVARCHAR(50) NOT NULL DEFAULT 'Unknown';
ALTER TABLE dbo.Payroll_Benefits ADD Company NVARCHAR(50) NOT NULL DEFAULT 'Unknown';
ALTER TABLE dbo.Payroll_Timesheets ADD Company NVARCHAR(50) NOT NULL DEFAULT 'Unknown';

PRINT 'Company columns added to all tables successfully';
