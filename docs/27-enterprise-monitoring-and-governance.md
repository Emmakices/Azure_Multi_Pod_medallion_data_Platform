# Enterprise Monitoring and Governance Framework

**Created**: January 16, 2025
**Purpose**: Comprehensive enterprise-grade monitoring, logging, and governance
**Status**: Production-Ready

---

## Overview

This document explains all enterprise features implemented in the data platform, why we built them, their benefits, and how to use them.

---

## Complete Feature List

### 1. Company Configuration Table

**Location**: `gold/config/companies`
**Notebook**: `databricks_notebooks/config/01_create_company_config_table.py`

**Why We Built This**:
- Eliminate hardcoded company lists in ADF pipelines
- Enable dynamic pipeline execution based on configuration
- Centralize all processing configuration in one place
- Support easy onboarding of new companies without pipeline changes

**What It Does**:
- Stores configuration for all companies across all pods
- Defines which domains to process for each company
- Specifies cluster configuration (workers, node types, autoscale)
- Tracks business metadata (cost center, compliance tags, SLA)
- Includes approval workflow (DRAFT, APPROVED, REJECTED)

**Benefits**:
- Dynamic orchestration: Add/remove companies by updating table
- No code changes: Pipeline reads config from database
- Governance: Approval required before processing new companies
- Cost management: Specify cluster sizes per company
- Compliance: Track which companies require GDPR, SOX, HIPAA

**Where To Use**:
- ADF Pipeline Step 1: Get_Company_Config activity
- Query at pipeline start to get list of companies to process
- ForEach loop iterates through returned companies

**Example**:
```sql
SELECT pod_id, company, worker_count, domains, priority, sla_hours
FROM company_config
WHERE pod_id = 'podA' AND enabled = true
ORDER BY priority DESC
```

---

### 2. Pipeline Execution Log Table

**Location**: `gold/config/pipeline_execution_log`
**Notebook**: `databricks_notebooks/config/02_create_pipeline_execution_log_table.py`

**Why We Built This**:
- Track every pipeline execution for audit and troubleshooting
- Monitor performance trends over time
- Identify slow or failing processes
- Provide execution history for compliance audits
- Enable cost attribution by execution

**What It Does**:
- Logs start and end of every pipeline activity
- Captures execution duration, status (SUCCESS/FAILED)
- Records error messages and stack traces for failures
- Tracks data metrics (rows processed, file sizes)
- Stores custom dimensions for flexible filtering
- Links to cluster information and DBU consumed

**Benefits**:
- Complete audit trail of all executions
- Troubleshooting: See exactly what failed and why
- Performance monitoring: Track duration trends
- Cost analysis: DBU consumption by pod/company/domain
- SLA tracking: Verify processing completed within SLA

**Where To Use**:
- Before each major ADF activity: Call log_execution_start
- After successful completion: Call log_execution_end
- On failure: Call log_execution_error
- Query for monitoring dashboards and alerts

**Example**:
```sql
-- Recent failures
SELECT execution_id, pod_id, company, stage, error_message
FROM pipeline_execution_log
WHERE status = 'FAILED' AND execution_date >= CURRENT_DATE() - 7
ORDER BY execution_start_time DESC
```

---

### 3. Data Lineage Tracking Table

**Location**: `gold/config/data_lineage`
**Notebook**: `databricks_notebooks/config/03_create_data_lineage_table.py`

**Why We Built This**:
- Answer "Where did this file go?" questions
- Trace Gold records back to source files for audit
- Impact analysis: If source file corrupted, which tables affected?
- Regulatory compliance: Prove data lineage for audits
- Troubleshooting: Trace data quality issues to source

**What It Does**:
- Tracks complete journey of data from source file through Bronze, Silver, Gold
- Records file paths at each layer
- Captures record counts at each transformation
- Tracks records rejected during quality checks
- Links to execution logs via execution_id

**Benefits**:
- Complete data lineage from source to analytics
- Regulatory compliance (GDPR right to erasure, SOX audit trails)
- Impact analysis: Know which downstream tables affected by bad data
- Troubleshooting: Trace back to source file when issues found
- Data lifecycle management: Track data age and retention

**Where To Use**:
- After copying to Bronze: Log source file and Bronze path
- After Bronze→Silver: Log Silver path and cleansed record count
- After Silver→Gold: Log Gold path and final record count
- Query to answer lineage questions

