-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Silver to Gold: Business Analytics Layer
-- MAGIC
-- MAGIC **Purpose**: Create business-ready, aggregated views and enriched datasets in the Gold layer for reporting and analytics
-- MAGIC
-- MAGIC **Data Flow**:
-- MAGIC - Source: silver/{pod_id}/hr/employees + silver/{pod_id}/payroll/payments
-- MAGIC - Target: gold/{pod_id}/analytics/* (multiple analytical tables)
-- MAGIC
-- MAGIC **Gold Layer Tables Created**:
-- MAGIC 1. `employee_payroll_summary` - Employee master with total compensation metrics
-- MAGIC 2. `department_payroll_analytics` - Department-level payroll aggregations
-- MAGIC 3. `monthly_payroll_trends` - Time-series payroll metrics by month
-- MAGIC 4. `payment_method_analysis` - Payment method distribution and analytics
-- MAGIC
-- MAGIC **Dependencies**: HR Silver and Payroll Silver tables must exist and contain data

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. Setup Parameters

-- COMMAND ----------

-- Create widgets for runtime parameters
CREATE WIDGET TEXT pod_id DEFAULT "podA";

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. Configuration Variables

-- COMMAND ----------

-- Set configuration variables
DECLARE storage_account STRING DEFAULT 'stdldevshared77b5h3';
DECLARE pod STRING DEFAULT getArgument('pod_id');
DECLARE hr_silver_path STRING DEFAULT concat('abfss://silver@', storage_account, '.dfs.core.windows.net/', pod, '/hr/employees');
DECLARE payroll_silver_path STRING DEFAULT concat('abfss://silver@', storage_account, '.dfs.core.windows.net/', pod, '/payroll/payments');
DECLARE gold_path STRING DEFAULT concat('abfss://gold@', storage_account, '.dfs.core.windows.net/', pod, '/analytics');

SELECT
  storage_account AS storage_account,
  pod AS pod_id,
  hr_silver_path AS hr_source,
  payroll_silver_path AS payroll_source,
  gold_path AS gold_target;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Verify Silver Tables Exist (Dependency Check)

-- COMMAND ----------

-- Check if both Silver tables exist and have data
SELECT 'Silver Data Dependency Check' AS step;

SELECT
  'HR Employees' AS table_name,
  COUNT(*) AS record_count,
  CASE
    WHEN COUNT(*) > 0 THEN 'PASS'
    ELSE 'FAIL - Run 01_bronze_to_silver_hr first'
  END AS status
FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees`
WHERE pod_id = getArgument('pod_id')

UNION ALL

SELECT
  'Payroll Payments' AS table_name,
  COUNT(*) AS record_count,
  CASE
    WHEN COUNT(*) > 0 THEN 'PASS'
    ELSE 'FAIL - Run 02_bronze_to_silver_payroll first'
  END AS status
FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/payroll/payments`
WHERE pod_id = getArgument('pod_id');

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 4. Gold Table 1: Employee Payroll Summary
-- MAGIC
-- MAGIC **Purpose**: Complete employee profile with aggregated compensation metrics
-- MAGIC
-- MAGIC **Business Use Cases**:
-- MAGIC - Employee compensation reports
-- MAGIC - Year-to-date payroll summaries
-- MAGIC - Total compensation analysis

-- COMMAND ----------

-- Create enriched employee payroll summary
CREATE OR REPLACE TEMPORARY VIEW gold_employee_payroll_summary AS
SELECT
  -- Employee Identifiers
  e.employee_id,
  e.first_name,
  e.last_name,
  e.email,

  -- Employment Details
  e.department,
  e.job_title,
  e.employment_status,
  e.hire_date,
  e.office_location,

  -- Annual Salary
  e.salary AS annual_salary,

  -- Manager Information
  e.manager_id,
  CONCAT(m.first_name, ' ', m.last_name) AS manager_name,

  -- Payroll Metrics (YTD - Year to Date)
  COUNT(DISTINCT p.payment_id) AS total_payments,
  MIN(p.payment_date) AS first_payment_date,
  MAX(p.payment_date) AS last_payment_date,

  -- Financial Aggregations
  SUM(p.gross_pay) AS ytd_gross_pay,
  SUM(p.tax_withheld) AS ytd_tax_withheld,
  SUM(p.deductions) AS ytd_deductions,
  SUM(p.net_pay) AS ytd_net_pay,

  -- Average Per Payment
  ROUND(AVG(p.gross_pay), 2) AS avg_gross_pay_per_payment,
  ROUND(AVG(p.net_pay), 2) AS avg_net_pay_per_payment,

  -- Tax Rate Analysis
  ROUND(
    CASE
      WHEN SUM(p.gross_pay) > 0 THEN (SUM(p.tax_withheld) / SUM(p.gross_pay)) * 100
      ELSE 0
    END,
    2
  ) AS effective_tax_rate_pct,

  -- Deduction Rate Analysis
  ROUND(
    CASE
      WHEN SUM(p.gross_pay) > 0 THEN (SUM(p.deductions) / SUM(p.gross_pay)) * 100
      ELSE 0
    END,
    2
  ) AS deduction_rate_pct,

  -- Payment Method (most frequent)
  FIRST(p.payment_method) AS primary_payment_method,

  -- Metadata
  CURRENT_TIMESTAMP() AS gold_processed_timestamp,
  getArgument('pod_id') AS pod_id

FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees` e

-- Left join to include employees without payroll records
LEFT JOIN delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/payroll/payments` p
  ON e.employee_id = p.employee_id
  AND e.pod_id = p.pod_id

-- Self-join to get manager names
LEFT JOIN delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees` m
  ON e.manager_id = m.employee_id
  AND e.pod_id = m.pod_id

WHERE e.pod_id = getArgument('pod_id')

GROUP BY
  e.employee_id,
  e.first_name,
  e.last_name,
  e.email,
  e.department,
  e.job_title,
  e.employment_status,
  e.hire_date,
  e.office_location,
  e.salary,
  e.manager_id,
  m.first_name,
  m.last_name;

-- Show sample
SELECT 'Gold - Employee Payroll Summary Sample' AS step;
SELECT * FROM gold_employee_payroll_summary LIMIT 10;

-- COMMAND ----------

-- Create/Replace Gold Delta Table
CREATE TABLE IF NOT EXISTS delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/employee_payroll_summary` (
  employee_id INT NOT NULL,
  first_name STRING NOT NULL,
  last_name STRING NOT NULL,
  email STRING NOT NULL,
  department STRING,
  job_title STRING,
  employment_status STRING,
  hire_date DATE NOT NULL,
  office_location STRING,
  annual_salary DECIMAL(10,2) NOT NULL,
  manager_id INT,
  manager_name STRING,
  total_payments INT,
  first_payment_date DATE,
  last_payment_date DATE,
  ytd_gross_pay DECIMAL(12,2),
  ytd_tax_withheld DECIMAL(12,2),
  ytd_deductions DECIMAL(12,2),
  ytd_net_pay DECIMAL(12,2),
  avg_gross_pay_per_payment DECIMAL(10,2),
  avg_net_pay_per_payment DECIMAL(10,2),
  effective_tax_rate_pct DECIMAL(5,2),
  deduction_rate_pct DECIMAL(5,2),
  primary_payment_method STRING,
  gold_processed_timestamp TIMESTAMP NOT NULL,
  pod_id STRING NOT NULL
)
USING DELTA
PARTITIONED BY (pod_id)
LOCATION 'abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/employee_payroll_summary';

-- Merge data into Gold table
MERGE INTO delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/employee_payroll_summary` AS target
USING gold_employee_payroll_summary AS source
ON target.employee_id = source.employee_id AND target.pod_id = source.pod_id

WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 5. Gold Table 2: Department Payroll Analytics
-- MAGIC
-- MAGIC **Purpose**: Department-level payroll aggregations and cost analysis
-- MAGIC
-- MAGIC **Business Use Cases**:
-- MAGIC - Department budget tracking
-- MAGIC - Cost center analysis
-- MAGIC - Headcount reporting

-- COMMAND ----------

-- Create department payroll analytics
CREATE OR REPLACE TEMPORARY VIEW gold_department_payroll_analytics AS
SELECT
  -- Department Information
  e.department,
  e.office_location,

  -- Headcount Metrics
  COUNT(DISTINCT e.employee_id) AS total_employees,
  COUNT(DISTINCT CASE WHEN e.employment_status = 'Active' THEN e.employee_id END) AS active_employees,
  COUNT(DISTINCT CASE WHEN e.employment_status = 'On Leave' THEN e.employee_id END) AS on_leave_employees,
  COUNT(DISTINCT CASE WHEN e.employment_status = 'Terminated' THEN e.employee_id END) AS terminated_employees,

  -- Salary Metrics (Annual Base Salary)
  SUM(e.salary) AS total_annual_salaries,
  ROUND(AVG(e.salary), 2) AS avg_annual_salary,
  MIN(e.salary) AS min_annual_salary,
  MAX(e.salary) AS max_annual_salary,

  -- Payroll Payment Metrics (Actual Paid Amounts)
  COUNT(p.payment_id) AS total_payments,
  SUM(p.gross_pay) AS ytd_total_gross_pay,
  SUM(p.tax_withheld) AS ytd_total_tax_withheld,
  SUM(p.deductions) AS ytd_total_deductions,
  SUM(p.net_pay) AS ytd_total_net_pay,

  -- Per-Employee Averages
  ROUND(SUM(p.gross_pay) / COUNT(DISTINCT e.employee_id), 2) AS ytd_avg_gross_per_employee,
  ROUND(SUM(p.net_pay) / COUNT(DISTINCT e.employee_id), 2) AS ytd_avg_net_per_employee,

  -- Department Tax Rate
  ROUND(
    CASE
      WHEN SUM(p.gross_pay) > 0 THEN (SUM(p.tax_withheld) / SUM(p.gross_pay)) * 100
      ELSE 0
    END,
    2
  ) AS dept_effective_tax_rate_pct,

  -- Tenure Analysis
  ROUND(AVG(DATEDIFF(CURRENT_DATE(), e.hire_date) / 365.25), 2) AS avg_tenure_years,

  -- Metadata
  CURRENT_TIMESTAMP() AS gold_processed_timestamp,
  getArgument('pod_id') AS pod_id

FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees` e

LEFT JOIN delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/payroll/payments` p
  ON e.employee_id = p.employee_id
  AND e.pod_id = p.pod_id

WHERE e.pod_id = getArgument('pod_id')

GROUP BY
  e.department,
  e.office_location;

-- Show sample
SELECT 'Gold - Department Payroll Analytics Sample' AS step;
SELECT * FROM gold_department_payroll_analytics ORDER BY ytd_total_gross_pay DESC;

-- COMMAND ----------

-- Create/Replace Gold Delta Table
CREATE TABLE IF NOT EXISTS delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/department_payroll_analytics` (
  department STRING,
  office_location STRING,
  total_employees INT,
  active_employees INT,
  on_leave_employees INT,
  terminated_employees INT,
  total_annual_salaries DECIMAL(15,2),
  avg_annual_salary DECIMAL(10,2),
  min_annual_salary DECIMAL(10,2),
  max_annual_salary DECIMAL(10,2),
  total_payments INT,
  ytd_total_gross_pay DECIMAL(15,2),
  ytd_total_tax_withheld DECIMAL(15,2),
  ytd_total_deductions DECIMAL(15,2),
  ytd_total_net_pay DECIMAL(15,2),
  ytd_avg_gross_per_employee DECIMAL(10,2),
  ytd_avg_net_per_employee DECIMAL(10,2),
  dept_effective_tax_rate_pct DECIMAL(5,2),
  avg_tenure_years DECIMAL(5,2),
  gold_processed_timestamp TIMESTAMP NOT NULL,
  pod_id STRING NOT NULL
)
USING DELTA
PARTITIONED BY (pod_id)
LOCATION 'abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/department_payroll_analytics';

-- Merge data into Gold table
MERGE INTO delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/department_payroll_analytics` AS target
USING gold_department_payroll_analytics AS source
ON target.department = source.department
   AND target.office_location = source.office_location
   AND target.pod_id = source.pod_id

WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 6. Gold Table 3: Monthly Payroll Trends
-- MAGIC
-- MAGIC **Purpose**: Time-series analysis of payroll metrics by month
-- MAGIC
-- MAGIC **Business Use Cases**:
-- MAGIC - Monthly payroll reports
-- MAGIC - Trend analysis and forecasting
-- MAGIC - Budget variance tracking

-- COMMAND ----------

-- Create monthly payroll trends
CREATE OR REPLACE TEMPORARY VIEW gold_monthly_payroll_trends AS
SELECT
  -- Time Dimensions
  YEAR(p.payment_date) AS payment_year,
  MONTH(p.payment_date) AS payment_month,
  DATE_TRUNC('MONTH', p.payment_date) AS payment_month_start,

  -- Payment Counts
  COUNT(DISTINCT p.payment_id) AS total_payments,
  COUNT(DISTINCT p.employee_id) AS unique_employees_paid,

  -- Financial Aggregations
  SUM(p.gross_pay) AS total_gross_pay,
  SUM(p.tax_withheld) AS total_tax_withheld,
  SUM(p.deductions) AS total_deductions,
  SUM(p.net_pay) AS total_net_pay,

  -- Averages
  ROUND(AVG(p.gross_pay), 2) AS avg_gross_pay_per_payment,
  ROUND(AVG(p.net_pay), 2) AS avg_net_pay_per_payment,

  -- Tax Analysis
  ROUND(
    CASE
      WHEN SUM(p.gross_pay) > 0 THEN (SUM(p.tax_withheld) / SUM(p.gross_pay)) * 100
      ELSE 0
    END,
    2
  ) AS effective_tax_rate_pct,

  -- Payment Method Distribution
  COUNT(DISTINCT CASE WHEN p.payment_method = 'Direct Deposit' THEN p.payment_id END) AS direct_deposit_count,
  COUNT(DISTINCT CASE WHEN p.payment_method = 'Check' THEN p.payment_id END) AS check_count,

  -- Department Breakdown (top 3 departments by payment count)
  ARRAY_AGG(
    STRUCT(e.department, COUNT(p.payment_id) AS payment_count)
    ORDER BY COUNT(p.payment_id) DESC
    LIMIT 3
  ) AS top_departments,

  -- Metadata
  CURRENT_TIMESTAMP() AS gold_processed_timestamp,
  getArgument('pod_id') AS pod_id

FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/payroll/payments` p

INNER JOIN delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees` e
  ON p.employee_id = e.employee_id
  AND p.pod_id = e.pod_id

WHERE p.pod_id = getArgument('pod_id')

GROUP BY
  YEAR(p.payment_date),
  MONTH(p.payment_date),
  DATE_TRUNC('MONTH', p.payment_date);

-- Show sample
SELECT 'Gold - Monthly Payroll Trends Sample' AS step;
SELECT
  payment_year,
  payment_month,
  payment_month_start,
  total_payments,
  unique_employees_paid,
  total_gross_pay,
  total_net_pay,
  avg_gross_pay_per_payment,
  effective_tax_rate_pct
FROM gold_monthly_payroll_trends
ORDER BY payment_year DESC, payment_month DESC;

-- COMMAND ----------

-- Create/Replace Gold Delta Table
CREATE TABLE IF NOT EXISTS delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/monthly_payroll_trends` (
  payment_year INT NOT NULL,
  payment_month INT NOT NULL,
  payment_month_start DATE NOT NULL,
  total_payments INT,
  unique_employees_paid INT,
  total_gross_pay DECIMAL(15,2),
  total_tax_withheld DECIMAL(15,2),
  total_deductions DECIMAL(15,2),
  total_net_pay DECIMAL(15,2),
  avg_gross_pay_per_payment DECIMAL(10,2),
  avg_net_pay_per_payment DECIMAL(10,2),
  effective_tax_rate_pct DECIMAL(5,2),
  direct_deposit_count INT,
  check_count INT,
  top_departments ARRAY<STRUCT<department:STRING, payment_count:BIGINT>>,
  gold_processed_timestamp TIMESTAMP NOT NULL,
  pod_id STRING NOT NULL
)
USING DELTA
PARTITIONED BY (pod_id)
LOCATION 'abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/monthly_payroll_trends';

-- Merge data into Gold table
MERGE INTO delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/monthly_payroll_trends` AS target
USING gold_monthly_payroll_trends AS source
ON target.payment_year = source.payment_year
   AND target.payment_month = source.payment_month
   AND target.pod_id = source.pod_id

WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 7. Gold Table 4: Payment Method Analysis
-- MAGIC
-- MAGIC **Purpose**: Analysis of payment method distribution and trends
-- MAGIC
-- MAGIC **Business Use Cases**:
-- MAGIC - Payment processing cost analysis
-- MAGIC - Direct deposit adoption tracking
-- MAGIC - Payment method optimization

-- COMMAND ----------

-- Create payment method analysis
CREATE OR REPLACE TEMPORARY VIEW gold_payment_method_analysis AS
SELECT
  -- Payment Method
  p.payment_method,

  -- Volume Metrics
  COUNT(DISTINCT p.payment_id) AS total_payments,
  COUNT(DISTINCT p.employee_id) AS unique_employees,

  -- Financial Metrics
  SUM(p.gross_pay) AS total_gross_pay,
  SUM(p.net_pay) AS total_net_pay,
  ROUND(AVG(p.gross_pay), 2) AS avg_gross_pay,
  ROUND(AVG(p.net_pay), 2) AS avg_net_pay,

  -- Distribution Percentages
  ROUND(
    COUNT(p.payment_id) * 100.0 / SUM(COUNT(p.payment_id)) OVER (),
    2
  ) AS payment_volume_pct,

  ROUND(
    SUM(p.gross_pay) * 100.0 / SUM(SUM(p.gross_pay)) OVER (),
    2
  ) AS payment_value_pct,

  -- Department Distribution
  COUNT(DISTINCT e.department) AS departments_using_method,

  -- Date Range
  MIN(p.payment_date) AS first_payment_date,
  MAX(p.payment_date) AS last_payment_date,

  -- Metadata
  CURRENT_TIMESTAMP() AS gold_processed_timestamp,
  getArgument('pod_id') AS pod_id

FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/payroll/payments` p

INNER JOIN delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees` e
  ON p.employee_id = e.employee_id
  AND p.pod_id = e.pod_id

WHERE p.pod_id = getArgument('pod_id')

GROUP BY p.payment_method;

-- Show sample
SELECT 'Gold - Payment Method Analysis Sample' AS step;
SELECT * FROM gold_payment_method_analysis ORDER BY total_payments DESC;

-- COMMAND ----------

-- Create/Replace Gold Delta Table
CREATE TABLE IF NOT EXISTS delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/payment_method_analysis` (
  payment_method STRING NOT NULL,
  total_payments INT,
  unique_employees INT,
  total_gross_pay DECIMAL(15,2),
  total_net_pay DECIMAL(15,2),
  avg_gross_pay DECIMAL(10,2),
  avg_net_pay DECIMAL(10,2),
  payment_volume_pct DECIMAL(5,2),
  payment_value_pct DECIMAL(5,2),
  departments_using_method INT,
  first_payment_date DATE,
  last_payment_date DATE,
  gold_processed_timestamp TIMESTAMP NOT NULL,
  pod_id STRING NOT NULL
)
USING DELTA
PARTITIONED BY (pod_id)
LOCATION 'abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/payment_method_analysis';

-- Merge data into Gold table
MERGE INTO delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/payment_method_analysis` AS target
USING gold_payment_method_analysis AS source
ON target.payment_method = source.payment_method AND target.pod_id = source.pod_id

WHEN MATCHED THEN UPDATE SET *
WHEN NOT MATCHED THEN INSERT *;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 8. Optimize All Gold Tables

-- COMMAND ----------

-- Optimize all Gold tables for query performance
OPTIMIZE delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/employee_payroll_summary`
WHERE pod_id = getArgument('pod_id');

OPTIMIZE delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/department_payroll_analytics`
WHERE pod_id = getArgument('pod_id');

OPTIMIZE delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/monthly_payroll_trends`
WHERE pod_id = getArgument('pod_id');

OPTIMIZE delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/payment_method_analysis`
WHERE pod_id = getArgument('pod_id');

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 9. Generate Final Processing Summary

-- COMMAND ----------

-- Final summary of all Gold tables created
SELECT 'Gold Layer Processing Complete' AS status;

SELECT
  'employee_payroll_summary' AS gold_table,
  COUNT(*) AS record_count
FROM delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/employee_payroll_summary`
WHERE pod_id = getArgument('pod_id')

UNION ALL

SELECT
  'department_payroll_analytics' AS gold_table,
  COUNT(*) AS record_count
FROM delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/department_payroll_analytics`
WHERE pod_id = getArgument('pod_id')

UNION ALL

SELECT
  'monthly_payroll_trends' AS gold_table,
  COUNT(*) AS record_count
FROM delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/monthly_payroll_trends`
WHERE pod_id = getArgument('pod_id')

UNION ALL

SELECT
  'payment_method_analysis' AS gold_table,
  COUNT(*) AS record_count
FROM delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/payment_method_analysis`
WHERE pod_id = getArgument('pod_id');

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 10. Sample Analytical Queries for Business Users

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Query 1: Top 10 Highest Paid Employees

-- COMMAND ----------

SELECT
  employee_id,
  first_name,
  last_name,
  department,
  job_title,
  annual_salary,
  ytd_gross_pay,
  ytd_net_pay,
  effective_tax_rate_pct
FROM delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/employee_payroll_summary`
WHERE pod_id = getArgument('pod_id')
  AND employment_status = 'Active'
ORDER BY ytd_gross_pay DESC
LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Query 2: Department Payroll Cost Ranking

-- COMMAND ----------

SELECT
  department,
  office_location,
  active_employees,
  ytd_total_gross_pay,
  ytd_avg_gross_per_employee,
  dept_effective_tax_rate_pct,
  avg_tenure_years
FROM delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/department_payroll_analytics`
WHERE pod_id = getArgument('pod_id')
ORDER BY ytd_total_gross_pay DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Query 3: Payroll Trend Over Time

-- COMMAND ----------

SELECT
  payment_month_start,
  unique_employees_paid,
  total_gross_pay,
  total_net_pay,
  avg_gross_pay_per_payment,
  effective_tax_rate_pct,
  direct_deposit_count,
  check_count
FROM delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/monthly_payroll_trends`
WHERE pod_id = getArgument('pod_id')
ORDER BY payment_month_start DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Query 4: Employees Without Recent Payroll Activity

-- COMMAND ----------

SELECT
  employee_id,
  first_name,
  last_name,
  department,
  employment_status,
  hire_date,
  annual_salary,
  total_payments,
  last_payment_date
FROM delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/podA/analytics/employee_payroll_summary`
WHERE pod_id = getArgument('pod_id')
  AND employment_status = 'Active'
  AND (total_payments IS NULL OR total_payments = 0)
ORDER BY hire_date DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ---
-- MAGIC **Notebook Complete**: Business-ready Gold layer tables created successfully.
-- MAGIC
-- MAGIC **Gold Tables Available**:
-- MAGIC - `employee_payroll_summary` - Complete employee compensation profiles
-- MAGIC - `department_payroll_analytics` - Department-level cost analysis
-- MAGIC - `monthly_payroll_trends` - Time-series payroll metrics
-- MAGIC - `payment_method_analysis` - Payment distribution analysis
-- MAGIC
-- MAGIC **Next Steps**:
-- MAGIC - Connect Power BI or Tableau to Gold tables
-- MAGIC - Schedule automated refreshes via Data Factory
-- MAGIC - Create dashboards and reports for business users
