# Create Databricks Cluster - Step by Step Guide

## Access Databricks Workspace

1. Open: https://adb-3370863217573312.12.azuredatabricks.net
2. Sign in with your Azure credentials

## Create New Cluster

### Step 1: Navigate to Compute

1. In the left sidebar, click **Compute** (lightning bolt icon)
2. Click **Create Cluster** button at the top

### Step 2: Basic Configuration

**Cluster name**: `config-query-cluster`

**Cluster mode**:
- Select **Single Node** (this uses fewer resources and might work with your quota)

**Databricks runtime version**:
- Select **13.3 LTS (Scala 2.12, Spark 3.4.1)** (recommended for stability)
- Or latest LTS version available

### Step 3: Node Configuration (Single Node)

**Node type**:
Try these in order (from smallest to largest):

**Option 1: Standard_DS3_v2** (4 cores, 14 GB RAM)
- Most cost-effective
- Good for config queries
- May hit quota limit

**Option 2: Standard_D4s_v3** (4 cores, 16 GB RAM)
- Slightly newer generation
- May have better quota availability

**Option 3: Standard_D4ds_v4** (4 cores, 16 GB RAM)
- Newest generation
- Often has more quota available

**Option 4: Standard_F4s_v2** (4 cores, 8 GB RAM)
- Compute-optimized
- Different quota pool (might work!)

### Step 4: Advanced Options (Click to Expand)

**Auto Termination**:
- Check the box
- Set to: **15 minutes** (cluster stops when idle)

**Spark Config** (for Single Node):
```
spark.databricks.cluster.profile singleNode
spark.master local[*]
```

**Tags** (optional but recommended):
```
Project: data-platform
Purpose: config-query
CostCenter: analytics
```

### Step 5: Create Cluster

1. Review configuration
2. Click **Create Cluster** button
3. Wait 3-5 minutes for cluster to start

## If Cluster Fails to Start

### Check the Error Message

1. Look at the cluster status
2. Read the error message carefully

**Common Errors**:

#### Error 1: Quota Exceeded
```
AZURE_QUOTA_EXCEEDED_EXCEPTION
```

**Solution**: Try different VM type (Option 2, 3, or 4 above)

#### Error 2: Resource Stockout
```
CLOUD_PROVIDER_RESOURCE_STOCKOUT
```

**Solution**:
- Wait 10 minutes and retry
- Or try different VM type

#### Error 3: Configuration Error
```
Invalid configuration
```

**Solution**:
- Remove Spark Config (if not using Single Node)
- Or ensure Single Node spark config is correct

## Verify Cluster is Running

When successful, you should see:
- **Status**: Green circle with "Running"
- **Spark UI** button is clickable
- **Notebooks** can be attached to this cluster

## Test the Cluster

1. Click **Create** → **Notebook** in left sidebar
2. Name: `test_cluster`
3. Attach to: `config-query-cluster`
4. Run this code:

```python
# Test basic functionality
print("Cluster is working!")
print(f"Spark version: {spark.version}")
print(f"Available cores: {sc.defaultParallelism}")

# Test Delta Lake access
df = spark.range(10)
print(f"Created test DataFrame with {df.count()} rows")
```

5. If all cells run successfully, cluster is ready!

## Recommended Configuration for Your Use Case

**For Company Config Query** (minimal resources needed):
```
Cluster name: config-query-cluster
Mode: Single Node
Runtime: 13.3 LTS
Node type: Standard_F4s_v2 (try this first - different quota!)
Workers: 0 (Single Node)
Auto-termination: 15 minutes
```

**Cost**: ~$0.15-0.25/hour (only while running)
With auto-termination, costs are minimal.

## Next Steps After Cluster Starts

1. Upload company config notebook
2. Create company configuration table
3. Test ADF integration

## Troubleshooting Commands

Check available VM types in your region:
```bash
az vm list-skus --location eastus --size Standard_D --output table | grep -i "4 vcpus"
```

Check quota for different VM families:
```bash
az vm list-usage --location eastus --output table | grep -i standard
```