**Example**:
```sql
-- Find all Gold records from specific source file
SELECT source_file_name, bronze_path, silver_path, gold_path,
       records_in_bronze, records_in_silver, records_in_gold
FROM data_lineage
WHERE source_file_name = 'hr_employees.csv'
  AND lineage_status = 'COMPLETED'
```

---

### 4. Data Quality Rules Log Table

**Location**: `gold/config/data_quality_log`
**Notebook**: `databricks_notebooks/config/04_create_data_quality_log_table.py`

**Why We Built This**:
- Monitor data quality trends over time
- Identify which quality rules fail most often
- Alert on critical quality failures
- Prove data quality controls exist (compliance)
- Track quality improvement initiatives

**What It Does**:
- Logs result of every quality rule check
- Records which rules passed/failed and by how much
- Tracks severity (CRITICAL, WARNING, INFO)
- Stores action taken (REJECTED, QUARANTINED, ACCEPTED_WITH_WARNING)
- Includes sample of failed records for investigation

**Benefits**:
- Quality monitoring: Is data quality improving?
- Early detection: Alert before bad data reaches Gold
- Root cause analysis: Identify problematic sources
- Compliance: Prove quality controls in place
- Continuous improvement: Track impact of quality initiatives

**Where To Use**:
- During Bronze→Silver transformation: After each quality check
- In custom quality validation notebooks
- Query for quality dashboards and trend analysis

**Example Quality Checks**:
- NOT_NULL: employee_id must not be null
- FORMAT: email must match email regex
- RANGE: salary must be > 0 and < 1000000
- UNIQUENESS: employee_id must be unique
- REFERENCE: department_id must exist in departments table

**Example**:
```sql
-- Quality failures in last 30 days
SELECT rule_name, rule_type, AVG(pass_percentage) as avg_pass_rate,
       SUM(records_failed) as total_failures
FROM data_quality_log
WHERE check_date >= CURRENT_DATE() - 30
  AND severity IN ('CRITICAL', 'WARNING')
GROUP BY rule_name, rule_type
ORDER BY avg_pass_rate ASC
```

---

### 5. SLA Monitoring Table

**Location**: `gold/config/sla_monitoring`
**Notebook**: `databricks_notebooks/config/05_create_sla_monitoring_table.py`

**Why We Built This**:
- Ensure we meet business SLA commitments
- Alert stakeholders before SLA breach
- Justify infrastructure upgrades with SLA data
- Report SLA compliance to business
- Identify processes consistently missing SLA

**What It Does**:
- Tracks time from file arrival to processing completion
- Compares against SLA defined in company_config
- Records whether SLA was met
- Calculates how many minutes over/under SLA
- Logs alert notifications sent

**Benefits**:
- SLA compliance reporting to business
- Early warning: Alert approaching SLA breaches
- Performance justification: Show need for faster clusters
- Trend analysis: Are SLAs consistently met?
- Prioritization: Focus optimization on SLA-critical processes

**Where To Use**:
- After pipeline completion: Calculate total elapsed time
- Compare against SLA from company_config
- Alert if SLA breached
- Query for SLA compliance reports

**Example**:
```sql
-- SLA compliance by company
SELECT company, priority, sla_hours,
       COUNT(*) as total_runs,
       SUM(CASE WHEN sla_met THEN 1 ELSE 0 END) as sla_met_count,
       ROUND(100.0 * SUM(CASE WHEN sla_met THEN 1 ELSE 0 END) / COUNT(*), 2) as sla_compliance_pct
FROM sla_monitoring
WHERE sla_date >= CURRENT_DATE() - 30
GROUP BY company, priority, sla_hours
ORDER BY sla_compliance_pct ASC
```

---

### 6. Cost Tracking Table

**Location**: `gold/config/cost_tracking`
**Notebook**: `databricks_notebooks/config/06_create_cost_tracking_table.py`

**Why We Built This**:
- Monthly chargeback to business units
- Identify expensive processes for optimization
- Budget planning with historical cost data
- ROI analysis for infrastructure investments
- Cost transparency to stakeholders

**What It Does**:
- Tracks DBU consumption per execution
- Calculates compute costs (DBU × rate)
- Tracks storage costs (data read/written)
- Links to cost center for chargeback
- Calculates cost per record processed

**Benefits**:
- Accurate chargeback to business units
- Identify optimization opportunities (high cost per record)
- Budget forecasting based on historical trends
- ROI calculation for infrastructure changes
- Cost awareness drives efficiency

