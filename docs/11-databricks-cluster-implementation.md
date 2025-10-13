# Step 15: Creating Databricks Cluster Pools and Interactive Clusters

## What We're Building

In the previous step, we created a single shared Databricks workspace using Terraform. However, the workspace itself is just an empty shell. To actually process data, we need to create:

1. **Cluster Pools** (one per pod) - Pre-configured VM pools that reduce cluster startup time
2. **Interactive Clusters** (one per pod) - Always-on clusters for notebooks and ad-hoc analysis

The Azure Resource Manager (azurerm) Terraform provider can create the Databricks workspace, but it cannot create the actual compute resources inside that workspace. For that, we need to use either the Databricks UI, REST API, or the dedicated Databricks Terraform provider.

This guide walks through creating these resources manually in the Databricks UI. It's the simplest approach for getting started and understanding what's being created before potentially automating it later.

## Why Cluster Pools?

Databricks cluster pools are collections of idle, ready-to-use VMs. When you create a cluster from a pool, it starts in 30-60 seconds instead of 5-7 minutes because the VMs are already provisioned.

**Key Benefits:**
- **Faster Startup**: Clusters start immediately from pool VMs
- **Cost Control**: Set max capacity per pod to prevent runaway costs
- **Resource Isolation**: Each pod's pool is independent
- **Predictable Scaling**: Pre-configured VM types and Spark versions

For our architecture, each pod gets its own pool (podA-pool, podB-pool, podC-pool). This ensures Pod A's heavy workload can't consume all available VMs and starve Pod B.

## Prerequisites

Before you begin, make sure you have:

1. Successfully deployed the Databricks workspace using Terraform (Step 14)
2. Access to the Databricks workspace URL (get it with `terraform output databricks`)
3. Contributor or Owner role on the Databricks workspace resource
4. Azure subscription quota for Standard_DS3_v2 VMs (or your chosen VM type)

## Architecture Design

We'll create the following resources:

**Cluster Pools (3 total):**
- podA-pool
- podB-pool
- podC-pool

**Interactive Clusters (3 total):**
- podA-interactive (uses podA-pool)
- podB-interactive (uses podB-pool)
- podC-interactive (uses podC-pool)

Each cluster is configured with:
- **Autoscaling**: 1-3 worker nodes
- **Autotermination**: 20 minutes of idle time
- **Delta Lake support**: Enabled
- **Pod-specific tags**: For cost tracking and filtering

## Step 1: Access Your Databricks Workspace

First, get your workspace URL from Terraform outputs:

```bash
cd terraform/environments/dev
terraform output databricks
```

Look for the `workspace_url` value. It will look like:

```
adb-1234567890123456.12.azuredatabricks.net
```

Open a browser and navigate to:

```
https://<your-workspace-url>
```

You should see the Databricks workspace interface. If you get an access denied error, verify your Azure AD role assignment from Step 14.

## Step 2: Create Cluster Pool for podA

In the Databricks workspace:

1. Click **Compute** in the left sidebar
2. Click the **Pools** tab at the top
3. Click **Create Pool** button

Configure the pool with these settings:

**Basic Settings:**
- **Pool Name**: `podA-pool`
- **Min Idle Instances**: `0`
- **Max Capacity**: `10`

**Instance Configuration:**
- **Instance Type**: `Standard_DS3_v2` (4 cores, 14GB RAM)
- **Idle Instance Auto Termination**: `15` minutes

**Databricks Runtime Version:**
- Select: `13.3 LTS (includes Apache Spark 3.4.1, Scala 2.12)`

**Tags:**
Click **Add** to create these tags:
- `pod_id`: `podA`
- `environment`: `dev`
- `pool_type`: `general`

Click **Create Pool**.

The pool will appear in your Pools list within a few seconds. Note that no VMs are actually running yet since Min Idle Instances is 0.

## Step 3: Create Cluster Pool for podB

Repeat the same process for Pod B:

1. Click **Create Pool**
2. Configure with the same settings, but change:
   - **Pool Name**: `podB-pool`
   - **Tags**: Set `pod_id` to `podB`
3. Click **Create Pool**

## Step 4: Create Cluster Pool for podC

Repeat once more for Pod C:

1. Click **Create Pool**
2. Configure with the same settings, but change:
   - **Pool Name**: `podC-pool`
   - **Tags**: Set `pod_id` to `podC`
3. Click **Create Pool**

You should now have three cluster pools in the Pools tab.

## Step 5: Create Interactive Cluster for podA

