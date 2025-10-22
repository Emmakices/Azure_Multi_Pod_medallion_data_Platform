# ADF Pipeline Configuration for Pod-Specific Notebooks

**Document Version**: 1.0
**Last Updated**: January 16, 2025
**Purpose**: Configure ADF to call pod-specific notebooks dynamically

---

## Overview

This document explains how to configure Azure Data Factory pipeline to dynamically call pod-specific notebooks instead of shared universal notebooks.

**Key Change**: Notebook paths are constructed dynamically based on `pod_id` parameter.

---

## Dynamic Notebook Path

### Old Approach (Shared Universal Notebooks)

```json
{
    "notebook_path": "/Shared/shared_notebooks/bronze_to_silver_universal"
}
```

**Problem**: All pods use the same notebook with no customization.

### New Approach (Pod-Specific Notebooks)

```json
{
    "notebook_path": "@{concat('/Shared/', pipeline().parameters.pod_id, '/bronze_to_silver')}"
}
```

**Result**:
- `pod_id = "podA"` → `/Shared/podA/bronze_to_silver`
- `pod_id = "podB"` → `/Shared/podB/bronze_to_silver`
- `pod_id = "podC"` → `/Shared/podC/bronze_to_silver`

**Benefits**: Each pod team maintains their own transformation logic.

---

## Updated Pipeline Activities

### Step 17: Submit Bronze to Silver Job

**Activity Type**: Web Activity

**Name**: `Submit_Bronze_to_Silver_Job`

**Method**: POST

**URL**:
```
@{concat('https://adb-3370863217573312.12.azuredatabricks.net/api/2.0/jobs/runs/submit')}
```

**Headers**:
```json
{
    "Authorization": "Bearer YOUR_DATABRICKS_TOKEN_HERE",
    "Content-Type": "application/json"
}
```

**Body** (Updated with dynamic pod path):
```json
{
    "run_name": "@{concat('BronzeToSilver_', pipeline().parameters.pod_id, '_', item().company, '_', item().domain, '_', pipeline().RunId)}",
    "new_cluster": {
        "spark_version": "13.3.x-scala2.12",
        "node_type_id": "Standard_D4s_v3",
        "num_workers": 2,
        "autotermination_minutes": 10,
        "custom_tags": {
            "pod": "@{pipeline().parameters.pod_id}",
            "company": "@{item().company}",
            "domain": "@{item().domain}",
            "stage": "bronze_to_silver",
            "owner": "@{concat(pipeline().parameters.pod_id, '_team')}"
        }
    },
    "notebook_task": {
        "notebook_path": "@{concat('/Shared/', pipeline().parameters.pod_id, '/bronze_to_silver')}",
        "base_parameters": {
            "pod_id": "@{pipeline().parameters.pod_id}",
            "company": "@{item().company}",
            "domain": "@{item().domain}",
            "storage_account": "@{pipeline().parameters.storage_account}"
        }
    }
}
```

**Key Changes**:
- `notebook_path`: Dynamic path based on pod_id
- `custom_tags`: Added owner tag for cost tracking
- `run_name`: Includes pod_id for clarity

---

### Step 19: Submit Silver to Gold Job

**Activity Type**: Web Activity

**Name**: `Submit_Silver_to_Gold_Job`

**Method**: POST

**URL**:
```
@{concat('https://adb-3370863217573312.12.azuredatabricks.net/api/2.0/jobs/runs/submit')}
```

**Headers**:
```json
{
    "Authorization": "Bearer YOUR_DATABRICKS_TOKEN_HERE",
    "Content-Type": "application/json"
}
```

**Body** (Updated with dynamic pod path):
```json
{
    "run_name": "@{concat('SilverToGold_', pipeline().parameters.pod_id, '_', item().company, '_', item().domain, '_', pipeline().RunId)}",
    "new_cluster": {
        "spark_version": "13.3.x-scala2.12",
        "node_type_id": "Standard_D4s_v3",
        "num_workers": 2,
        "autotermination_minutes": 10,
        "custom_tags": {
            "pod": "@{pipeline().parameters.pod_id}",
            "company": "@{item().company}",
            "domain": "@{item().domain}",
            "stage": "silver_to_gold",
            "owner": "@{concat(pipeline().parameters.pod_id, '_team')}"
        }
    },
    "notebook_task": {
        "notebook_path": "@{concat('/Shared/', pipeline().parameters.pod_id, '/silver_to_gold')}",
        "base_parameters": {
            "pod_id": "@{pipeline().parameters.pod_id}",
            "company": "@{item().company}",
            "domain": "@{item().domain}",
            "storage_account": "@{pipeline().parameters.storage_account}"
        }
    }
}
```

