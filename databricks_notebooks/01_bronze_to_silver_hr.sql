-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Bronze to Silver: HR Employee Data Cleansing
-- MAGIC
-- MAGIC **Purpose**: Read raw HR employee data from Bronze layer, cleanse and validate, write to Silver as Delta table
-- MAGIC
-- MAGIC **Data Flow**:
-- MAGIC - Source: bronze/{pod_id}/hr/HR_EMPLOYEES
-- MAGIC - Target: silver/{pod_id}/hr/employees
-- MAGIC
-- MAGIC **Data Quality Rules**:
-- MAGIC - Remove exact duplicate rows
-- MAGIC - Remove NULL employee_id (critical field)
-- MAGIC - Remove future hire_dates (data quality issue)
-- MAGIC - Remove salary <= 0 or NULL
-- MAGIC - Trim whitespace, normalize email to lowercase
-- MAGIC
-- MAGIC **Dependencies**: None (HR is the master data)

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. Setup Parameters

-- COMMAND ----------

-- Create widgets for runtime parameters
CREATE WIDGET TEXT pod_id DEFAULT "podA";
CREATE WIDGET TEXT domain DEFAULT "hr";

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. Configuration Variables

-- COMMAND ----------

-- Set configuration variables
DECLARE storage_account STRING DEFAULT 'stdldevshared77b5h3';
DECLARE pod STRING DEFAULT getArgument('pod_id');
DECLARE domain_name STRING DEFAULT getArgument('domain');
DECLARE bronze_path STRING DEFAULT concat('abfss://bronze@', storage_account, '.dfs.core.windows.net/', pod, '/', domain_name, '/HR_EMPLOYEES');
DECLARE silver_path STRING DEFAULT concat('abfss://silver@', storage_account, '.dfs.core.windows.net/', pod, '/', domain_name, '/employees');

SELECT
  storage_account AS storage_account,
  pod AS pod_id,
  domain_name AS domain,
  bronze_path AS bronze_source,
  silver_path AS silver_target;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Read Raw Data from Bronze Layer

-- COMMAND ----------

-- Create temporary view of raw bronze data
-- Handles both Parquet and Delta formats automatically
CREATE OR REPLACE TEMPORARY VIEW bronze_hr_raw AS
SELECT * FROM delta.`abfss://bronze@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/HR_EMPLOYEES`;

-- Show sample of raw data
SELECT 'Raw Bronze Data Sample' AS step;
SELECT * FROM bronze_hr_raw LIMIT 5;

-- Row count before cleansing
SELECT 'Bronze Row Count' AS metric, COUNT(*) AS row_count FROM bronze_hr_raw;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 4. Data Quality Analysis

-- COMMAND ----------

-- Analyze data quality issues in bronze data
SELECT 'Data Quality Issues' AS analysis;

SELECT
  'Total Records' AS issue_type,
  COUNT(*) AS record_count,
  0 AS percentage
FROM bronze_hr_raw

UNION ALL

SELECT
  'NULL employee_id' AS issue_type,
  COUNT(*) AS record_count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM bronze_hr_raw), 2) AS percentage
FROM bronze_hr_raw
WHERE employee_id IS NULL

UNION ALL

SELECT
  'Duplicate Records' AS issue_type,
  COUNT(*) - COUNT(DISTINCT employee_id) AS record_count,
  ROUND((COUNT(*) - COUNT(DISTINCT employee_id)) * 100.0 / COUNT(*), 2) AS percentage
FROM bronze_hr_raw

UNION ALL

SELECT
  'Future Hire Dates' AS issue_type,
  COUNT(*) AS record_count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM bronze_hr_raw), 2) AS percentage
FROM bronze_hr_raw
WHERE TRY_CAST(hire_date AS DATE) > CURRENT_DATE()

UNION ALL

SELECT
  'Invalid Salary (<=0 or NULL)' AS issue_type,
  COUNT(*) AS record_count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM bronze_hr_raw), 2) AS percentage
