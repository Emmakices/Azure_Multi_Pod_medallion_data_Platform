-- Databricks notebook source
-- MAGIC %md
-- MAGIC # Bronze to Silver: HR Employee Data Cleansing (Pod A)
-- MAGIC
-- MAGIC **Pod**: podA
-- MAGIC **Required Cluster**: podA-interactive
-- MAGIC **Purpose**: Read raw HR employee data from Bronze layer, cleanse and validate, write to Silver as Delta table
-- MAGIC
-- MAGIC **Data Flow**:
-- MAGIC - Source: bronze/podA/hr/HR_EMPLOYEES
-- MAGIC - Target: silver/podA/hr/employees
-- MAGIC
-- MAGIC **Pod Isolation**: This notebook ONLY processes podA data and must run on podA-interactive cluster

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 0. Cluster Validation (Enforce Pod Isolation)

-- COMMAND ----------

-- MAGIC %python
-- MAGIC # Validate that this notebook is running on the correct cluster
-- MAGIC import json
-- MAGIC
-- MAGIC # Get cluster information
-- MAGIC cluster_name = spark.conf.get("spark.databricks.clusterUsageTags.clusterName", "UNKNOWN")
-- MAGIC
-- MAGIC # Define required cluster for this pod
-- MAGIC REQUIRED_CLUSTER = "podA-interactive"
-- MAGIC POD_ID = "podA"
-- MAGIC
-- MAGIC print(f"Current Cluster: {cluster_name}")
-- MAGIC print(f"Required Cluster: {REQUIRED_CLUSTER}")
-- MAGIC print(f"Pod ID: {POD_ID}")
-- MAGIC
-- MAGIC # Enforce cluster requirement
-- MAGIC if cluster_name != REQUIRED_CLUSTER:
-- MAGIC     error_msg = f"""
-- MAGIC     ╔══════════════════════════════════════════════════════════════╗
-- MAGIC     ║  CLUSTER VALIDATION FAILED                                   ║
-- MAGIC     ╠══════════════════════════════════════════════════════════════╣
-- MAGIC     ║  This notebook is for Pod A and MUST run on:                 ║
-- MAGIC     ║  Cluster: {REQUIRED_CLUSTER}                                 ║
-- MAGIC     ║                                                              ║
-- MAGIC     ║  Currently running on: {cluster_name}                        ║
-- MAGIC     ║                                                              ║
-- MAGIC     ║  ACTION REQUIRED:                                            ║
-- MAGIC     ║  1. Detach this notebook                                     ║
-- MAGIC     ║  2. Attach to: {REQUIRED_CLUSTER}                            ║
-- MAGIC     ║  3. Re-run all cells                                         ║
-- MAGIC     ╚══════════════════════════════════════════════════════════════╝
-- MAGIC     """
-- MAGIC     raise ValueError(error_msg)
-- MAGIC else:
-- MAGIC     print("✓ CLUSTER VALIDATION PASSED")
-- MAGIC     print(f"✓ Running on correct cluster: {REQUIRED_CLUSTER}")

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. Configuration Variables

-- COMMAND ----------

-- Set configuration variables (HARDCODED for podA)
DECLARE storage_account STRING DEFAULT 'stdldevshared77b5h3';
DECLARE pod STRING DEFAULT 'podA';
DECLARE domain_name STRING DEFAULT 'hr';
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
-- MAGIC ## 2. Read Raw Data from Bronze Layer

-- COMMAND ----------

-- Create temporary view of raw bronze data
CREATE OR REPLACE TEMPORARY VIEW bronze_hr_raw AS
SELECT * FROM delta.`abfss://bronze@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/HR_EMPLOYEES`;

-- Show sample of raw data
SELECT 'Raw Bronze Data Sample' AS step;
SELECT * FROM bronze_hr_raw LIMIT 5;

-- Row count before cleansing
SELECT 'Bronze Row Count' AS metric, COUNT(*) AS row_count FROM bronze_hr_raw;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Data Quality Analysis

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

ORDER BY issue_type;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 4. Data Cleansing and Transformation

-- COMMAND ----------

-- Create cleansed temporary view with all transformations
CREATE OR REPLACE TEMPORARY VIEW hr_cleansed AS
SELECT DISTINCT
  CAST(employee_id AS INT) AS employee_id,
  INITCAP(TRIM(first_name)) AS first_name,
  INITCAP(TRIM(last_name)) AS last_name,
  LOWER(TRIM(email)) AS email,
  TRIM(department) AS department,
  TRIM(job_title) AS job_title,
  CAST(hire_date AS DATE) AS hire_date,
  CAST(salary AS DECIMAL(10,2)) AS salary,
  INITCAP(TRIM(employment_status)) AS employment_status,
  CAST(manager_id AS INT) AS manager_id,
  CASE
    WHEN TRIM(office_location) = '' THEN NULL
    ELSE TRIM(office_location)
  END AS office_location,
  CAST(created_datetime AS TIMESTAMP) AS created_datetime,
  CURRENT_TIMESTAMP() AS processed_timestamp,
  'HR_EMPLOYEES' AS source_file_name,
  'podA' AS pod_id

FROM bronze_hr_raw

WHERE
  employee_id IS NOT NULL
  AND CAST(employee_id AS INT) IS NOT NULL
  AND TRY_CAST(salary AS DECIMAL(10,2)) > 0
  AND TRY_CAST(hire_date AS DATE) <= CURRENT_DATE()
  AND email IS NOT NULL
  AND TRIM(email) != ''
  AND email LIKE '%@%.%'
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
-- MAGIC ## 5. Create/Update Silver Delta Table

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
-- MAGIC ## 6. Merge Cleansed Data into Silver (Idempotent Upsert)

-- COMMAND ----------

-- Perform MERGE operation for idempotency
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
    employee_id, first_name, last_name, email, department, job_title, hire_date,
    salary, employment_status, manager_id, office_location, created_datetime,
    processed_timestamp, source_file_name, pod_id
  )
  VALUES (
    source.employee_id, source.first_name, source.last_name, source.email,
    source.department, source.job_title, source.hire_date, source.salary,
    source.employment_status, source.manager_id, source.office_location,
    source.created_datetime, source.processed_timestamp, source.source_file_name,
    source.pod_id
  );

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 7. Verify and Optimize

-- COMMAND ----------

-- Final row count in Silver
SELECT 'Silver Table Row Count' AS metric, COUNT(*) AS row_count
FROM delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees`
WHERE pod_id = 'podA';

-- Optimize Delta table
OPTIMIZE delta.`abfss://silver@stdldevshared77b5h3.dfs.core.windows.net/podA/hr/employees`
WHERE pod_id = 'podA';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ---
-- MAGIC **Pod A Processing Complete**: HR employee data cleansed and loaded to Silver layer.
-- MAGIC
-- MAGIC **Next**: Run podA/02_bronze_to_silver_payroll on podA-interactive cluster.