**Key Changes**:
- `notebook_path`: Dynamic path based on pod_id
- `custom_tags`: Added owner tag for cost tracking
- `run_name`: Includes pod_id for clarity

---

### Step 16b: Check Bronze Completeness (No Change)

**This remains in shared utilities** as it's common to all pods.

```json
{
    "notebook_path": "/Shared/shared_notebooks/check_bronze_completeness"
}
```

**Reason**: Completeness check logic is identical for all pods.

---

## Complete Pipeline Structure

```
Pipeline: MultiPod_DataLake_Orchestration

Parameters:
├─ pod_id: "podA" | "podB" | "podC"
└─ storage_account: "stdldevshared77b5h3"

Activities:
1. Get_Company_Config (Databricks job)
   ├─ Reads: gold/config/companies/
   └─ Returns: Company metadata for the pod

2. ForEach_Company (parallel: 4 companies)
   ├─ Check_Data_Exists (landing zone)
   └─ If_Has_Data:
       ├─ Copy_All_Files_to_Bronze (wildcard *)
       ├─ Archive_All_Files
       ├─ Check_Bronze_Completeness (shared utility)
       ├─ Poll for Completeness
       └─ If_Complete:
           └─ ForEach_Domain (parallel: all domains):
               ├─ Submit_Bronze_to_Silver_Job
               │   └─ Calls: /Shared/{pod_id}/bronze_to_silver
               ├─ Poll Bronze→Silver
               ├─ Submit_Silver_to_Gold_Job
               │   └─ Calls: /Shared/{pod_id}/silver_to_gold
               └─ Poll Silver→Gold
```

---

## Execution Examples

### Example 1: podA Finance Processing

**Pipeline Trigger**: File uploaded to `landing/podA/finance/`

**Parameters**:
- `pod_id`: "podA"
- `storage_account`: "stdldevshared77b5h3"

**Execution Flow**:
1. Get_Company_Config → Returns Finance company with domains: ["hr", "payroll"]
2. Check_Bronze_Completeness → COMPLETE (both files present)
3. ForEach_Domain: "hr"
   - Submit_Bronze_to_Silver_Job
     - Notebook: `/Shared/podA/bronze_to_silver`
     - Parameters: pod_id=podA, company=finance, domain=hr
   - Submit_Silver_to_Gold_Job
     - Notebook: `/Shared/podA/silver_to_gold`
     - Parameters: pod_id=podA, company=finance, domain=hr
4. ForEach_Domain: "payroll"
   - Submit_Bronze_to_Silver_Job
     - Notebook: `/Shared/podA/bronze_to_silver`
     - Parameters: pod_id=podA, company=finance, domain=payroll
   - Submit_Silver_to_Gold_Job
     - Notebook: `/Shared/podA/silver_to_gold`
     - Parameters: pod_id=podA, company=finance, domain=payroll

**Result**:
- podA team's custom transformation logic applied
- podA-specific HR and Payroll metrics created
- Cost tracked with owner: "podA_team"

---

### Example 2: podB Sales Processing

**Pipeline Trigger**: File uploaded to `landing/podB/sales/`

**Parameters**:
- `pod_id`: "podB"
- `storage_account`: "stdldevshared77b5h3"

