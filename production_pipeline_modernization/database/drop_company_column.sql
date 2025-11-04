-- Drop Company column and its constraints from all tables

USE HRPayrollDB;
GO

-- Drop indexes and constraints first, then columns

-- HR_Employees
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HR_Employees_Company' AND object_id = OBJECT_ID('HR_Employees'))
    DROP INDEX IX_HR_Employees_Company ON HR_Employees;

DECLARE @sql NVARCHAR(MAX);
SELECT @sql = 'ALTER TABLE HR_Employees DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('HR_Employees')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('HR_Employees') AND name = 'Company');
IF @sql IS NOT NULL EXEC sp_executesql @sql;

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('HR_Employees') AND name = 'Company')
    ALTER TABLE HR_Employees DROP COLUMN Company;

-- HR_Departments
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HR_Departments_Company' AND object_id = OBJECT_ID('HR_Departments'))
    DROP INDEX IX_HR_Departments_Company ON HR_Departments;

SELECT @sql = 'ALTER TABLE HR_Departments DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('HR_Departments')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('HR_Departments') AND name = 'Company');
IF @sql IS NOT NULL EXEC sp_executesql @sql;

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('HR_Departments') AND name = 'Company')
    ALTER TABLE HR_Departments DROP COLUMN Company;

-- HR_Positions
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HR_Positions_Company' AND object_id = OBJECT_ID('HR_Positions'))
    DROP INDEX IX_HR_Positions_Company ON HR_Positions;

SELECT @sql = 'ALTER TABLE HR_Positions DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('HR_Positions')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('HR_Positions') AND name = 'Company');
IF @sql IS NOT NULL EXEC sp_executesql @sql;

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('HR_Positions') AND name = 'Company')
    ALTER TABLE HR_Positions DROP COLUMN Company;

-- HR_Locations
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HR_Locations_Company' AND object_id = OBJECT_ID('HR_Locations'))
    DROP INDEX IX_HR_Locations_Company ON HR_Locations;

SELECT @sql = 'ALTER TABLE HR_Locations DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('HR_Locations')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('HR_Locations') AND name = 'Company');
IF @sql IS NOT NULL EXEC sp_executesql @sql;

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('HR_Locations') AND name = 'Company')
    ALTER TABLE HR_Locations DROP COLUMN Company;

-- HR_Performance
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_HR_Performance_Company' AND object_id = OBJECT_ID('HR_Performance'))
    DROP INDEX IX_HR_Performance_Company ON HR_Performance;

SELECT @sql = 'ALTER TABLE HR_Performance DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('HR_Performance')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('HR_Performance') AND name = 'Company');
IF @sql IS NOT NULL EXEC sp_executesql @sql;

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('HR_Performance') AND name = 'Company')
    ALTER TABLE HR_Performance DROP COLUMN Company;

-- Payroll_Salaries
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payroll_Salaries_Company' AND object_id = OBJECT_ID('Payroll_Salaries'))
    DROP INDEX IX_Payroll_Salaries_Company ON Payroll_Salaries;

SELECT @sql = 'ALTER TABLE Payroll_Salaries DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('Payroll_Salaries')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('Payroll_Salaries') AND name = 'Company');
IF @sql IS NOT NULL EXEC sp_executesql @sql;

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Payroll_Salaries') AND name = 'Company')
    ALTER TABLE Payroll_Salaries DROP COLUMN Company;

-- Payroll_Bonuses
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payroll_Bonuses_Company' AND object_id = OBJECT_ID('Payroll_Bonuses'))
    DROP INDEX IX_Payroll_Bonuses_Company ON Payroll_Bonuses;

SELECT @sql = 'ALTER TABLE Payroll_Bonuses DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('Payroll_Bonuses')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('Payroll_Bonuses') AND name = 'Company');
IF @sql IS NOT NULL EXEC sp_executesql @sql;

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Payroll_Bonuses') AND name = 'Company')
    ALTER TABLE Payroll_Bonuses DROP COLUMN Company;

-- Payroll_Deductions
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payroll_Deductions_Company' AND object_id = OBJECT_ID('Payroll_Deductions'))
    DROP INDEX IX_Payroll_Deductions_Company ON Payroll_Deductions;

SELECT @sql = 'ALTER TABLE Payroll_Deductions DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('Payroll_Deductions')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('Payroll_Deductions') AND name = 'Company');
IF @sql IS NOT NULL EXEC sp_executesql @sql;

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Payroll_Deductions') AND name = 'Company')
    ALTER TABLE Payroll_Deductions DROP COLUMN Company;

-- Payroll_Benefits
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payroll_Benefits_Company' AND object_id = OBJECT_ID('Payroll_Benefits'))
    DROP INDEX IX_Payroll_Benefits_Company ON Payroll_Benefits;

SELECT @sql = 'ALTER TABLE Payroll_Benefits DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('Payroll_Benefits')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('Payroll_Benefits') AND name = 'Company');
IF @sql IS NOT NULL EXEC sp_executesql @sql;

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Payroll_Benefits') AND name = 'Company')
    ALTER TABLE Payroll_Benefits DROP COLUMN Company;

-- Payroll_Timesheets
IF EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Payroll_Timesheets_Company' AND object_id = OBJECT_ID('Payroll_Timesheets'))
    DROP INDEX IX_Payroll_Timesheets_Company ON Payroll_Timesheets;

SELECT @sql = 'ALTER TABLE Payroll_Timesheets DROP CONSTRAINT ' + name
FROM sys.default_constraints
WHERE parent_object_id = OBJECT_ID('Payroll_Timesheets')
  AND parent_column_id = (SELECT column_id FROM sys.columns WHERE object_id = OBJECT_ID('Payroll_Timesheets') AND name = 'Company');
IF @sql IS NOT NULL EXEC sp_executesql @sql;

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('Payroll_Timesheets') AND name = 'Company')
    ALTER TABLE Payroll_Timesheets DROP COLUMN Company;

PRINT 'Company column and indexes dropped from all 10 tables';
PRINT 'Pipeline can now load data without Company column mapping issues!';