**Where To Use**:
- After execution completion: Log DBU consumed
- Get DBU rate from Azure pricing
- Calculate total cost
- Monthly: Aggregate by cost center for chargeback

**Example**:
```sql
-- Monthly cost by business unit
SELECT business_unit, cost_center, billing_month,
       SUM(total_cost_usd) as total_cost,
       SUM(dbu_consumed) as total_dbu,
       COUNT(*) as execution_count
FROM cost_tracking
WHERE billing_month = '2025-01'
GROUP BY business_unit, cost_center, billing_month
ORDER BY total_cost DESC
```

---

### 7. Alert Rules Configuration Table

**Location**: `gold/config/alert_rules`
**Notebook**: `databricks_notebooks/config/07_create_alert_and_policy_tables.py`

**Why We Built This**:
- Centralize alert configuration in database
- Enable/disable alerts without code changes
- Configure thresholds dynamically
- Route alerts to appropriate channels
- Cooldown periods to prevent alert fatigue

**What It Does**:
- Defines alert conditions (duration > X, quality < Y, SLA breach)
- Specifies notification channels (EMAIL, SLACK, TEAMS)
- Sets severity levels (CRITICAL, WARNING, INFO)
- Configures cooldown periods between alerts
- Allows pod/company/domain-specific rules

**Benefits**:
- Dynamic alert management (no code changes)
- Prevent alert fatigue with cooldown periods
- Route alerts to right people
- Easy to adjust thresholds as needed
- Disable noisy alerts without deployment

**Where To Use**:
- After execution: Query alert rules for this pod/company/stage
- Check if thresholds exceeded
- Send notification via configured channel
- Respect cooldown period

**Example Alert Rules**:
- Bronze→Silver > 10 minutes → EMAIL to data team
- Data quality < 95% → SLACK to #data-alerts
- SLA breach → EMAIL to business + data team
- Cost > $10/execution → EMAIL to finance

**Example**:
```sql
SELECT * FROM alert_rules
WHERE enabled = true
  AND (pod_id = 'podA' OR pod_id IS NULL)
  AND (company = 'finance' OR company IS NULL)
  AND rule_type = 'DURATION'
```

---

### 8. Retry Policy Configuration Table

**Location**: `gold/config/retry_policy`
**Notebook**: `databricks_notebooks/config/07_create_alert_and_policy_tables.py`

**Why We Built This**:
- Configure retry behavior without changing ADF pipeline
- Different retry strategies for different stages
- Handle transient errors gracefully
- Notify on retries for visibility
- Exponential backoff to avoid overwhelming resources

**What It Does**:
- Defines max retry attempts per pod/stage
- Configures retry delay and backoff strategy
- Specifies which error types to retry
- Controls notifications on retry attempts

**Benefits**:
- Resilience: Automatically retry transient failures
- Flexibility: Different retry strategies per stage
- Visibility: Notifications on retry attempts
- No code changes: Adjust retry config in database
- Intelligent backoff: Avoid overwhelming resources

**Where To Use**:
- On pipeline failure: Query retry policy for this pod/stage
- Check if error type is retryable
- Wait configured delay (with backoff if enabled)
- Retry up to max_retry_count
- Notify if configured

**Example**:
```sql
-- Get retry policy for Bronze→Silver
SELECT max_retry_count, retry_delay_seconds,
       exponential_backoff, backoff_multiplier
FROM retry_policy
WHERE pod_id = 'podA'
  AND (company = 'finance' OR company IS NULL)
  AND stage = 'bronze_to_silver'
  AND enabled = true
```

---

### 9. Archive Log Table

**Location**: `gold/config/archive_log`
**Notebook**: `databricks_notebooks/config/07_create_alert_and_policy_tables.py`

**Why We Built This**:
- Track all archived files for audit
- Enforce retention policies
- Auto-delete old archives
- Compliance with data retention regulations
- Prevent storage costs from archived data

**What It Does**:
- Logs when files moved to archive
- Records retention period and deletion date
- Tracks total size of archived data
- Links to pod/company for reporting

**Benefits**:
- Audit trail for archived files
- Automated retention enforcement
- Cost management: Delete old archives
- Compliance: Prove retention policies enforced
- Storage optimization: Track archive space usage

**Where To Use**:
- After archiving files from landing zone: Log archive details
- Set deletion_date based on retention policy
- Scheduled job: Delete files past deletion_date
- Query for archive reports

