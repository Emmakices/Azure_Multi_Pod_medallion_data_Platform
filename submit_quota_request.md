# Submit Azure Quota Increase Request

## Your Current Status

- **Subscription**: Azure subscription 1
- **Subscription ID**: e97fa8c6-457d-495f-aa82-0d87e72f5842
- **Region**: East US
- **Current DSv2 Quota**: 10 vCPUs
- **Currently Used**: 0 vCPUs
- **Needed**: 24 vCPUs

## Problem

10 vCPU limit is insufficient for Databricks:
- Standard_DS3_v2 = 4 vCPUs per node
- 1 cluster needs: 1 driver (4 vCPUs) + 2 workers (8 vCPUs) = 12 vCPUs
- Current limit of 10 vCPUs < 12 vCPUs needed

## Quick Submit (3 clicks)

### Method 1: Direct Portal Link (FASTEST)

Click this link to open the quota request form:

https://portal.azure.com/#view/Microsoft_Azure_Support/NewSupportRequestV3Blade/issueType/quota/subscriptionId/e97fa8c6-457d-495f-aa82-0d87e72f5842/topicId/1135fc8b-7c8a-b425-04b7-850b8e4a5ab7

**Then fill in**:
1. Quota type: **Compute-VM (cores-vCPUs)**
2. Click **Next**
3. Region: **East US**
4. VM series: **DSv2 Series**
5. New limit: **24**
6. Click **Next**
7. Review and click **Create**

### Method 2: Manual Portal Navigation

1. Open: https://portal.azure.com
2. Search for **Quotas** in the top search bar
3. Click **Compute** on the left
4. Find **Standard DSv2 Family vCPUs**
5. Filter by **East US** region
6. Click on the quota line
7. Click **Request adjustment**
8. Enter new limit: **24**
9. Business justification:
```
Requesting quota increase for Azure Databricks data platform deployment.
Use case: Company-level data processing with ephemeral job clusters.
Requirements:
- Multiple small clusters (Standard_DS3_v2: 4 vCPUs each)
- Job clusters that auto-terminate after processing
- Peak usage: 2-3 clusters simultaneously
- Total vCPU needed: 24 for parallel company processing
Current limit (10 vCPUs) is insufficient for single cluster (12 vCPUs needed).
```
10. Click **Submit**

## After Submission

- **Check status**: Portal → Support → My support requests
- **Timeline**: Usually approved within 1-2 business days
- **Notification**: You'll receive email confirmation

## What to Do While Waiting

You can continue with ADF pipeline configuration:
1. Create datasets (Steps 8-9 in guide)
2. Set up pipeline structure (Step 10-11)
3. Create the Databricks notebooks locally

Once quota is approved, you'll be able to:
1. Upload notebooks to Databricks
2. Run the company config table creation
3. Test the full pipeline

## Alternative: Use Different Region

If East US quota is limited, you could redeploy to a region with more capacity:
- **West US 2** (usually high availability)
- **Central US** (good availability)
- **West Europe** (alternative)

To check other regions:
```bash
az vm list-usage --location westus2 --query "[?contains(name.value, 'standardDSv2Family')]" --output table
```

## Need Help?

If quota request is denied or taking too long:
1. Open Support ticket: Portal → Help + support → New support request
2. Issue type: Service and subscription limits (quotas)
3. Priority: Moderate or High (based on urgency)
