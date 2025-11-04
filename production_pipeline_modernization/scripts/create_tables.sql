-- Create Employees table
CREATE TABLE Employees (
    EmployeeID NVARCHAR(10) PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Email NVARCHAR(100),
    Department NVARCHAR(50),
    HireDate DATE,
    Salary DECIMAL(10,2)
);

-- Create Payroll table
CREATE TABLE Payroll (
    PayrollID NVARCHAR(10) PRIMARY KEY,
    EmployeeID NVARCHAR(10),
    PayPeriod NVARCHAR(10),
    GrossPay DECIMAL(10,2),
    Deductions DECIMAL(10,2),
    NetPay DECIMAL(10,2),
    PaymentDate DATE,
    FOREIGN KEY (EmployeeID) REFERENCES Employees(EmployeeID)
);