**Example**:
```sql
-- Files pending deletion in next 30 days
SELECT archive_path, file_count, total_size_mb, deletion_date,
       DATEDIFF(deletion_date, CURRENT_DATE()) as days_until_deletion
FROM archive_log
WHERE deletion_date BETWEEN CURRENT_DATE() AND DATE_ADD(CURRENT_DATE(), 30)
ORDER BY days_until_deletion
```

---

## Integration with ADF Pipeline

### Complete Pipeline Flow with All Enterprise Features

```
Pipeline: MultiPod_DataLake_Orchestration

Step 1: Get Company Configuration
  └─ Calls: /Shared/config/get_company_config
  └─ Returns: List of enabled companies for this pod
  └─ Feature: COMPANY CONFIGURATION

Step 2: ForEach Company

  Step 3: Check Data Exists

  Step 4: If Has Data

  Step 5: Copy to Bronze
    ├─ Log Start: /Shared/config/log_execution_start
    ├─ Copy Files
    ├─ Log Lineage: /Shared/config/log_data_lineage (layer=bronze)
    └─ Log End: /Shared/config/log_execution_end
    Features: EXECUTION LOG, DATA LINEAGE

  Step 6: Archive Files
    └─ Log Archive: /Shared/config/log_archive
    Feature: ARCHIVE LOG

  Step 7: Check Completeness
    ├─ Log Start
    ├─ Check Bronze Completeness
    └─ Log End
    Feature: EXECUTION LOG

  Step 8: If Complete

  Step 9: ForEach Domain

    Step 10: Log SLA Start
      └─ Record file_arrival_time
      Feature: SLA MONITORING

    Step 11: Bronze→Silver
      ├─ Log Start + Lineage ID
      ├─ Execute Transformation
      │  ├─ Run Quality Checks
      │  └─ Log Quality Results
      ├─ Update Lineage (layer=silver)
      ├─ Check Alert Rules
      ├─ Log Cost Metrics
      └─ Log End
      Features: EXECUTION LOG, DATA LINEAGE, QUALITY LOG, ALERT RULES, COST TRACKING

    Step 12: Silver→Gold
      ├─ Log Start
      ├─ Execute Transformation
      ├─ Update Lineage (layer=gold, status=COMPLETED)
      ├─ Check Alert Rules
      ├─ Log Cost Metrics
      └─ Log End
      Features: EXECUTION LOG, DATA LINEAGE, COST TRACKING

    Step 13: Log SLA End
      └─ Calculate total_elapsed_time, check if SLA met
      Feature: SLA MONITORING

  On Failure:
    ├─ Log Error
    ├─ Query Retry Policy
    ├─ Retry if applicable
    └─ Send Alert if configured
    Features: EXECUTION LOG, RETRY POLICY, ALERT RULES
```

---

## Summary of Benefits

### Monitoring & Observability
- Real-time execution tracking
- Performance trend analysis
- Quality monitoring dashboards
- Cost visibility by business unit

### Governance & Compliance
- Complete audit trail (who, what, when)
- Data lineage for regulatory requirements
- Approval workflows for config changes
- Retention policy enforcement

### Operations & Reliability
- Automated retries for transient failures
- SLA monitoring and alerting
- Quality gates prevent bad data
- Configuration-driven orchestration

### Cost Management
- Accurate chargeback to business units
- Cost per execution/record tracking
- Identify optimization opportunities
- Budget forecasting with historical data

---

## Where This Documentation Belongs

This document (`docs/27-enterprise-monitoring-and-governance.md`) explains:
- **WHAT** we built (9 enterprise features)
- **WHY** we built each feature
- **BENEFITS** of each feature
- **WHERE TO USE** in ADF pipeline

**Related Documents**:
- `docs/26-metadata-driven-orchestration-and-logging.md` - Technical implementation details
- `implementation_guide.md` - Step-by-step build instructions
- `architecture_summary.md` - Overall architecture overview
- `METADATA_ORCHESTRATION_SUMMARY.md` - Quick reference for features

---

## Conclusion

These 9 enterprise features transform the data platform from basic ETL to enterprise-grade data infrastructure with:
- **Configuration-driven orchestration** (no hardcoded values)
- **Complete observability** (track everything)
- **Data governance** (lineage, quality, compliance)
- **Cost management** (track and optimize)
- **Operational excellence** (SLA, alerts, retries)

All features are production-ready, documented, and integrated with the ADF pipeline.