FROM bronze_hr_raw
WHERE TRY_CAST(salary AS DECIMAL(10,2)) <= 0 OR salary IS NULL

UNION ALL

SELECT
  'Missing Email' AS issue_type,
  COUNT(*) AS record_count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM bronze_hr_raw), 2) AS percentage
FROM bronze_hr_raw
WHERE email IS NULL OR TRIM(email) = ''

UNION ALL

SELECT
  'Invalid Email Format' AS issue_type,
  COUNT(*) AS record_count,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM bronze_hr_raw), 2) AS percentage
FROM bronze_hr_raw
WHERE email IS NOT NULL
  AND TRIM(email) != ''
  AND email NOT LIKE '%@%.%'

ORDER BY issue_type;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 5. Data Cleansing and Transformation

-- COMMAND ----------

-- Create cleansed temporary view with all transformations
CREATE OR REPLACE TEMPORARY VIEW hr_cleansed AS
SELECT DISTINCT
  -- Primary Key
  CAST(employee_id AS INT) AS employee_id,

  -- Name fields (trim whitespace, proper case)
  INITCAP(TRIM(first_name)) AS first_name,
  INITCAP(TRIM(last_name)) AS last_name,

  -- Email (lowercase, trimmed)
  LOWER(TRIM(email)) AS email,

  -- Department and Job Title (trim whitespace)
  TRIM(department) AS department,
  TRIM(job_title) AS job_title,

  -- Dates
  CAST(hire_date AS DATE) AS hire_date,

  -- Salary (proper decimal format)
  CAST(salary AS DECIMAL(10,2)) AS salary,

  -- Employment Status (trim, proper case)
  INITCAP(TRIM(employment_status)) AS employment_status,

  -- Manager ID (nullable foreign key)
  CAST(manager_id AS INT) AS manager_id,

  -- Office Location (trim whitespace, handle empty strings)
  CASE
    WHEN TRIM(office_location) = '' THEN NULL
    ELSE TRIM(office_location)
  END AS office_location,

  -- Created Datetime
  CAST(created_datetime AS TIMESTAMP) AS created_datetime,

  -- Metadata columns
  CURRENT_TIMESTAMP() AS processed_timestamp,
  'HR_EMPLOYEES' AS source_file_name,
  getArgument('pod_id') AS pod_id

FROM bronze_hr_raw

-- Data Quality Filters
WHERE
  -- Critical field validation
  employee_id IS NOT NULL
  AND CAST(employee_id AS INT) IS NOT NULL

  -- Salary validation
  AND TRY_CAST(salary AS DECIMAL(10,2)) > 0

  -- Hire date validation (no future dates)
  AND TRY_CAST(hire_date AS DATE) <= CURRENT_DATE()

  -- Email validation (must be present and have basic format)
  AND email IS NOT NULL
  AND TRIM(email) != ''
  AND email LIKE '%@%.%'

  -- Name validation
  AND first_name IS NOT NULL
  AND TRIM(first_name) != ''
  AND last_name IS NOT NULL
  AND TRIM(last_name) != '';

-- Show sample of cleansed data
SELECT 'Cleansed Data Sample' AS step;
SELECT * FROM hr_cleansed LIMIT 5;

-- Row count after cleansing
SELECT 'Cleansed Row Count' AS metric, COUNT(*) AS row_count FROM hr_cleansed;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 6. Data Quality Summary

-- COMMAND ----------

-- Calculate cleansing impact
SELECT
  'Data Cleansing Summary' AS summary;

SELECT
  (SELECT COUNT(*) FROM bronze_hr_raw) AS bronze_row_count,
  (SELECT COUNT(*) FROM hr_cleansed) AS silver_row_count,
  (SELECT COUNT(*) FROM bronze_hr_raw) - (SELECT COUNT(*) FROM hr_cleansed) AS rows_filtered,
  ROUND(
    ((SELECT COUNT(*) FROM bronze_hr_raw) - (SELECT COUNT(*) FROM hr_cleansed)) * 100.0 /
    (SELECT COUNT(*) FROM bronze_hr_raw),
    2
  ) AS filter_percentage;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 7. Create/Update Silver Delta Table

