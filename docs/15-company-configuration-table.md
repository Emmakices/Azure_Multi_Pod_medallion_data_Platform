# Company Configuration Table - Enterprise Standard

## Overview

The **company configuration table** is the central registry for all companies being processed in the data platform. It provides a configuration-driven architecture where the ADF pipeline dynamically adapts based on data stored in this table.

**Location**: `gold/config/companies`
**Format**: Delta Lake
**Partitioning**: By `pod_id`
**Version**: 1.0.0

---

## Table of Contents

1. [Architecture Principles](#architecture-principles)
2. [Schema Definition](#schema-definition)
3. [Enterprise Features](#enterprise-features)
4. [Configuration Standards](#configuration-standards)
5. [Usage Examples](#usage-examples)
6. [Maintenance Procedures](#maintenance-procedures)
7. [Integration with ADF](#integration-with-adf)

---

## Architecture Principles

### Configuration-Driven Design

Instead of hardcoding company information in ADF pipelines, all metadata lives in this Delta table:

```
Traditional Approach (Hardcoded):
├─ ADF Pipeline code contains company list
├─ To add company: Modify pipeline JSON → Redeploy
└─ Risk: Downtime, versioning issues

Configuration-Driven Approach (This Design):
├─ ADF Pipeline reads from config table
├─ To add company: INSERT one row → No pipeline changes
└─ Benefit: Zero downtime, self-service capable
```

### Single Source of Truth

All company metadata stored in one place:
- Processing configuration (workers, domains, SLA)
- Business metadata (cost center, business unit)
- Compliance requirements (GDPR, HIPAA, SOX)
- Audit trail (created by, modified by, timestamps)

---

## Schema Definition

### Core Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `company_id` | String | [DONE] | Unique identifier: `{pod_id}-{company}` |
| `pod_id` | String | [DONE] | Processing pod (podA, podB, podC) |
| `company` | String | [DONE] | Company/account name |
| `enabled` | Boolean | [DONE] | Process this company? |
| `worker_count` | Integer | [DONE] | Number of cluster workers (1-10) |
| `domains` | Array<String> | [DONE] | Data domains to process |

### Business Metadata

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `business_unit` | String | [ERROR] | Owning business unit |
| `cost_center` | String | [ERROR] | Cost center for chargeback |
| `data_classification` | String | [DONE] | PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED |
| `compliance_tags` | Array<String> | [ERROR] | GDPR, HIPAA, SOX, etc. |

### Processing SLA

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `sla_hours` | Integer | [DONE] | SLA for completion (hours) |
| `priority` | String | [DONE] | HIGH, MEDIUM, LOW |
| `max_retry_count` | Integer | [DONE] | Max retry attempts on failure |

### Cluster Configuration

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `driver_node_type` | String | [DONE] | Azure VM size for driver |
| `worker_node_type` | String | [DONE] | Azure VM size for workers |
| `autoscale_min_workers` | Integer | [ERROR] | Min workers for autoscaling |
| `autoscale_max_workers` | Integer | [ERROR] | Max workers for autoscaling |
| `spot_instances_enabled` | Boolean | [DONE] | Use Spot instances? |

### Data Volume Estimates

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `estimated_monthly_gb` | Double | [ERROR] | Monthly data volume (GB) |
| `estimated_monthly_rows` | Integer | [ERROR] | Monthly row count |

### Audit Trail

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `created_by` | String | [DONE] | User who created config |
| `created_at` | Timestamp | [DONE] | Creation timestamp |
| `modified_by` | String | [DONE] | User who last modified |
| `modified_at` | Timestamp | [DONE] | Last modification timestamp |
| `approval_status` | String | [DONE] | DRAFT, APPROVED, REJECTED |
| `approved_by` | String | [ERROR] | Approver name |
| `comments` | String | [ERROR] | Additional notes |
| `config_version` | String | [DONE] | Schema version |

---

## Enterprise Features

### 1. Change Data Feed (CDC)

Track all changes to configuration:

```sql
-- View all changes to company configurations
SELECT *
FROM table_changes('company_config', 0)
ORDER BY _commit_timestamp DESC;

-- See who modified the finance company config
SELECT _change_type, company_id, modified_by, modified_at, _commit_timestamp
FROM table_changes('company_config', 0)
WHERE company_id = 'podA-finance';
```

### 2. Time Travel

View historical configurations:

```sql
-- View config as it was yesterday
SELECT * FROM company_config VERSION AS OF 1;

-- View config at specific timestamp
SELECT * FROM company_config TIMESTAMP AS OF '2025-01-14T10:00:00';
```

### 3. Schema Evolution

Column mapping enabled for safe schema changes:

```sql
-- Add new column without breaking existing queries
ALTER TABLE company_config ADD COLUMN backup_enabled BOOLEAN DEFAULT false;
```

### 4. Auto-Optimization

Table automatically optimizes itself:
- Auto-compaction after writes
- Optimize write enabled
- Z-ordering on common query columns

### 5. Data Quality Validations

Built-in validations ensure data integrity:
- [DONE] No duplicate `company_id`
- [DONE] `worker_count` between 1-10
- [DONE] Non-empty `domains` array
- [DONE] Valid `priority` (HIGH, MEDIUM, LOW)
- [DONE] Valid `data_classification`
- [DONE] `autoscale_min_workers` ≤ `autoscale_max_workers`

---

## Configuration Standards

### Data Classification Levels

| Level | Description | Example Use Case | Spot Instances? |
|-------|-------------|------------------|-----------------|
| PUBLIC | Publicly available data | Marketing materials | [DONE] Yes |
| INTERNAL | Internal use only | Operations data | [DONE] Yes |
| CONFIDENTIAL | Business sensitive | Finance, Sales data | [DONE] Yes (with approval) |
| RESTRICTED | Highly regulated | HR, Compliance, PHI | [ERROR] No |

### Priority Levels

| Priority | SLA (Hours) | Use Case | Example |
|----------|-------------|----------|---------|
| HIGH | 2-4 | Mission-critical | Finance, Sales, HR |
| MEDIUM | 6-8 | Important but not urgent | Operations, Marketing |
| LOW | 12-24 | Nice-to-have | IT logs, Archive data |

### Worker Count Guidelines

| Workers | Data Volume | Monthly Rows | Use Case |
|---------|-------------|--------------|----------|
| 1 | < 50 GB | < 1M | Small companies, logs |
| 2 | 50-150 GB | 1M-5M | Standard companies |
| 3-4 | 150-300 GB | 5M-10M | Large companies, HR Central |
| 5+ | > 300 GB | > 10M | Very large, real-time |

### VM Type Selection

| Node Type | vCPUs | RAM | Use Case |
|-----------|-------|-----|----------|
| Standard_DS3_v2 | 4 | 14 GB | Standard workloads |
| Standard_DS4_v2 | 8 | 28 GB | Large workloads, sensitive data |
| Standard_DS5_v2 | 16 | 56 GB | Very large workloads |

---

## Usage Examples

### 1. Query All Enabled Companies for a Pod

```sql
-- ADF Lookup Activity Query
SELECT company_id, company, worker_count, domains, priority, sla_hours
FROM company_config
WHERE pod_id = 'podA' AND enabled = true
ORDER BY priority DESC, company;
```

### 2. Get High Priority Companies Only

```sql
SELECT pod_id, company, data_classification, sla_hours
FROM company_config
WHERE enabled = true AND priority = 'HIGH'
ORDER BY sla_hours;
```

### 3. Get Dynamic Cluster Configuration

```sql
-- For ADF Databricks activity
SELECT
    company_id,
    worker_node_type,
    autoscale_min_workers,
    autoscale_max_workers,
    spot_instances_enabled
FROM company_config
WHERE pod_id = @pipeline_pod_id AND enabled = true;
```

### 4. Cost Center Chargeback Report

```sql
SELECT
    business_unit,
    cost_center,
    COUNT(*) as company_count,
    SUM(estimated_monthly_gb) as total_gb_monthly,
    SUM(worker_count) as total_workers
FROM company_config
WHERE enabled = true
GROUP BY business_unit, cost_center
ORDER BY total_gb_monthly DESC;
```

### 5. Compliance Audit

```sql
-- Find all companies requiring GDPR compliance
SELECT company_id, business_unit, data_classification, compliance_tags
FROM company_config
WHERE enabled = true
  AND array_contains(compliance_tags, 'GDPR')
ORDER BY data_classification DESC;
```

---

## Maintenance Procedures

### Adding a New Company

```sql
INSERT INTO company_config VALUES (
    'podA-legal',                        -- company_id
    'podA',                              -- pod_id
    'legal',                             -- company
    true,                                -- enabled
    2,                                   -- worker_count
    array('hr', 'compliance', 'audit_logs'), -- domains
    'Legal',                             -- business_unit
    'CC-LEGAL-001',                      -- cost_center
    'RESTRICTED',                        -- data_classification
    array('SOX', 'GDPR'),                -- compliance_tags
    4,                                   -- sla_hours
    'HIGH',                              -- priority
    3,                                   -- max_retry_count
    'Standard_DS3_v2',                   -- driver_node_type
    'Standard_DS3_v2',                   -- worker_node_type
    2,                                   -- autoscale_min_workers
    4,                                   -- autoscale_max_workers
    false,                               -- spot_instances_enabled
    80.0,                                -- estimated_monthly_gb
    2000000,                             -- estimated_monthly_rows
    'admin@company.com',                 -- created_by
    current_timestamp(),                 -- created_at
    'admin@company.com',                 -- modified_by
    current_timestamp(),                 -- modified_at
    'APPROVED',                          -- approval_status
    'legal.director@company.com',        -- approved_by
    'Legal company data processing',     -- comments
    '1.0.0'                              -- config_version
);
```

### Disabling a Company (Pause Processing)

```sql
UPDATE company_config
SET
    enabled = false,
    modified_by = 'admin@company.com',
    modified_at = current_timestamp(),
    comments = 'Temporarily disabled for maintenance'
WHERE company_id = 'podA-marketing';
```

### Scaling Up a Company (More Workers)

```sql
UPDATE company_config
SET
    worker_count = 4,
    autoscale_max_workers = 6,
    modified_by = 'admin@company.com',
    modified_at = current_timestamp(),
    comments = 'Scaled up due to increased data volume'
WHERE company_id = 'podC-hr_central';
```

### Changing Priority

```sql
UPDATE company_config
SET
    priority = 'HIGH',
    sla_hours = 4,
    modified_by = 'admin@company.com',
    modified_at = current_timestamp(),
    comments = 'Elevated to HIGH priority per business request'
WHERE company_id = 'podB-sales';
```

### Archive History (Once Per Quarter)

```sql
-- Optimize table to reduce storage costs
OPTIMIZE company_config;

-- Vacuum old files (older than 30 days)
VACUUM company_config RETAIN 720 HOURS;
```

---

## Integration with ADF

### Step 1: ADF Lookup Activity

Configure Lookup activity in ADF pipeline:

**Activity Name**: `Get_Company_Config`

**Source Dataset**: Delta Lake Gen2
- **Linked Service**: `ls_datalake`
- **File System**: `gold`
- **Directory**: `config/companies`

**Query**:
```sql
SELECT company_id, company, worker_count, domains, priority,
       driver_node_type, worker_node_type,
       autoscale_min_workers, autoscale_max_workers,
       spot_instances_enabled
FROM delta.`abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/config/companies`
WHERE pod_id = '@{pipeline().parameters.pod_id}' AND enabled = true
ORDER BY priority DESC, company
```

**Settings**:
- ☐ First row only (unchecked - we want all rows)

### Step 2: ForEach Loop

**Items**: `@activity('Get_Company_Config').output.value`

This passes each company configuration to the loop.

### Step 3: Access Configuration in Activities

Inside ForEach activities, access company config:

```json
{
  "company": "@item().company",
  "worker_count": "@item().worker_count",
  "domains": "@item().domains"
}
```

### Step 4: Dynamic Cluster Specification

Use config to build job cluster JSON:

```json
{
  "new_cluster": {
    "spark_version": "13.3.x-scala2.12",
    "node_type_id": "@item().worker_node_type",
    "driver_node_type_id": "@item().driver_node_type",
    "autoscale": {
      "min_workers": "@item().autoscale_min_workers",
      "max_workers": "@item().autoscale_max_workers"
    },
    "azure_attributes": {
      "availability": "@if(equals(item().spot_instances_enabled, true), 'SPOT_AZURE', 'ON_DEMAND_AZURE')"
    }
  }
}
```

---

## Monitoring and Observability

### View Active Configurations

```sql
SELECT pod_id, company, priority, worker_count, sla_hours
FROM company_config
WHERE enabled = true
ORDER BY pod_id, priority DESC;
```

### Track Configuration Changes

```sql
-- View last 10 configuration changes
SELECT _change_type, company_id, modified_by, _commit_timestamp
FROM table_changes('company_config', 0)
ORDER BY _commit_timestamp DESC
LIMIT 10;
```

### Cost Estimation

```sql
-- Estimate monthly costs by company
SELECT
    company_id,
    business_unit,
    worker_count * 730 * 0.20 as estimated_monthly_cost_usd,
    estimated_monthly_gb
FROM company_config
WHERE enabled = true
ORDER BY estimated_monthly_cost_usd DESC;
```

---

## Security and Access Control

### Table-Level Security

```sql
-- Grant read access to ADF service principal
GRANT SELECT ON company_config TO 'adf-service-principal@company.com';

-- Grant write access to data engineers
GRANT SELECT, INSERT, UPDATE ON company_config TO 'data-engineers-group';

-- Revoke delete permission (use soft delete via enabled=false)
REVOKE DELETE ON company_config FROM 'data-engineers-group';
```

### Row-Level Security (Future Enhancement)

```sql
-- Create view with RLS for pod-specific access
CREATE OR REPLACE VIEW company_config_podA AS
SELECT * FROM company_config
WHERE pod_id = 'podA';

GRANT SELECT ON company_config_podA TO 'podA-team';
```

---

## Best Practices

### [DONE] DO

1. **Always set `modified_by` and `modified_at`** when updating
2. **Use `enabled=false` instead of DELETE** to preserve history
3. **Test changes with one company** before bulk updates
4. **Document changes in `comments` field**
5. **Get approval before changing RESTRICTED data configs**
6. **Run OPTIMIZE weekly** for query performance
7. **Monitor CDC feed** for unauthorized changes

### [ERROR] DON'T

1. **Don't delete rows** - Use `enabled=false` instead
2. **Don't bypass approval** for production changes
3. **Don't use spot instances** for RESTRICTED data
4. **Don't set SLA < 2 hours** without capacity planning
5. **Don't duplicate company_id**
6. **Don't leave approval_status as DRAFT** in production
7. **Don't modify schema** without version bump

---

## Troubleshooting

### Issue: ADF Can't Read Table

**Symptom**: Lookup activity fails with "Table not found"

**Solution**:
```sql
-- Verify table exists
DESCRIBE EXTENDED company_config;

-- Check path
SHOW CREATE TABLE company_config;

-- Grant permissions
GRANT SELECT ON company_config TO 'adf-principal';
```

### Issue: No Companies Returned

**Symptom**: ForEach loop has zero iterations

**Solution**:
```sql
-- Check if any enabled companies exist
SELECT COUNT(*) FROM company_config WHERE enabled = true;

-- Check specific pod
SELECT * FROM company_config WHERE pod_id = 'podA' AND enabled = true;
```

### Issue: Performance Degradation

**Symptom**: Lookup query taking > 5 seconds

**Solution**:
```sql
-- Optimize table
OPTIMIZE company_config ZORDER BY (pod_id, enabled, priority);

-- Vacuum old files
VACUUM company_config RETAIN 168 HOURS;

-- Check partition pruning is working
EXPLAIN SELECT * FROM company_config WHERE pod_id = 'podA';
```

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0.0 | 2025-01-15 | Initial enterprise schema | Data Engineering |

---

## Related Documentation

- [ADF Pipeline Orchestration Guide](./18-adf-pipeline-orchestration-company-level.md)
- [Shared Data Lake Module](./11-shared-data-lake-gen2-module.md)
- [Databricks Integration](./15-databricks-workspace.md)

---

## Support

For questions or issues with the company configuration table:
- **Team**: Data Engineering
- **Email**: data.engineering@company.com
- **Slack**: #data-platform-support
