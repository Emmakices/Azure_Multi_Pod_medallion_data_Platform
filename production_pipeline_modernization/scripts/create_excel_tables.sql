-- ============================================
-- Create Tables for Excel Multi-Sheet Data
-- ============================================
-- This script creates 10 tables for the Excel sheets:
-- HR Data: Employees, Departments, Positions, Locations, Performance
-- Payroll Data: Salaries, Bonuses, Deductions, Benefits, Timesheets
-- ============================================

-- Drop existing tables if they exist (for clean rebuild)
IF OBJECT_ID('dbo.HR_Performance', 'U') IS NOT NULL DROP TABLE dbo.HR_Performance;
IF OBJECT_ID('dbo.HR_Positions', 'U') IS NOT NULL DROP TABLE dbo.HR_Positions;
IF OBJECT_ID('dbo.HR_Employees', 'U') IS NOT NULL DROP TABLE dbo.HR_Employees;
IF OBJECT_ID('dbo.HR_Departments', 'U') IS NOT NULL DROP TABLE dbo.HR_Departments;
IF OBJECT_ID('dbo.HR_Locations', 'U') IS NOT NULL DROP TABLE dbo.HR_Locations;

IF OBJECT_ID('dbo.Payroll_Timesheets', 'U') IS NOT NULL DROP TABLE dbo.Payroll_Timesheets;
IF OBJECT_ID('dbo.Payroll_Benefits', 'U') IS NOT NULL DROP TABLE dbo.Payroll_Benefits;
IF OBJECT_ID('dbo.Payroll_Deductions', 'U') IS NOT NULL DROP TABLE dbo.Payroll_Deductions;
IF OBJECT_ID('dbo.Payroll_Bonuses', 'U') IS NOT NULL DROP TABLE dbo.Payroll_Bonuses;
IF OBJECT_ID('dbo.Payroll_Salaries', 'U') IS NOT NULL DROP TABLE dbo.Payroll_Salaries;

-- Also drop old tables if they exist
IF OBJECT_ID('dbo.Employees', 'U') IS NOT NULL DROP TABLE dbo.Employees;
IF OBJECT_ID('dbo.Payroll', 'U') IS NOT NULL DROP TABLE dbo.Payroll;

GO

-- ============================================
-- HR TABLES (from hr_data.xlsx)
-- ============================================

-- Table 1: HR_Employees
CREATE TABLE dbo.HR_Employees (
    EmployeeID NVARCHAR(10) PRIMARY KEY,
    FirstName NVARCHAR(50) NOT NULL,
    LastName NVARCHAR(50) NOT NULL,
    Email NVARCHAR(100) NOT NULL,
    Department NVARCHAR(50),
    HireDate DATE,
    Salary DECIMAL(10,2),
    CreatedDate DATETIME2 DEFAULT GETDATE()
);

-- Table 2: HR_Departments
CREATE TABLE dbo.HR_Departments (
    DepartmentID NVARCHAR(10) PRIMARY KEY,
    DepartmentName NVARCHAR(100) NOT NULL,
    ManagerID NVARCHAR(10),
    Location NVARCHAR(100),
    Budget DECIMAL(12,2),
    CreatedDate DATETIME2 DEFAULT GETDATE()
);

-- Table 3: HR_Positions
CREATE TABLE dbo.HR_Positions (
    PositionID NVARCHAR(10) PRIMARY KEY,
    PositionTitle NVARCHAR(100) NOT NULL,
    DepartmentID NVARCHAR(10),
    MinSalary DECIMAL(10,2),
    MaxSalary DECIMAL(10,2),
    CreatedDate DATETIME2 DEFAULT GETDATE()
);

-- Table 4: HR_Locations
CREATE TABLE dbo.HR_Locations (
    LocationID NVARCHAR(10) PRIMARY KEY,
    BuildingName NVARCHAR(100) NOT NULL,
    Address NVARCHAR(255),
    City NVARCHAR(100),
    State NVARCHAR(50),
    ZipCode NVARCHAR(20),
    Capacity INT,
    CreatedDate DATETIME2 DEFAULT GETDATE()
);

-- Table 5: HR_Performance
CREATE TABLE dbo.HR_Performance (
    ReviewID NVARCHAR(10) PRIMARY KEY,
    EmployeeID NVARCHAR(10),
    ReviewDate DATE,
    Rating DECIMAL(3,2),
    Reviewer NVARCHAR(10),
    Comments NVARCHAR(500),
    CreatedDate DATETIME2 DEFAULT GETDATE()
);

GO

-- ============================================
-- PAYROLL TABLES (from payroll_data.xlsx)
-- ============================================

-- Table 6: Payroll_Salaries
CREATE TABLE dbo.Payroll_Salaries (
    PayrollID NVARCHAR(10) PRIMARY KEY,
    EmployeeID NVARCHAR(10),
    PayPeriod NVARCHAR(10),
    GrossPay DECIMAL(10,2),
    Deductions DECIMAL(10,2),
    NetPay DECIMAL(10,2),
    PaymentDate DATE,
    CreatedDate DATETIME2 DEFAULT GETDATE()
);

-- Table 7: Payroll_Bonuses
CREATE TABLE dbo.Payroll_Bonuses (
    BonusID NVARCHAR(10) PRIMARY KEY,
    EmployeeID NVARCHAR(10),
    BonusType NVARCHAR(50),
    Amount DECIMAL(10,2),
    BonusDate DATE,
    Reason NVARCHAR(500),
    CreatedDate DATETIME2 DEFAULT GETDATE()
);

-- Table 8: Payroll_Deductions
CREATE TABLE dbo.Payroll_Deductions (
    DeductionID NVARCHAR(10) PRIMARY KEY,
    EmployeeID NVARCHAR(10),
    DeductionType NVARCHAR(50),
    Amount DECIMAL(10,2),
    DeductionDate DATE,
    CreatedDate DATETIME2 DEFAULT GETDATE()
);

-- Table 9: Payroll_Benefits
CREATE TABLE dbo.Payroll_Benefits (
    BenefitID NVARCHAR(10) PRIMARY KEY,
    EmployeeID NVARCHAR(10),
    BenefitType NVARCHAR(50),
    Provider NVARCHAR(100),
    MonthlyPremium DECIMAL(10,2),
    StartDate DATE,
    CreatedDate DATETIME2 DEFAULT GETDATE()
);

-- Table 10: Payroll_Timesheets
CREATE TABLE dbo.Payroll_Timesheets (
    TimesheetID NVARCHAR(10) PRIMARY KEY,
    EmployeeID NVARCHAR(10),
    WeekEnding DATE,
    RegularHours INT,
    OvertimeHours INT,
    TotalHours INT,
    CreatedDate DATETIME2 DEFAULT GETDATE()
);

GO

-- ============================================
-- Verify tables created
-- ============================================
SELECT
    TABLE_NAME as TableName,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = t.TABLE_NAME) as ColumnCount
FROM INFORMATION_SCHEMA.TABLES t
WHERE TABLE_SCHEMA = 'dbo'
    AND TABLE_TYPE = 'BASE TABLE'
    AND TABLE_NAME LIKE 'HR_%' OR TABLE_NAME LIKE 'Payroll_%'
ORDER BY TABLE_NAME;
