# Azure Databricks Quota Increase Request Guide

## Current Issue

Azure Databricks clusters cannot start due to quota limits:
```
AZURE_QUOTA_EXCEEDED_EXCEPTION: Your subscription doesn't have enough quota for Standard_DS3_v2 in East US region
```

## Solution: Request Quota Increase

### Step 1: Open Azure Portal

1. Go to: https://portal.azure.com
2. In the search bar, type: **Quotas**
3. Click on **Quotas** service

### Step 2: Find Databricks Quota

1. In the Quotas page, click **Compute**
2. Filter by:
   - **Provider**: Microsoft.Compute
   - **Region**: East US (or your region)
   - **Resource**: Search for "Standard DSv2 Family vCPUs" or "Total Regional vCPUs"

### Step 3: Request Increase

1. Click on the quota you want to increase
2. Click **Request adjustment** or **New Quota Request**
3. Fill in the form:

**Deployment model**: Resource Manager

**Location**: East US (or your deployment region)

**VM series**: DSv2-series

**New vCPU limit**:
- Current: 0 or low number
- Requested: **24** (allows multiple small clusters)
  - 1 driver (4 vCPUs) + 2 workers (4 vCPUs each) = 12 vCPUs per cluster
  - 24 vCPUs allows 2 clusters running simultaneously

**Business justification**:
```
Requesting quota increase for Azure Databricks data platform deployment.
Use case: Company-level data processing with ephemeral job clusters
Requirements:
- Multiple small clusters (Standard_DS3_v2: 4 vCPUs, 14 GB RAM)
- Job clusters that auto-terminate after processing
- Peak usage: 2-3 clusters running simultaneously
- Total vCPU needed: 24 (6 clusters worth for parallel processing)
```

4. Click **Submit**

### Step 4: Wait for Approval

- **Timeline**: Usually 1-2 business days
- **Notification**: Email when approved
- **Status**: Check in Azure Portal → Support → My support requests

## Alternative: Use Smaller VM Type

While waiting for quota approval, try smaller VMs that might have available quota:

### Option 1: Standard_D4s_v3 (4 vCPUs)
```json
{
  "node_type_id": "Standard_D4s_v3",
  "num_workers": 1
}
```

### Option 2: Standard_D4ds_v4 (4 vCPUs - newer generation)
```json
{
  "node_type_id": "Standard_D4ds_v4",
  "num_workers": 1
}
```

### Option 3: Use Single-Node Cluster (No Workers)
```json
{
  "node_type_id": "Standard_DS3_v2",
  "num_workers": 0,
  "spark_conf": {
    "spark.databricks.cluster.profile": "singleNode",
    "spark.master": "local[*]"
  },
  "custom_tags": {
    "ResourceClass": "SingleNode"
  }
}
```

## Check Current Quota Usage

Run this Azure CLI command:

```bash
az vm list-usage --location eastus --output table | grep "Standard DSv2"
```

Output shows:
```
Current usage / Limit
```

## After Quota Increase

Once approved, your clusters should start successfully. Test by:

1. Starting interactive cluster in Databricks
2. Running company config table creation notebook
3. Testing ADF pipeline with job cluster

## Support

If quota request is denied or taking too long:
- Open Azure Support ticket
- Category: Billing & Subscription Management
- Issue type: Increase compute-quota limit
- Priority: Based on urgency

## Cost Considerations

**24 vCPU quota** for Standard_DS3_v2:
- Price: ~$0.27/hour per node
- Job cluster cost: ~$0.81/hour (1 driver + 2 workers)
- With auto-termination (10 min): ~$0.14 per job
- 100 jobs/month: ~$14/month

**Much cheaper than always-on clusters** which would cost $583/month (24/7 operation).