Now we'll create the actual compute cluster that Pod A will use for data processing.

1. Click **Compute** in the left sidebar
2. Make sure you're on the **All-Purpose Clusters** tab
3. Click **Create Cluster**

Configure the cluster:

**Basic Settings:**
- **Cluster Name**: `podA-interactive`
- **Cluster Mode**: `Standard`
- **Pool**: Select `podA-pool` from dropdown

**Cluster Configuration:**
- **Databricks Runtime Version**: Will inherit from pool (13.3 LTS)
- **Enable Autoscaling**: Check this box
- **Workers**: Min `1`, Max `3`
- **Terminate After**: `20` minutes of inactivity

**Advanced Options:**
Click **Advanced Options** to expand, then go to the **Spark** tab.

In the **Spark Config** text area, add:

```
spark.databricks.delta.preview.enabled true
spark.sql.adaptive.enabled true
spark.databricks.cluster.profile singleNode
```

These settings enable Delta Lake preview features, adaptive query execution, and optimize for single-node mode when only one worker is active.

**Tags:**
Click **Add** in the Tags section to create:
- `pod_id`: `podA`
- `workload`: `interactive`
- `environment`: `dev`
- `cost_center`: `podA`

Click **Create Cluster**.

The cluster will start immediately. Since it's using the pool, it should reach "Running" state in 30-60 seconds. You'll see a green indicator when ready.

## Step 6: Create Interactive Cluster for podB

Repeat the cluster creation process for Pod B:

1. Click **Create Cluster**
2. Configure with the same settings, but change:
   - **Cluster Name**: `podB-interactive`
   - **Pool**: Select `podB-pool`
   - **Tags**: Set `pod_id` and `cost_center` to `podB`
3. Click **Create Cluster**

## Step 7: Create Interactive Cluster for podC

Repeat one more time for Pod C:

1. Click **Create Cluster**
2. Configure with the same settings, but change:
   - **Cluster Name**: `podC-interactive`
   - **Pool**: Select `podC-pool`
   - **Tags**: Set `pod_id` and `cost_center` to `podC`
3. Click **Create Cluster**

## Step 8: Verify All Clusters Are Running

Go back to the **All-Purpose Clusters** tab. You should see:

```
podA-interactive    Running    Pool: podA-pool
podB-interactive    Running    Pool: podB-pool
podC-interactive    Running    Pool: podC-pool
```

All three clusters should show a green "Running" indicator. If any show errors, check the cluster event log by clicking on the cluster name.

## Step 9: Test Data Lake Access from podA Cluster

Now let's verify that the Databricks clusters can access our Data Lake.

1. Click **Workspace** in the left sidebar
2. Click **Create** → **Notebook**
3. Name it: `Test Data Lake Access`
4. Language: `Python`
5. Cluster: Select `podA-interactive`
6. Click **Create**

In the first cell, add this code (replace `<storage-account-name>` with your actual Data Lake storage account name from terraform output):

```python
# Get storage account name
storage_account = "<storage-account-name>"

# Test listing bronze layer for podA
dbutils.fs.ls(f"abfss://bronze@{storage_account}.dfs.core.windows.net/podA/")
```

Run the cell (Shift + Enter or click the Run button).

If successful, you'll see a list of directories in the podA bronze layer (hr/, payroll/, finance/).

If you get an access denied error, the managed identity RBAC permissions may not have propagated yet. Wait 5 minutes and restart the cluster, then try again.

## Step 10: Test Write Access

Add a second cell to test write permissions:

```python
# Create a simple test DataFrame
from pyspark.sql import Row

test_data = [
    Row(test_id=1, message="Cluster write test successful"),
    Row(test_id=2, message="RBAC permissions working")
]

test_df = spark.createDataFrame(test_data)

# Write to bronze layer
test_path = f"abfss://bronze@{storage_account}.dfs.core.windows.net/podA/cluster_test/"

test_df.write.format("delta").mode("overwrite").save(test_path)

print(f"Test data written successfully to {test_path}")
```

Run this cell. If successful, you'll see the success message.

Verify the data was written by reading it back:

```python
# Read the test data back
verify_df = spark.read.format("delta").load(test_path)
display(verify_df)
```

You should see your two test rows displayed in a table.

## Step 11: Verify Cost Tracking Tags

To make sure our cost tracking tags are working:

1. Go to the Azure Portal
2. Navigate to **Cost Management + Billing**
3. Click **Cost Analysis**
4. Add a filter: Tag → pod_id → Select `podA`

