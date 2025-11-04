-- Verify data loaded successfully into all tables

USE HRPayrollDB;
GO

PRINT '============================================';
PRINT 'Data Load Verification Report';
PRINT '============================================';
PRINT '';

-- HR Tables
PRINT 'HR Tables:';
PRINT '-----------';

DECLARE @EmployeeCount INT, @DepartmentCount INT, @PositionCount INT, @LocationCount INT, @PerformanceCount INT;
DECLARE @SalaryCount INT, @BonusCount INT, @DeductionCount INT, @BenefitCount INT, @TimesheetCount INT;

SELECT @EmployeeCount = COUNT(*) FROM HR_Employees;
SELECT @DepartmentCount = COUNT(*) FROM HR_Departments;
SELECT @PositionCount = COUNT(*) FROM HR_Positions;
SELECT @LocationCount = COUNT(*) FROM HR_Locations;
SELECT @PerformanceCount = COUNT(*) FROM HR_Performance;

PRINT 'HR_Employees: ' + CAST(@EmployeeCount AS VARCHAR(10)) + ' rows';
PRINT 'HR_Departments: ' + CAST(@DepartmentCount AS VARCHAR(10)) + ' rows';
PRINT 'HR_Positions: ' + CAST(@PositionCount AS VARCHAR(10)) + ' rows';
PRINT 'HR_Locations: ' + CAST(@LocationCount AS VARCHAR(10)) + ' rows';
PRINT 'HR_Performance: ' + CAST(@PerformanceCount AS VARCHAR(10)) + ' rows';

PRINT '';
PRINT 'Payroll Tables:';
PRINT '---------------';

SELECT @SalaryCount = COUNT(*) FROM Payroll_Salaries;
SELECT @BonusCount = COUNT(*) FROM Payroll_Bonuses;
SELECT @DeductionCount = COUNT(*) FROM Payroll_Deductions;
SELECT @BenefitCount = COUNT(*) FROM Payroll_Benefits;
SELECT @TimesheetCount = COUNT(*) FROM Payroll_Timesheets;

PRINT 'Payroll_Salaries: ' + CAST(@SalaryCount AS VARCHAR(10)) + ' rows';
PRINT 'Payroll_Bonuses: ' + CAST(@BonusCount AS VARCHAR(10)) + ' rows';
PRINT 'Payroll_Deductions: ' + CAST(@DeductionCount AS VARCHAR(10)) + ' rows';
PRINT 'Payroll_Benefits: ' + CAST(@BenefitCount AS VARCHAR(10)) + ' rows';
PRINT 'Payroll_Timesheets: ' + CAST(@TimesheetCount AS VARCHAR(10)) + ' rows';

PRINT '';
PRINT 'Total rows loaded: ' + CAST(@EmployeeCount + @DepartmentCount + @PositionCount + @LocationCount + @PerformanceCount + @SalaryCount + @BonusCount + @DeductionCount + @BenefitCount + @TimesheetCount AS VARCHAR(10));

PRINT '';
PRINT '============================================';
PRINT 'Sample Data from Each Table:';
PRINT '============================================';

-- Sample from HR_Employees
PRINT '';
PRINT 'HR_Employees (first 3 rows):';
SELECT TOP 3 * FROM HR_Employees ORDER BY EmployeeID;

-- Sample from Payroll_Salaries
PRINT '';
PRINT 'Payroll_Salaries (first 3 rows):';
SELECT TOP 3 * FROM Payroll_Salaries ORDER BY PayrollID;

PRINT '';
PRINT 'Verification complete!';