**Execution Flow**:
1. Get_Company_Config → Returns Sales company with domains: ["customers", "orders"]
2. Check_Bronze_Completeness → COMPLETE
3. ForEach_Domain: "customers"
   - Notebook: `/Shared/podB/bronze_to_silver` (podB team's logic)
   - Notebook: `/Shared/podB/silver_to_gold` (podB team's metrics)
4. ForEach_Domain: "orders"
   - Notebook: `/Shared/podB/bronze_to_silver` (podB team's logic)
   - Notebook: `/Shared/podB/silver_to_gold` (podB team's metrics)

**Result**:
- podB team's custom transformation logic applied
- podB-specific Sales metrics created
- Cost tracked with owner: "podB_team"

---

## Cost Tracking with Custom Tags

**Cluster Tags Configuration**:

```json
{
    "pod": "podA",
    "company": "finance",
    "domain": "hr",
    "stage": "bronze_to_silver",
    "owner": "podA_team",
    "environment": "dev"
}
```

**Azure Cost Analysis Queries**:

1. **Cost per Pod**:
   - Filter by tag: `pod = "podA"`
   - Result: Total cost for all podA processing

2. **Cost per Company**:
   - Filter by tag: `company = "finance"`
   - Result: Total cost for Finance company across all pods

3. **Cost per Domain**:
   - Filter by tag: `domain = "hr"`
   - Result: Total cost for HR domain processing

4. **Cost per Team**:
   - Filter by tag: `owner = "podA_team"`
   - Result: Total cost attributed to podA team

5. **Cost per Stage**:
   - Filter by tag: `stage = "bronze_to_silver"`
   - Result: Total cost for Bronze→Silver transformations

**Benefits**:
- Chargeback to pod teams
- Identify expensive domains
- Optimize high-cost transformations
- Budget planning per team

---

## Testing Pod-Specific Notebooks

### Test Plan

**1. Test podA Finance HR**:
```bash
# Upload test file
az storage blob upload \
    --account-name stdldevshared77b5h3 \
    --container-name landing \
    --name podA/finance/hr_test.csv \
    --file test_data/hr_sample.csv

# Trigger pipeline with pod_id=podA
# Verify: /Shared/podA/bronze_to_silver called
# Verify: podA-specific HR logic applied
# Verify: Custom tags present in cluster
```

**2. Test podB Sales Customers**:
```bash
# Upload test file
az storage blob upload \
    --account-name stdldevshared77b5h3 \
    --container-name landing \
    --name podB/sales/customers_test.csv \
    --file test_data/customers_sample.csv

# Trigger pipeline with pod_id=podB
# Verify: /Shared/podB/bronze_to_silver called
# Verify: podB-specific customer logic applied
```

**3. Validate Isolation**:
- Change podA notebook → Only podA pipelines affected
- Run podB pipeline → No impact from podA changes
- Verify separate Silver/Gold tables per pod

---

## Rollback Strategy

If you need to rollback to shared universal notebooks:

**1. Update ADF Pipeline Bodies**:
```json
{
    "notebook_path": "/Shared/shared_notebooks/bronze_to_silver_universal"
}
```

**2. Redeploy Pipeline**:
```bash
az datafactory pipeline update \
    --resource-group rg-delta-lake-dev \
    --factory-name adf-delta-lake-dev \
    --name MultiPod_DataLake_Orchestration \
    --pipeline @pipeline.json
```

**3. Verify**:
- Check pipeline runs use shared notebooks
- Cost tags still work (just owner won't be pod-specific)

---

## Migration Checklist

- [ ] Review new pod-specific notebooks in Databricks workspace
- [ ] Customize podA notebooks for Finance business rules
- [ ] Customize podB notebooks for Sales business rules
- [ ] Customize podC notebooks for HR Central business rules
- [ ] Update ADF pipeline JSON with dynamic notebook paths
- [ ] Update custom tags configuration
- [ ] Test podA pipeline with sample data
- [ ] Test podB pipeline with sample data
- [ ] Test podC pipeline with sample data
- [ ] Verify cost tags appear in Azure Cost Management
- [ ] Run parallel testing (old vs new notebooks)
- [ ] Compare outputs for consistency
- [ ] Enable pod-specific notebooks in production
- [ ] Monitor for 1 week
- [ ] Deprecate old shared universal notebooks
- [ ] Update documentation with lessons learned

---

## Troubleshooting

### Issue: Notebook Not Found

**Error**: `Notebook /Shared/podA/bronze_to_silver does not exist`

**Solution**:
1. Verify notebook uploaded to Databricks
2. Check exact path (case-sensitive)
3. Verify pod_id parameter passed correctly
4. Check ADF dynamic expression syntax

**Verification**:
```python
# In Databricks workspace
%sh
databricks workspace ls /Shared/podA
```

### Issue: Wrong Notebook Called

**Error**: podB data processed by podA notebook

**Solution**:
1. Verify pipeline parameter: `pod_id` correctly set
2. Check ADF expression: `@{concat('/Shared/', pipeline().parameters.pod_id, '/bronze_to_silver')}`
3. Review pipeline run history to see actual path used

### Issue: Custom Logic Not Applied

**Error**: Generic transformation instead of pod-specific rules

**Solution**:
1. Check notebook code has domain-specific if/elif blocks
2. Verify `domain` parameter passed correctly
3. Review notebook output logs for which branch executed
4. Test notebook manually with correct parameters

---

## Summary

**Enterprise Architecture Achieved**:
- Pod-specific notebooks with dynamic path construction
- Clear ownership per pod team
- Business-specific customization
- Cost tracking per pod/company/domain/owner
- Isolation and independence between pods
- Scalable to any number of pods

**Next Steps**:
1. Review and customize pod-specific notebooks
2. Update ADF pipeline with dynamic paths
3. Test with sample data
4. Deploy to production
5. Monitor cost tags
6. Train pod teams on their notebooks

This configuration is production-ready and follows enterprise best practices for multi-tenant data platforms with clear governance and ownership.
