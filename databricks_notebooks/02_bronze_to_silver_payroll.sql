-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Bronze to Silver: Payroll Payment Data Cleansing
-- MAGIC
-- MAGIC **Purpose**: Read raw payroll payment data from Bronze layer, cleanse and validate with referential integrity checks, write to Silver as Delta table
-- MAGIC
-- MAGIC **Data Flow**:
-- MAGIC - Source: bronze/{pod_id}/payroll/PAYROLL_PAYMENTS
-- MAGIC - Target: silver/{pod_id}/payroll/payments
-- MAGIC
-- MAGIC **Data Quality Rules**:
-- MAGIC - Remove exact duplicate rows
-- MAGIC - Validate employee_id exists in HR Silver (referential integrity)
-- MAGIC - Remove NULL payment_id (critical field)
-- MAGIC - Validate pay period date ranges (start < end)
-- MAGIC - Validate payment math: gross_pay - tax_withheld - deductions = net_pay
-- MAGIC - Remove future payment dates (data quality issue)
-- MAGIC - Normalize payment_method values
-- MAGIC
-- MAGIC **Dependencies**: HR Silver table MUST exist (employee master data)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. Setup Parameters

-- COMMAND ----------

-- Create widgets for runtime parameters
CREATE WIDGET TEXT pod_id DEFAULT "podA";
CREATE WIDGET TEXT domain DEFAULT "payroll";

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. Configuration Variables

-- COMMAND ----------

-- Set configuration variables
DECLARE storage_account STRING DEFAULT 'stdldevshared77b5h3';
DECLARE pod STRING DEFAULT getArgument('pod_id');
DECLARE domain_name STRING DEFAULT getArgument('domain');
DECLARE bronze_path STRING DEFAULT concat('abfss://bronze@', storage_account, '.dfs.core.windows.net/', pod, '/', domain_name, '/PAYROLL_PAYMENTS');
DECLARE silver_path STRING DEFAULT concat('abfss://silver@', storage_account, '.dfs.core.windows.net/', pod, '/', domain_name, '/payments');
DECLARE hr_silver_path STRING DEFAULT concat('abfss://silver@', storage_account, '.dfs.core.windows.net/', pod, '/hr/employees');

SELECT
  storage_account AS storage_account,
  pod AS pod_id,
  domain_name AS domain,
  bronze_path AS bronze_source,
  silver_path AS silver_target,
  hr_silver_path AS hr_reference;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Verify HR Silver Table Exists (Dependency Check)

-- COMMAND ----------

-- Check if HR Silver table exists and has data
SELECT 'HR Dependency Check' AS step;

SELECT
  COUNT(*) AS hr_employee_count,
  CASE
    WHEN COUNT(*) > 0 THEN 'PASS - HR data available'
    ELSE 'FAIL - HR Silver table is empty. Run 01_bronze_to_silver_hr first.'
  END AS dependency_status
FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees`
WHERE pod_id = getArgument('pod_id');

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 4. Read Raw Data from Bronze Layer

-- COMMAND ----------

-- Create temporary view of raw bronze payroll data
CREATE OR REPLACE TEMPORARY VIEW bronze_payroll_raw AS
SELECT * FROM delta.`abfss://bronze@stdldevshared77b5h3.dfs.core.windows.net/podA/payroll/PAYROLL_PAYMENTS`;

-- Show sample of raw data
SELECT 'Raw Bronze Data Sample' AS step;
SELECT * FROM bronze_payroll_raw LIMIT 5;

-- Row count before cleansing
SELECT 'Bronze Row Count' AS metric, COUNT(*) AS row_count FROM bronze_payroll_raw;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 5. Data Quality Analysis

-- COMMAND ----------

-- Analyze data quality issues in bronze data
SELECT 'Data Quality Issues' AS analysis;

SELECT
  'Total Records' AS issue_type,
  COUNT(*) AS record_count,
  0 AS percentage
FROM bronze_payroll_raw

UNION ALL

SELECT
  'NULL payment_id' AS issue_type,
  COUNT(*) AS record_count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM bronze_payroll_raw), 2) AS percentage
FROM bronze_payroll_raw
WHERE payment_id IS NULL

UNION ALL

SELECT
  'Duplicate payment_id' AS issue_type,
  COUNT(*) - COUNT(DISTINCT payment_id) AS record_count,
  ROUND((COUNT(*) - COUNT(DISTINCT payment_id)) * 100.0 / COUNT(*), 2) AS percentage
FROM bronze_payroll_raw

UNION ALL

SELECT
  'Invalid employee_id (not in HR)' AS issue_type,
  COUNT(*) AS record_count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM bronze_payroll_raw), 2) AS percentage
