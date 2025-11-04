-- Drop CreatedDate column and its constraints from all tables

USE HRPayrollDB;
GO

-- Drop constraints first, then columns

-- HR_Employees
DECLARE @sql NVARCHAR(MAX);
SELECT @sql = 'ALTER TABLE HR_Employees DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('HR_Employees')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('HR_Employees') AND name = 'CreatedDate');
IF @sql IS NOT NULL EXEC sp_executesql @sql;
ALTER TABLE HR_Employees DROP COLUMN CreatedDate;

-- HR_Departments
SELECT @sql = 'ALTER TABLE HR_Departments DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('HR_Departments')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('HR_Departments') AND name = 'CreatedDate');
IF @sql IS NOT NULL EXEC sp_executesql @sql;
ALTER TABLE HR_Departments DROP COLUMN CreatedDate;

-- HR_Positions
SELECT @sql = 'ALTER TABLE HR_Positions DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('HR_Positions')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('HR_Positions') AND name = 'CreatedDate');
IF @sql IS NOT NULL EXEC sp_executesql @sql;
ALTER TABLE HR_Positions DROP COLUMN CreatedDate;

-- HR_Locations
SELECT @sql = 'ALTER TABLE HR_Locations DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('HR_Locations')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('HR_Locations') AND name = 'CreatedDate');
IF @sql IS NOT NULL EXEC sp_executesql @sql;
ALTER TABLE HR_Locations DROP COLUMN CreatedDate;

-- HR_Performance
SELECT @sql = 'ALTER TABLE HR_Performance DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('HR_Performance')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('HR_Performance') AND name = 'CreatedDate');
IF @sql IS NOT NULL EXEC sp_executesql @sql;
ALTER TABLE HR_Performance DROP COLUMN CreatedDate;

-- Payroll_Salaries
SELECT @sql = 'ALTER TABLE Payroll_Salaries DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('Payroll_Salaries')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('Payroll_Salaries') AND name = 'CreatedDate');
IF @sql IS NOT NULL EXEC sp_executesql @sql;
ALTER TABLE Payroll_Salaries DROP COLUMN CreatedDate;

-- Payroll_Bonuses
SELECT @sql = 'ALTER TABLE Payroll_Bonuses DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('Payroll_Bonuses')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('Payroll_Bonuses') AND name = 'CreatedDate');
IF @sql IS NOT NULL EXEC sp_executesql @sql;
ALTER TABLE Payroll_Bonuses DROP COLUMN CreatedDate;

-- Payroll_Deductions
SELECT @sql = 'ALTER TABLE Payroll_Deductions DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('Payroll_Deductions')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('Payroll_Deductions') AND name = 'CreatedDate');
IF @sql IS NOT NULL EXEC sp_executesql @sql;
ALTER TABLE Payroll_Deductions DROP COLUMN CreatedDate;

-- Payroll_Benefits
SELECT @sql = 'ALTER TABLE Payroll_Benefits DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('Payroll_Benefits')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('Payroll_Benefits') AND name = 'CreatedDate');
IF @sql IS NOT NULL EXEC sp_executesql @sql;
ALTER TABLE Payroll_Benefits DROP COLUMN CreatedDate;

-- Payroll_Timesheets
SELECT @sql = 'ALTER TABLE Payroll_Timesheets DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('Payroll_Timesheets')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('Payroll_Timesheets') AND name = 'CreatedDate');
IF @sql IS NOT NULL EXEC sp_executesql @sql;
ALTER TABLE Payroll_Timesheets DROP COLUMN CreatedDate;

PRINT '✓ CreatedDate column dropped from all 10 tables';
PRINT 'Pipeline can now load data successfully!';