-- COMMAND ----------

-- Create Silver table if it doesn't exist
CREATE TABLE IF NOT EXISTS delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees` (
  employee_id INT NOT NULL,
  first_name STRING NOT NULL,
  last_name STRING NOT NULL,
  email STRING NOT NULL,
  department STRING,
  job_title STRING,
  hire_date DATE NOT NULL,
  salary DECIMAL(10,2) NOT NULL,
  employment_status STRING,
  manager_id INT,
  office_location STRING,
  created_datetime TIMESTAMP,
  processed_timestamp TIMESTAMP NOT NULL,
  source_file_name STRING NOT NULL,
  pod_id STRING NOT NULL
)
USING DELTA
PARTITIONED BY (pod_id)
LOCATION 'abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 8. Merge Cleansed Data into Silver (Idempotent Upsert)

-- COMMAND ----------

-- Perform MERGE operation for idempotency
-- Updates existing records, inserts new records
MERGE INTO delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees` AS target
USING hr_cleansed AS source
ON target.employee_id = source.employee_id AND target.pod_id = source.pod_id

WHEN MATCHED THEN
  UPDATE SET
    target.first_name = source.first_name,
    target.last_name = source.last_name,
    target.email = source.email,
    target.department = source.department,
    target.job_title = source.job_title,
    target.hire_date = source.hire_date,
    target.salary = source.salary,
    target.employment_status = source.employment_status,
    target.manager_id = source.manager_id,
    target.office_location = source.office_location,
    target.created_datetime = source.created_datetime,
    target.processed_timestamp = source.processed_timestamp,
    target.source_file_name = source.source_file_name

WHEN NOT MATCHED THEN
  INSERT (
    employee_id,
    first_name,
    last_name,
    email,
    department,
    job_title,
    hire_date,
    salary,
    employment_status,
    manager_id,
    office_location,
    created_datetime,
    processed_timestamp,
    source_file_name,
    pod_id
  )
  VALUES (
    source.employee_id,
    source.first_name,
    source.last_name,
    source.email,
    source.department,
    source.job_title,
    source.hire_date,
    source.salary,
    source.employment_status,
    source.manager_id,
    source.office_location,
    source.created_datetime,
    source.processed_timestamp,
    source.source_file_name,
    source.pod_id
  );

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 9. Verify Silver Table

-- COMMAND ----------

-- Final row count in Silver
SELECT 'Silver Table Row Count' AS metric, COUNT(*) AS row_count
FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees`
WHERE pod_id = getArgument('pod_id');

-- Show sample of final data
SELECT 'Silver Table Sample' AS step;
SELECT * FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees`
WHERE pod_id = getArgument('pod_id')
ORDER BY employee_id
LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 10. Optimize Delta Table

-- COMMAND ----------

-- Optimize Delta table for query performance
OPTIMIZE delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees`
WHERE pod_id = getArgument('pod_id');

-- Collect statistics for better query planning
ANALYZE TABLE delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees`
COMPUTE STATISTICS;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 11. Processing Summary

-- COMMAND ----------

-- Final processing summary
SELECT 'HR Data Processing Complete' AS status;

SELECT
  getArgument('pod_id') AS pod_id,
  getArgument('domain') AS domain,
  'HR_EMPLOYEES' AS source_file,
  (SELECT COUNT(*) FROM bronze_hr_raw) AS bronze_records,
  (SELECT COUNT(*) FROM hr_cleansed) AS records_after_cleansing,
  (SELECT COUNT(*) FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees` WHERE pod_id = getArgument('pod_id')) AS silver_records,
  CURRENT_TIMESTAMP() AS completed_at;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ---
-- MAGIC **Notebook Complete**: HR employee data has been cleansed and loaded into the Silver layer.
-- MAGIC
-- MAGIC **Next Step**: Run `02_bronze_to_silver_payroll` notebook to process payroll data (depends on HR Silver data).