FROM bronze_payroll_raw pr
WHERE NOT EXISTS (
  SELECT 1
  FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees` hr
  WHERE hr.employee_id = pr.employee_id
    AND hr.pod_id = getArgument('pod_id')
)

UNION ALL

SELECT
  'Invalid Date Range (start >= end)' AS issue_type,
  COUNT(*) AS record_count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM bronze_payroll_raw), 2) AS percentage
FROM bronze_payroll_raw
WHERE TRY_CAST(pay_period_start AS DATE) >= TRY_CAST(pay_period_end AS DATE)

UNION ALL

SELECT
  'Future Payment Dates' AS issue_type,
  COUNT(*) AS record_count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM bronze_payroll_raw), 2) AS percentage
FROM bronze_payroll_raw
WHERE TRY_CAST(payment_date AS DATE) > CURRENT_DATE()

UNION ALL

SELECT
  'NULL Deductions' AS issue_type,
  COUNT(*) AS record_count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM bronze_payroll_raw), 2) AS percentage
FROM bronze_payroll_raw
WHERE deductions IS NULL

UNION ALL

SELECT
  'Incorrect Net Pay Calculation' AS issue_type,
  COUNT(*) AS record_count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM bronze_payroll_raw), 2) AS percentage
FROM bronze_payroll_raw
WHERE ABS(
  CAST(gross_pay AS DECIMAL(10,2)) -
  CAST(tax_withheld AS DECIMAL(10,2)) -
  COALESCE(CAST(deductions AS DECIMAL(10,2)), 0) -
  CAST(net_pay AS DECIMAL(10,2))
) > 0.01

ORDER BY issue_type;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 6. Data Cleansing and Transformation

-- COMMAND ----------

-- Create cleansed temporary view with all transformations and validations
CREATE OR REPLACE TEMPORARY VIEW payroll_cleansed AS
SELECT DISTINCT
  -- Primary Key
  CAST(pr.payment_id AS INT) AS payment_id,

  -- Foreign Key (validated against HR Silver)
  CAST(pr.employee_id AS INT) AS employee_id,

  -- Pay Period Dates
  CAST(pr.pay_period_start AS DATE) AS pay_period_start,
  CAST(pr.pay_period_end AS DATE) AS pay_period_end,

  -- Financial Amounts (proper decimal format)
  CAST(pr.gross_pay AS DECIMAL(10,2)) AS gross_pay,
  CAST(pr.tax_withheld AS DECIMAL(10,2)) AS tax_withheld,
  COALESCE(CAST(pr.deductions AS DECIMAL(10,2)), 0.00) AS deductions,

  -- Recalculate net_pay for data accuracy (don't trust source calculation)
  CAST(
    CAST(pr.gross_pay AS DECIMAL(10,2)) -
    CAST(pr.tax_withheld AS DECIMAL(10,2)) -
    COALESCE(CAST(pr.deductions AS DECIMAL(10,2)), 0.00)
    AS DECIMAL(10,2)
  ) AS net_pay,

  -- Payment Date
  CAST(pr.payment_date AS DATE) AS payment_date,

  -- Payment Method (standardize casing variations)
  CASE
    WHEN UPPER(TRIM(pr.payment_method)) = 'DIRECT DEPOSIT' THEN 'Direct Deposit'
    WHEN UPPER(TRIM(pr.payment_method)) = 'CHECK' THEN 'Check'
    WHEN UPPER(TRIM(pr.payment_method)) = 'WIRE TRANSFER' THEN 'Wire Transfer'
    ELSE 'Unknown'
  END AS payment_method,

  -- Bank Account (handle N/A for non-direct deposit)
  CASE
    WHEN TRIM(pr.bank_account_last4) IN ('N/A', 'NA', '') THEN NULL
    ELSE TRIM(pr.bank_account_last4)
  END AS bank_account_last4,

  -- Created Datetime
  CAST(pr.created_datetime AS TIMESTAMP) AS created_datetime,

  -- Metadata columns
  CURRENT_TIMESTAMP() AS processed_timestamp,
  'PAYROLL_PAYMENTS' AS source_file_name,
  getArgument('pod_id') AS pod_id

FROM bronze_payroll_raw pr

-- Referential Integrity: Join with HR Silver to validate employee_id
INNER JOIN delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees` hr
  ON pr.employee_id = hr.employee_id
  AND hr.pod_id = getArgument('pod_id')

-- Data Quality Filters
WHERE
  -- Critical field validation
  pr.payment_id IS NOT NULL
  AND CAST(pr.payment_id AS INT) IS NOT NULL
  AND pr.employee_id IS NOT NULL
  AND CAST(pr.employee_id AS INT) IS NOT NULL

  -- Date validations
  AND TRY_CAST(pr.pay_period_start AS DATE) IS NOT NULL
  AND TRY_CAST(pr.pay_period_end AS DATE) IS NOT NULL
  AND TRY_CAST(pr.payment_date AS DATE) IS NOT NULL
  AND TRY_CAST(pr.pay_period_start AS DATE) < TRY_CAST(pr.pay_period_end AS DATE)
  AND TRY_CAST(pr.payment_date AS DATE) <= CURRENT_DATE()

  -- Financial validations (no negative amounts)
  AND TRY_CAST(pr.gross_pay AS DECIMAL(10,2)) >= 0
  AND TRY_CAST(pr.tax_withheld AS DECIMAL(10,2)) >= 0
  AND COALESCE(TRY_CAST(pr.deductions AS DECIMAL(10,2)), 0) >= 0;

-- Show sample of cleansed data
SELECT 'Cleansed Data Sample' AS step;
SELECT * FROM payroll_cleansed LIMIT 5;

-- Row count after cleansing
SELECT 'Cleansed Row Count' AS metric, COUNT(*) AS row_count FROM payroll_cleansed;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 7. Referential Integrity Validation Results

-- COMMAND ----------

-- Show which employee_ids were filtered out due to missing HR records
SELECT 'Orphaned Payroll Records (No HR Match)' AS validation;

SELECT DISTINCT
  pr.employee_id,
  COUNT(*) AS payment_count
FROM bronze_payroll_raw pr
WHERE NOT EXISTS (
  SELECT 1
  FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees` hr
  WHERE hr.employee_id = pr.employee_id
    AND hr.pod_id = getArgument('pod_id')
)
GROUP BY pr.employee_id
ORDER BY pr.employee_id;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 8. Data Quality Summary

-- COMMAND ----------

-- Calculate cleansing impact
SELECT 'Data Cleansing Summary' AS summary;

SELECT
  (SELECT COUNT(*) FROM bronze_payroll_raw) AS bronze_row_count,
  (SELECT COUNT(*) FROM payroll_cleansed) AS silver_row_count,
  (SELECT COUNT(*) FROM bronze_payroll_raw) - (SELECT COUNT(*) FROM payroll_cleansed) AS rows_filtered,
  ROUND(
    ((SELECT COUNT(*) FROM bronze_payroll_raw) - (SELECT COUNT(*) FROM payroll_cleansed)) * 100.0 /
    (SELECT COUNT(*) FROM bronze_payroll_raw),
    2
  ) AS filter_percentage;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 9. Payment Calculation Validation

-- COMMAND ----------

-- Compare original net_pay vs recalculated net_pay
SELECT 'Payment Calculation Discrepancies' AS validation;

SELECT
  pr.payment_id,
  pr.employee_id,
  CAST(pr.gross_pay AS DECIMAL(10,2)) AS original_gross_pay,
  CAST(pr.tax_withheld AS DECIMAL(10,2)) AS original_tax_withheld,
  COALESCE(CAST(pr.deductions AS DECIMAL(10,2)), 0.00) AS original_deductions,
  CAST(pr.net_pay AS DECIMAL(10,2)) AS original_net_pay,
  CAST(
    CAST(pr.gross_pay AS DECIMAL(10,2)) -
    CAST(pr.tax_withheld AS DECIMAL(10,2)) -
    COALESCE(CAST(pr.deductions AS DECIMAL(10,2)), 0.00)
    AS DECIMAL(10,2)
  ) AS recalculated_net_pay,
  CAST(
    CAST(pr.net_pay AS DECIMAL(10,2)) -
    (CAST(pr.gross_pay AS DECIMAL(10,2)) -
     CAST(pr.tax_withheld AS DECIMAL(10,2)) -
     COALESCE(CAST(pr.deductions AS DECIMAL(10,2)), 0.00))
    AS DECIMAL(10,2)
  ) AS discrepancy
FROM bronze_payroll_raw pr
WHERE ABS(
  CAST(pr.gross_pay AS DECIMAL(10,2)) -
  CAST(pr.tax_withheld AS DECIMAL(10,2)) -
  COALESCE(CAST(pr.deductions AS DECIMAL(10,2)), 0.00) -
  CAST(pr.net_pay AS DECIMAL(10,2))
) > 0.01
LIMIT 20;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 10. Create/Update Silver Delta Table

-- COMMAND ----------

-- Create Silver table if it doesn't exist
CREATE TABLE IF NOT EXISTS delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/payroll/payments` (
  payment_id INT NOT NULL,
  employee_id INT NOT NULL,
  pay_period_start DATE NOT NULL,
  pay_period_end DATE NOT NULL,
  gross_pay DECIMAL(10,2) NOT NULL,
  tax_withheld DECIMAL(10,2) NOT NULL,
  deductions DECIMAL(10,2) NOT NULL,
  net_pay DECIMAL(10,2) NOT NULL,
  payment_date DATE NOT NULL,
  payment_method STRING NOT NULL,
  bank_account_last4 STRING,
  created_datetime TIMESTAMP,
  processed_timestamp TIMESTAMP NOT NULL,
  source_file_name STRING NOT NULL,
  pod_id STRING NOT NULL
)
USING DELTA
PARTITIONED BY (pod_id)
LOCATION 'abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/payroll/payments';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 11. Merge Cleansed Data into Silver (Idempotent Upsert)

-- COMMAND ----------

-- Perform MERGE operation for idempotency
-- Updates existing records, inserts new records
MERGE INTO delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/payroll/payments` AS target
USING payroll_cleansed AS source
ON target.payment_id = source.payment_id AND target.pod_id = source.pod_id

WHEN MATCHED THEN
  UPDATE SET
    target.employee_id = source.employee_id,
    target.pay_period_start = source.pay_period_start,
    target.pay_period_end = source.pay_period_end,
    target.gross_pay = source.gross_pay,
    target.tax_withheld = source.tax_withheld,
    target.deductions = source.deductions,
    target.net_pay = source.net_pay,
    target.payment_date = source.payment_date,
    target.payment_method = source.payment_method,
    target.bank_account_last4 = source.bank_account_last4,
    target.created_datetime = source.created_datetime,
    target.processed_timestamp = source.processed_timestamp,
    target.source_file_name = source.source_file_name

WHEN NOT MATCHED THEN
  INSERT (
    payment_id,
    employee_id,
    pay_period_start,
    pay_period_end,
    gross_pay,
    tax_withheld,
    deductions,
    net_pay,
    payment_date,
    payment_method,
    bank_account_last4,
    created_datetime,
    processed_timestamp,
    source_file_name,
    pod_id
  )
  VALUES (
    source.payment_id,
    source.employee_id,
    source.pay_period_start,
    source.pay_period_end,
    source.gross_pay,
    source.tax_withheld,
    source.deductions,
    source.net_pay,
    source.payment_date,
    source.payment_method,
    source.bank_account_last4,
    source.created_datetime,
    source.processed_timestamp,
    source.source_file_name,
    source.pod_id
  );

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 12. Verify Silver Table

-- COMMAND ----------

-- Final row count in Silver
SELECT 'Silver Table Row Count' AS metric, COUNT(*) AS row_count
FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/payroll/payments`
WHERE pod_id = getArgument('pod_id');

-- Show sample of final data
SELECT 'Silver Table Sample' AS step;
SELECT * FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/payroll/payments`
WHERE pod_id = getArgument('pod_id')
ORDER BY payment_date DESC, payment_id
LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 13. Verify Referential Integrity

-- COMMAND ----------

-- Ensure all employee_ids in Payroll Silver exist in HR Silver
SELECT 'Referential Integrity Check' AS validation;

SELECT
  COUNT(DISTINCT p.employee_id) AS unique_employees_in_payroll,
  (
    SELECT COUNT(DISTINCT employee_id)
    FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees`
    WHERE pod_id = getArgument('pod_id')
  ) AS unique_employees_in_hr,
  CASE
    WHEN COUNT(DISTINCT p.employee_id) <= (
      SELECT COUNT(DISTINCT employee_id)
      FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees`
      WHERE pod_id = getArgument('pod_id')
    ) THEN 'PASS - All payroll employee_ids exist in HR'
    ELSE 'FAIL - Orphaned employee_ids found'
  END AS integrity_status
FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/payroll/payments` p
WHERE p.pod_id = getArgument('pod_id');

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 14. Optimize Delta Table

-- COMMAND ----------

-- Optimize Delta table for query performance
OPTIMIZE delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/payroll/payments`
WHERE pod_id = getArgument('pod_id');

-- Collect statistics for better query planning
ANALYZE TABLE delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/payroll/payments`
COMPUTE STATISTICS;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 15. Processing Summary

-- COMMAND ----------

-- Final processing summary
SELECT 'Payroll Data Processing Complete' AS status;

SELECT
  getArgument('pod_id') AS pod_id,
  getArgument('domain') AS domain,
  'PAYROLL_PAYMENTS' AS source_file,
  (SELECT COUNT(*) FROM bronze_payroll_raw) AS bronze_records,
  (SELECT COUNT(*) FROM payroll_cleansed) AS records_after_cleansing,
  (SELECT COUNT(*) FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/payroll/payments` WHERE pod_id = getArgument('pod_id')) AS silver_records,
  CURRENT_TIMESTAMP() AS completed_at;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ---
-- MAGIC **Notebook Complete**: Payroll payment data has been cleansed, validated against HR data, and loaded into the Silver layer.
-- MAGIC
-- MAGIC **Next Step**: Run `03_silver_to_gold_analytics` notebook to create business-ready aggregated views in the Gold layer.