You should see Databricks compute costs associated with the podA cluster. This confirms that cost allocation by pod is working correctly.

## Troubleshooting

### Issue: Cluster Fails to Start - Quota Exceeded

**Error Message**:
```
Azure quota exceeded: The current VM usage plus the requested increase exceeds the approved quota
```

**What This Means**: Your Azure subscription doesn't have enough quota for Standard_DS3_v2 VMs in your region.

**Solution**:

Option 1 - Request quota increase:
```bash
az vm list-usage --location eastus --output table | grep DSv3
```

If usage is at limit, submit a quota increase request in the Azure Portal (Support → New Support Request → Service and subscription limits).

Option 2 - Use a different VM size:

1. Delete the cluster pool
2. Create a new pool with a different instance type (e.g., Standard_DS4_v2 or Standard_D4s_v3)
3. Recreate the cluster

### Issue: Access Denied When Listing Storage

**Error Message**:
```
java.io.IOException: No credentials found for account <storage-account>.dfs.core.windows.net
```

**Solution**:

The Databricks managed identity might not have the Storage Blob Data Contributor role yet, or RBAC permissions haven't propagated.

Check if the role assignment exists:

```bash
az role assignment list \
  --scope "/subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.Storage/storageAccounts/<storage-account-name>" \
  --query "[?principalType=='ServicePrincipal'].{Role:roleDefinitionName, Principal:principalId}" \
  --output table
```

If you don't see the Databricks workspace identity with "Storage Blob Data Contributor" role:

```bash
# Get workspace identity
WORKSPACE_IDENTITY=$(az databricks workspace show \
  --name dbw-dev-platform \
  --resource-group rg-platform-dev \
  --query "storageAccountIdentity.principalId" -o tsv)

# Assign role
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee-object-id $WORKSPACE_IDENTITY \
  --scope "<storage-account-resource-id>"
```

Wait 5 minutes, then restart the cluster.

### Issue: Cluster Terminates Immediately

**Symptom**: Cluster shows "Running" for a few seconds, then "Terminated".

**Solution**:

Click on the cluster name and check the **Event Log** tab. Common causes:

1. **Init script failure** - If you configured init scripts, one might be failing
2. **Spark config error** - Check your Spark config for typos
3. **Network connectivity** - The cluster VMs can't reach Azure services

For Spark config issues, try removing all custom Spark configs and recreating the cluster with defaults first.

## Best Practices

### When to Use Interactive Clusters vs Job Clusters

**Interactive Clusters** (what we just created):
- Best for: Notebooks, ad-hoc queries, development
- Kept alive for 20 minutes after last use
- Costs accrue while idle within that 20-minute window
- Perfect for exploratory data analysis

**Job Clusters** (future enhancement):
- Best for: Scheduled ETL jobs, production pipelines
- Start when job runs, terminate immediately after
- Zero idle time costs
- Cannot be used for interactive notebooks

For production workloads, you'll want to create separate job clusters that auto-terminate.

### Cost Optimization Tips

1. **Set Autotermination**: Always configure the 20-minute timeout. Without it, clusters run 24/7.

2. **Use Autoscaling**: Don't overprovision workers. Let autoscaling add workers only when needed.

3. **Start With Small Pools**: Max capacity of 10 is generous for dev. Consider reducing to 5.

4. **Monitor Idle Clusters**: Set up Azure Monitor alerts for clusters idle > 15 minutes.

5. **Use Spot Instances** (for non-critical workloads): Edit pool settings → Enable spot instances for 60-90% cost reduction.

## Summary

You've successfully created the Databricks compute infrastructure for your multi-pod data platform:

**What we accomplished:**
- Created 3 cluster pools (podA-pool, podB-pool, podC-pool)
- Created 3 interactive clusters (podA-interactive, podB-interactive, podC-interactive)
- Verified Data Lake access using managed identity authentication
- Confirmed cost tracking tags are working
- Tested read and write operations to the bronze layer

**What's next:**

In the next steps, we'll create Data Factory pipelines that:
1. Detect when CSV files land in blob storage
2. Copy them to the Data Lake bronze layer
3. Trigger Databricks notebooks to process the data
4. Move cleansed data through silver to gold layers

Each pod's pipeline will be isolated, but they'll all share the same infrastructure for cost efficiency.

The clusters you created will automatically start when triggered by Data Factory jobs and shut down after 20 minutes of inactivity, keeping costs low while maintaining fast response times.
