# Step 13: Shared Data Factory Module with Parameterized Pipeline Architecture

## Overview

In this step, we create a Data Factory module that fundamentally changes how orchestration works in a multi-pod data platform. Instead of deploying separate Azure Data Factory instances for each pod (the old architecture), we deploy a single shared Data Factory that handles workloads for all pods through parameterized pipelines.

This architectural shift reduces costs, simplifies operations, and introduces the concept of dynamic pipeline routing where the same pipeline code can process data for different pods by simply passing different parameters.

## Why Share a Single Data Factory Across Pods?

### The Old Per-Pod Architecture Problem

In the previous architecture, each pod had its own dedicated Azure Data Factory instance:

```
Pod A: adf-poda-dev
Pod B: adf-podb-dev
Pod C: adf-podc-dev
```

This seemed like good isolation, but it created several problems:

**Cost Multiplication**: Azure Data Factory has a base cost per instance. Three instances mean paying three times the base cost, even if the pipelines are identical.

**Configuration Duplication**: Every pipeline, dataset, linked service, and trigger had to be created three times with only minor differences (pod-specific folder paths).

**Maintenance Overhead**: When you need to update a pipeline, you have to update it in three places. This gets worse as you add more pods.

**Deployment Complexity**: CI/CD pipelines become complicated when managing multiple ADF instances with nearly identical code.

**Monitoring Fragmentation**: You have to monitor three separate ADF instances, making it harder to get a unified view of data processing across the platform.

### The New Shared Architecture Solution

The new architecture uses a single Data Factory instance with parameterized pipelines:

```
adf-dev-platform (single instance)
  Pipeline: Copy_SourceBlob_To_Bronze
    Parameters: pod_id, domain
    Source: @concat('hr-landing/', pipeline().parameters.pod_id, '/')
    Destination: @concat('bronze/', pipeline().parameters.pod_id, '/hr/')
```

When you execute this pipeline:
- With pod_id = "podA", it processes Pod A's data
- With pod_id = "podB", it processes Pod B's data
- With pod_id = "podC", it processes Pod C's data

Same code, different execution paths. This is the power of parameterization.

**Benefits of Shared Model**:

**Cost Reduction**: One Data Factory instance instead of three reduces base costs by 66%.

**Single Source of Truth**: One pipeline definition that works for all pods. Update once, affects all.

**Simplified Operations**: Monitor one ADF instance instead of three. Fewer resources to manage.

**Easier Scaling**: Adding Pod D doesn't require deploying a new ADF instance, just passing "podD" as a parameter.

**Unified Monitoring**: All pipeline runs appear in the same Log Analytics workspace with pod_id as a dimension for filtering.

## Understanding Managed Identity Authentication

This module introduces a critical security concept: managed identity authentication. Understanding this is essential because it eliminates the need for storing passwords or connection strings in your infrastructure.

### What is a Managed Identity?

A managed identity is an Azure Active Directory identity that Azure automatically manages for you. When you create an Azure Data Factory with a system-assigned managed identity, Azure does several things automatically:

1. Creates an identity in Azure Active Directory
2. Associates this identity with your Data Factory resource
3. Manages the lifecycle of this identity (it gets deleted when ADF is deleted)
4. Provides authentication tokens to ADF at runtime

The beauty of this is that you never see or manage any credentials. Azure handles everything behind the scenes.

### How Managed Identity Works for Storage Access

Here's the flow when ADF needs to read a file from storage:

1. ADF needs to copy a file from blob storage
2. ADF asks Azure AD: "I need a token to access storage account X"
3. Azure AD checks: "Does this ADF's managed identity have permission to storage account X?"
4. If yes, Azure AD issues a short-lived access token to ADF
5. ADF uses this token to authenticate to the storage account
6. Storage account validates the token and allows the operation

This happens automatically. You don't write any code to request tokens or handle authentication. You just configure RBAC permissions, and Azure handles the rest.

### Why This Matters

**No Secrets**: There are no passwords, access keys, or connection strings to manage, rotate, or accidentally commit to source control.

**Automatic Rotation**: The tokens Azure issues are short-lived and automatically renewed. No manual rotation needed.

**Audit Trail**: Every access attempt is logged with the managed identity's details, making security audits straightforward.

**Least Privilege**: You can grant specific permissions (like "Storage Blob Data Contributor") rather than full admin access.

## The Role of RBAC in This Architecture

RBAC (Role-Based Access Control) is what connects your managed identity to storage permissions.

### Storage Blob Data Contributor Role

This is the role we're assigning to ADF's managed identity on both storage accounts. What does this role allow?

**Read Operations**: List containers, list blobs, read blob content
**Write Operations**: Create blobs, upload blob content, overwrite existing blobs
**Delete Operations**: Delete blobs (needed for some data lifecycle scenarios)
**Metadata Operations**: Set and read blob metadata, tags, and properties

What it does NOT allow:
- Changing storage account configuration
- Managing access keys
- Deleting the storage account itself
- Modifying firewall rules

This is the principle of least privilege. ADF gets exactly the permissions it needs to move data, nothing more.

### Why Two Role Assignments?

We create two separate role assignments because we have two separate storage accounts:

**Assignment 1: ADF to Source Blob Storage**
```hcl
resource "azurerm_role_assignment" "adf_to_source_blob" {
  scope                = var.source_blob_storage_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.platform.identity[0].principal_id
}
```

This grants ADF permission to read files from the source blob storage where external systems drop files. ADF needs this to copy files from hr-landing, payroll-landing, and finance-landing containers.

**Assignment 2: ADF to Data Lake**
```hcl
resource "azurerm_role_assignment" "adf_to_datalake" {
  scope                = var.data_lake_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.platform.identity[0].principal_id
}
```

This grants ADF permission to write files to the data lake. ADF needs this to write processed data to bronze, silver, and gold layers.

Both assignments use the same managed identity (ADF's identity) but grant permissions on different storage accounts.

## Understanding Linked Services

Linked services are ADF's way of defining connections to external systems. Think of them as connection profiles that pipelines reference when they need to access data.

### Linked Service to Source Blob Storage

```hcl
resource "azurerm_data_factory_linked_service_azure_blob_storage" "source_blob" {
  name                 = "LS_SourceBlobStorage"
  data_factory_id      = azurerm_data_factory.platform.id
  use_managed_identity = true
  connection_string    = "DefaultEndpointsProtocol=https;AccountName=${var.source_blob_storage_name};EndpointSuffix=core.windows.net"
}
```

**What This Does**:

The linked service tells ADF how to connect to the source blob storage account. The key parameter is `use_managed_identity = true`, which instructs ADF to use its managed identity for authentication instead of an access key.

Notice the connection string doesn't include `AccountKey=...`. That's the whole point. With managed identity authentication, you don't need the account key. The connection string just tells ADF which storage account to connect to, and the managed identity (backed by RBAC) provides the actual authentication.

### Linked Service to Data Lake

```hcl
resource "azurerm_data_factory_linked_service_data_lake_storage_gen2" "datalake" {
  name                 = "LS_DataLake"
  data_factory_id      = azurerm_data_factory.platform.id
  use_managed_identity = true
  url                  = var.data_lake_endpoint
}
```

This is similar to the blob storage linked service, but specifically designed for ADLS Gen2. The `url` parameter points to the DFS endpoint (the one ending in .dfs.core.windows.net), which is necessary for hierarchical namespace features.

### How Pipelines Use Linked Services

When you create a dataset in ADF (which represents a specific data location), you reference a linked service:

```json
{
  "name": "DS_SourceBlob_HR",
  "type": "AzureBlob",
  "linkedServiceName": {
    "referenceName": "LS_SourceBlobStorage",
    "type": "LinkedServiceReference"
  },
  "parameters": {
    "pod_id": {
      "type": "String"
    }
  },
  "folderPath": "@concat('hr-landing/', dataset().pod_id, '/')"
}
```

The dataset uses the linked service for authentication and connection details, but adds its own parameters (like pod_id) to make the path dynamic.

## Diagnostic Logging for Multi-Tenant Monitoring

When you share a single ADF instance across multiple pods, monitoring becomes more complex. You need to answer questions like:

- Which pod's pipelines are running right now?
- Did Pod A's HR ingestion pipeline fail?
- How many pipeline runs did Pod B execute this month?

This is where diagnostic logging with custom dimensions comes in.

### The Diagnostic Setting Configuration

```hcl
resource "azurerm_monitor_diagnostic_setting" "adf_diagnostics" {
  name                       = "adf-${var.environment}-diagnostics"
  target_resource_id         = azurerm_data_factory.platform.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ActivityRuns"
  }

  enabled_log {
    category = "PipelineRuns"
  }

  enabled_log {
    category = "TriggerRuns"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
```

This configuration sends three types of logs to Log Analytics:

**ActivityRuns**: Individual activity executions within a pipeline. For example, a Copy Data activity that moves files from source to bronze.

**PipelineRuns**: Overall pipeline executions from start to finish. This includes all activities that ran as part of the pipeline.

**TriggerRuns**: Event-based trigger executions. When a file lands in hr-landing/podA/, the trigger fires and creates a pipeline run.

### Filtering Logs by Pod

When ADF logs pipeline runs, it includes all pipeline parameters in the log entry under customDimensions. This means if your pipeline has a pod_id parameter, every log entry will include that value.

In Log Analytics, you can query like this:

```kusto
AzureDiagnostics
| where ResourceType == "DATAFACTORIES"
| where Category == "PipelineRuns"
| extend pod_id = tostring(customDimensions.pod_id)
| where pod_id == "podA"
| project TimeGenerated, pipelineName, runStatus, pod_id, duration
```

This query shows only Pod A's pipeline runs, even though all pods share the same ADF instance. This is how you maintain visibility and accountability in a shared infrastructure model.

## Module Structure Breakdown

Let's walk through each file in detail.

### Part 1: Module Variables (variables.tf)

Create the file at `terraform/modules/data-factory/variables.tf`:

```hcl
# Variables for Shared Data Factory Module
# This module creates ONE Azure Data Factory shared by all pods
# Pipelines use parameters to route data to pod-specific storage folders

variable "resource_group_name" {
  description = "Resource group name for shared Data Factory"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
}

variable "source_blob_storage_id" {
  description = "Source blob storage account resource ID for RBAC"
  type        = string
}

variable "source_blob_storage_name" {
  description = "Source blob storage account name for linked service"
  type        = string
}

variable "data_lake_id" {
  description = "Data Lake Gen2 storage account resource ID for RBAC"
  type        = string
}

variable "data_lake_endpoint" {
  description = "Data Lake Gen2 primary DFS endpoint for linked service"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace ID for diagnostics"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
```

**Understanding the Variables**:

**source_blob_storage_id vs source_blob_storage_name**: We need both because they serve different purposes. The ID is used for RBAC role assignment (granting permissions), while the name is used in the linked service connection string (telling ADF which account to connect to).

**data_lake_id vs data_lake_endpoint**: Same pattern. The ID is for RBAC, the endpoint is for the linked service connection. The endpoint will be something like `https://stdldevshared123abc.dfs.core.windows.net/`.

**log_analytics_workspace_id**: This is the shared Log Analytics workspace created in an earlier step. All pods send their logs here, making it the central monitoring hub for the entire platform.

### Part 2: Main Module Resources (main.tf)

This is the core of the module. Let's break it down section by section.

**Section 1: The Data Factory Resource**

```hcl
resource "azurerm_data_factory" "platform" {
  name                            = "adf-${var.environment}-platform"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  managed_virtual_network_enabled = true
  public_network_enabled          = true

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}
```

**Naming Convention**: We use "platform" instead of a pod ID because this ADF serves the entire platform, not a single pod. The result is `adf-dev-platform` for development environment.

**managed_virtual_network_enabled = true**: This creates a managed virtual network for ADF integration runtimes. It provides network isolation for data movement activities without you having to create and manage the VNet yourself.

**public_network_enabled = true**: For POC and development, we allow public access to the ADF portal. In production, you'd set this to false and access ADF through private endpoints.

**identity block**: This single configuration creates a system-assigned managed identity. Azure automatically provisions an identity in Azure AD and associates it with this Data Factory. The identity's lifecycle is tied to the Data Factory - if you delete the ADF, the identity gets deleted too.

**Section 2: RBAC Role Assignments**

```hcl
resource "azurerm_role_assignment" "adf_to_source_blob" {
  scope                = var.source_blob_storage_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.platform.identity[0].principal_id

  depends_on = [azurerm_data_factory.platform]
}

resource "azurerm_role_assignment" "adf_to_datalake" {
  scope                = var.data_lake_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.platform.identity[0].principal_id

  depends_on = [azurerm_data_factory.platform]
}
```

**The depends_on Block**: This is critical. Terraform needs to create the Data Factory first (which creates the managed identity) before it can assign roles to that identity. Without depends_on, Terraform might try to create the role assignment before the identity exists, causing the deployment to fail.

**principal_id**: This references the object ID of the managed identity. The syntax `azurerm_data_factory.platform.identity[0].principal_id` navigates through the ADF resource, into its identity block (which is a list, hence [0]), and grabs the principal_id attribute.

**scope**: This defines what the role applies to. By using the storage account resource ID as the scope, we're saying "this permission applies to this entire storage account and everything in it."

**Section 3: Diagnostic Settings**

```hcl
resource "azurerm_monitor_diagnostic_setting" "adf_diagnostics" {
  name                       = "adf-${var.environment}-diagnostics"
  target_resource_id         = azurerm_data_factory.platform.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ActivityRuns"
  }

  enabled_log {
    category = "PipelineRuns"
  }

  enabled_log {
    category = "TriggerRuns"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }

  depends_on = [azurerm_data_factory.platform]
}
```

**target_resource_id**: This specifies what resource we're collecting diagnostics from - in this case, our Data Factory.

**log_analytics_workspace_id**: This specifies where to send the logs. All three log categories and metrics get sent to this workspace.

**enabled_log blocks**: Each category represents a different type of ADF activity. ActivityRuns gives you granular details about individual steps. PipelineRuns gives you the overall execution status. TriggerRuns tells you when and why pipelines were triggered.

**metric block**: This captures performance metrics like pipeline duration, activity duration, and resource utilization. Setting category to "AllMetrics" means we collect everything Azure provides.

**Section 4: Linked Services**

```hcl
resource "azurerm_data_factory_linked_service_azure_blob_storage" "source_blob" {
  name                 = "LS_SourceBlobStorage"
  data_factory_id      = azurerm_data_factory.platform.id
  use_managed_identity = true
  connection_string    = "DefaultEndpointsProtocol=https;AccountName=${var.source_blob_storage_name};EndpointSuffix=core.windows.net"

  depends_on = [
    azurerm_data_factory.platform,
    azurerm_role_assignment.adf_to_source_blob
  ]
}

resource "azurerm_data_factory_linked_service_data_lake_storage_gen2" "datalake" {
  name                 = "LS_DataLake"
  data_factory_id      = azurerm_data_factory.platform.id
  use_managed_identity = true
  url                  = var.data_lake_endpoint

  depends_on = [
    azurerm_data_factory.platform,
    azurerm_role_assignment.adf_to_datalake
  ]
}
```

**Naming Convention**: The "LS_" prefix stands for "Linked Service" and is a common ADF naming convention. It makes it easy to identify linked services when browsing the ADF portal.

**use_managed_identity = true**: This is the key setting that enables credential-free authentication. ADF will use its managed identity (backed by the RBAC role assignments we created) to authenticate.

**depends_on with role assignments**: We need the role assignments to exist before creating the linked services. Otherwise, when ADF tries to test the connection during linked service creation, it might fail because permissions haven't propagated yet.

**Connection string format**: Notice there's no AccountKey parameter. The connection string only specifies which storage account to connect to. The actual authentication happens through the managed identity.

### Part 3: Module Outputs (outputs.tf)

```hcl
# Outputs for Shared Data Factory Module
# Provides resource IDs and names for pipeline creation and monitoring

output "data_factory_id" {
  description = "Shared Data Factory resource ID"
  value       = azurerm_data_factory.platform.id
}

output "data_factory_name" {
  description = "Shared Data Factory name"
  value       = azurerm_data_factory.platform.name
}

output "data_factory_identity_principal_id" {
  description = "Data Factory managed identity principal ID"
  value       = azurerm_data_factory.platform.identity[0].principal_id
}

output "source_blob_linked_service_name" {
  description = "Source blob storage linked service name"
  value       = azurerm_data_factory_linked_service_azure_blob_storage.source_blob.name
}

output "datalake_linked_service_name" {
  description = "Data Lake linked service name"
  value       = azurerm_data_factory_linked_service_data_lake_storage_gen2.datalake.name
}
```

**Why These Outputs Matter**:

**data_factory_id**: You'll need this when creating ADF pipelines, datasets, and triggers through Terraform or ARM templates.

**data_factory_name**: Useful for documentation and for constructing URLs to the ADF portal.

**data_factory_identity_principal_id**: If you need to grant this ADF additional permissions on other resources (like Azure Key Vault or other storage accounts), you'll use this principal ID.

**Linked service names**: When creating datasets and pipelines, you reference linked services by name. These outputs provide the exact names to use.

## Deployment Process

Now let's walk through actually deploying this module.

### Step 1: Clean Up Old Per-Pod Architecture

Before we can deploy the shared model, we need to remove the old per-pod Data Factory instances.

Navigate to the dev environment:

```bash
cd C:\Users\User\Desktop\Delta_lake_project\terraform\environments\dev
```

If you haven't already destroyed everything, run:

```bash
terraform destroy -auto-approve
```

This will remove all existing infrastructure including the old per-pod ADF instances.

### Step 2: Remove Old Module Files

Delete the old Data Factory module files:

```bash
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\data-factory\main.tf"
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\data-factory\variables.tf"
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\data-factory\outputs.tf"
```

These commands delete the old per-pod architecture files to make room for the new shared architecture.

### Step 3: Create New Module Files

The new module files have been created with the content shown in the previous sections. Verify they exist:

```bash
ls -la "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\data-factory\"
```

You should see:
```
-rw-r--r-- 1 User 197121 4234 Oct  4 19:45 main.tf
-rw-r--r-- 1 User 197121 1112 Oct  4 19:44 variables.tf
-rw-r--r-- 1 User 197121  843 Oct  4 19:46 outputs.tf
```

### Step 4: Update Dev Environment Configuration

Edit `terraform/environments/dev/main.tf` and update the Data Factory module call:

```hcl
# Shared Data Factory Module - Single ADF instance with parameterized pipelines
module "data_factory_platform" {
  source = "../../modules/data-factory"

  environment                = var.environment
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  source_blob_storage_id     = module.source_blob_storage_shared.storage_account_id
  source_blob_storage_name   = module.source_blob_storage_shared.storage_account_name
  data_lake_id               = module.data_lake_shared.storage_account_id
  data_lake_endpoint         = module.data_lake_shared.primary_dfs_endpoint
  log_analytics_workspace_id = module.log_analytics.workspace_id
  tags                       = var.tags

  depends_on = [
    module.source_blob_storage_shared,
    module.data_lake_shared,
    module.log_analytics
  ]
}
```

**Key Changes from Old Architecture**:

**No for_each loop**: Unlike the old per-pod model, we instantiate this module only once. It creates a single shared ADF.

**Module name**: Changed to `data_factory_platform` to reflect that this is a platform-wide resource, not pod-specific.

**Dependencies**: We explicitly depend on the storage modules to ensure storage accounts exist before ADF tries to access them.

### Step 5: Validate and Deploy

Navigate to the dev environment:

```bash
cd C:\Users\User\Desktop\Delta_lake_project\terraform\environments\dev
```

Initialize Terraform to recognize the updated module:

```bash
terraform init
```

Format the code:

```bash
terraform fmt -recursive
```

Validate the configuration:

```bash
terraform validate
```

Expected output:
```
Success! The configuration is valid.
```

Preview what will be created:

```bash
terraform plan
```

You should see in the plan:
- 1 Data Factory resource
- 2 role assignment resources
- 1 diagnostic setting resource
- 2 linked service resources
- Total: 6 resources to be created

Deploy the resources:

```bash
terraform apply -auto-approve
```

The deployment takes about 3-5 minutes. You'll see output like:

```
azurerm_data_factory.platform: Creating...
azurerm_data_factory.platform: Still creating... [10s elapsed]
azurerm_data_factory.platform: Still creating... [20s elapsed]
azurerm_data_factory.platform: Creation complete after 23s

azurerm_role_assignment.adf_to_source_blob: Creating...
azurerm_role_assignment.adf_to_datalake: Creating...
azurerm_monitor_diagnostic_setting.adf_diagnostics: Creating...

...

Apply complete! Resources: 6 added, 0 changed, 0 destroyed.
```

### Step 6: Verify Deployment

List Data Factory instances in the resource group:

```bash
az datafactory list \
  --resource-group rg-delta-lake-dev \
  --output table
```

Expected output:
```
Location  Name                  ResourceGroup      ProvisioningState
--------  --------------------  -----------------  -------------------
eastus    adf-dev-platform      rg-delta-lake-dev  Succeeded
```

Check the managed identity was created:

```bash
az datafactory show \
  --name adf-dev-platform \
  --resource-group rg-delta-lake-dev \
  --query "identity.{Type:type, PrincipalId:principalId, TenantId:tenantId}" \
  --output table
```

Expected output:
```
Type            PrincipalId                           TenantId
--------------  ------------------------------------  ------------------------------------
SystemAssigned  a1b2c3d4-e5f6-7890-abcd-ef1234567890  6c086ae8-f198-40e0-bfec-5a06bf6fcb41
```

Verify role assignments were created:

```bash
az role assignment list \
  --scope /subscriptions/e97fa8c6-457d-495f-aa82-0d87e72f5842/resourceGroups/rg-delta-lake-dev/providers/Microsoft.Storage/storageAccounts/stblobdevshared123abc \
  --query "[?principalType=='ServicePrincipal'].{Role:roleDefinitionName, Principal:principalId}" \
  --output table
```

Expected output:
```
Role                              Principal
--------------------------------  ------------------------------------
Storage Blob Data Contributor     a1b2c3d4-e5f6-7890-abcd-ef1234567890
```

Verify linked services were created:

```bash
az datafactory linked-service list \
  --factory-name adf-dev-platform \
  --resource-group rg-delta-lake-dev \
  --output table
```

Expected output:
```
Name                   Type
---------------------  --------------------------------------------------------
LS_SourceBlobStorage   Microsoft.DataFactory/factories/linkedservices
LS_DataLake            Microsoft.DataFactory/factories/linkedservices
```

Check diagnostic settings:

```bash
az monitor diagnostic-settings list \
  --resource /subscriptions/e97fa8c6-457d-495f-aa82-0d87e72f5842/resourceGroups/rg-delta-lake-dev/providers/Microsoft.DataFactory/factories/adf-dev-platform \
  --query "[].{Name:name, Workspace:workspaceId}" \
  --output table
```

Expected output should show the diagnostic setting sending logs to your Log Analytics workspace.

### Step 7: Access the ADF Portal

Open the Azure Portal and navigate to your Data Factory:

```bash
# Get the ADF portal URL
az datafactory show \
  --name adf-dev-platform \
  --resource-group rg-delta-lake-dev \
  --query "id" \
  --output tsv
```

Or simply navigate in the Azure Portal:
1. Go to Resource Groups
2. Click on rg-delta-lake-dev
3. Find and click on adf-dev-platform
4. Click "Open Azure Data Factory Studio"

In the ADF Studio, you should see:
- The LS_SourceBlobStorage linked service under Manage > Linked services
- The LS_DataLake linked service under Manage > Linked services
- No pipelines yet (we'll create those in a future step)

## How Parameterized Pipelines Will Work

Now that we have the shared Data Factory infrastructure, let's understand how pipelines will use it.

### Pipeline Parameter Concept

When you create a pipeline in ADF, you can define parameters that accept values at runtime. Here's a simple example:

```json
{
  "name": "Copy_SourceBlob_To_Bronze",
  "properties": {
    "parameters": {
      "pod_id": {
        "type": "String",
        "defaultValue": "podA"
      },
      "domain": {
        "type": "String",
        "defaultValue": "hr"
      }
    },
    "activities": [
      {
        "name": "Copy_HR_Files",
        "type": "Copy",
        "inputs": [
          {
            "referenceName": "DS_SourceBlob",
            "type": "DatasetReference",
            "parameters": {
              "pod_id": {
                "value": "@pipeline().parameters.pod_id",
                "type": "Expression"
              },
              "domain": {
                "value": "@pipeline().parameters.domain",
                "type": "Expression"
              }
            }
          }
        ],
        "outputs": [
          {
            "referenceName": "DS_DataLake_Bronze",
            "type": "DatasetReference",
            "parameters": {
              "pod_id": {
                "value": "@pipeline().parameters.pod_id",
                "type": "Expression"
              },
              "domain": {
                "value": "@pipeline().parameters.domain",
                "type": "Expression"
              }
            }
          }
        ]
      }
    ]
  }
}
```

### Dataset Parameter Example

The datasets referenced by the pipeline also use parameters:

```json
{
  "name": "DS_SourceBlob",
  "properties": {
    "linkedServiceName": {
      "referenceName": "LS_SourceBlobStorage",
      "type": "LinkedServiceReference"
    },
    "parameters": {
      "pod_id": {
        "type": "String"
      },
      "domain": {
        "type": "String"
      }
    },
    "type": "Binary",
    "typeProperties": {
      "location": {
        "type": "AzureBlobStorageLocation",
        "container": "@concat(dataset().domain, '-landing')",
        "folderPath": "@dataset().pod_id"
      }
    }
  }
}
```

### How This Enables Multi-Tenant Operations

When you trigger this pipeline:

**For Pod A HR data**:
```json
{
  "pod_id": "podA",
  "domain": "hr"
}
```
Result: Copies from `hr-landing/podA/` to `bronze/podA/hr/`

**For Pod B Payroll data**:
```json
{
  "pod_id": "podB",
  "domain": "payroll"
}
```
Result: Copies from `payroll-landing/podB/` to `bronze/podB/payroll/`

Same pipeline, different execution paths. This is the power of the shared model.

### Event-Driven Triggers with Pod Isolation

You can create event triggers that pass pod-specific parameters:

```json
{
  "name": "Trigger_PodA_HR_FileArrival",
  "properties": {
    "type": "BlobEventsTrigger",
    "typeProperties": {
      "blobPathBeginsWith": "/hr-landing/blobs/podA/",
      "events": ["Microsoft.Storage.BlobCreated"]
    },
    "pipelines": [
      {
        "pipelineReference": {
          "referenceName": "Copy_SourceBlob_To_Bronze",
          "type": "PipelineReference"
        },
        "parameters": {
          "pod_id": "podA",
          "domain": "hr"
        }
      }
    ]
  }
}
```

When a file lands in `hr-landing/podA/`, this trigger fires and runs the pipeline with `pod_id="podA"` and `domain="hr"`.

## Monitoring Shared ADF in Log Analytics

With all pods sharing one ADF, monitoring needs to be smart about filtering.

### Query Pipeline Runs by Pod

```kusto
AzureDiagnostics
| where ResourceType == "DATAFACTORIES"
| where Category == "PipelineRuns"
| extend pod_id = tostring(customDimensions.pod_id)
| extend domain = tostring(customDimensions.domain)
| project
    TimeGenerated,
    pipelineName = OperationName,
    pod_id,
    domain,
    status = Status,
    duration = DurationMs
| order by TimeGenerated desc
```

This query extracts pod_id and domain from the pipeline parameters and displays them alongside the pipeline execution details.

### Query Failed Runs for Specific Pod

```kusto
AzureDiagnostics
| where ResourceType == "DATAFACTORIES"
| where Category == "PipelineRuns"
| where Status == "Failed"
| extend pod_id = tostring(customDimensions.pod_id)
| where pod_id == "podA"
| project
    TimeGenerated,
    pipelineName = OperationName,
    errorMessage = Message,
    pod_id
```

This helps you quickly identify failures affecting a specific pod without being overwhelmed by other pods' logs.

### Create Alerts for Pod-Specific Failures

You can create Log Analytics alerts that fire only when a specific pod's pipelines fail:

```kusto
AzureDiagnostics
| where ResourceType == "DATAFACTORIES"
| where Category == "PipelineRuns"
| where Status == "Failed"
| extend pod_id = tostring(customDimensions.pod_id)
| where pod_id == "podA"
| summarize FailureCount = count() by bin(TimeGenerated, 5m)
| where FailureCount > 0
```

This query can power an alert that notifies the Pod A team when their pipelines fail, without spamming them about Pod B or Pod C issues.

## Security Considerations

### RBAC Scope

The current configuration grants ADF access to entire storage accounts. In a highly secure environment, you might want more granular control:

```bash
# Grant access only to specific containers (requires Azure RBAC conditions - currently in preview)
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee <adf-principal-id> \
  --scope /subscriptions/.../storageAccounts/stblobdevshared123abc/blobServices/default/containers/bronze \
  --condition "blob path starts with 'podA/'"
```

This would limit ADF to only Pod A's folders within the bronze container.

### Managed Virtual Network

The `managed_virtual_network_enabled = true` setting creates an isolated network for ADF's integration runtimes. Data movement happens within this private network, not over the public internet.

Benefits:
- Data in transit never leaves Azure's backbone network
- Integration runtime compute is isolated from public internet
- Can be connected to your corporate VNet through private endpoints

### Public Network Access

For production, consider disabling public access:

```hcl
public_network_enabled = false
```

Then use private endpoints to access the ADF portal from within your corporate network.

## Cost Implications

### Old Architecture (Per-Pod) Costs

- 3 Data Factory instances: 3 × $0.50/month base = $1.50
- 3 sets of orchestration activities: 3 × $1.00 per 1000 runs = $3.00
- 3 sets of pipeline executions: 3 × $1.00 per 1000 runs = $3.00
- Total minimum: $7.50/month (with minimal usage)

### New Architecture (Shared) Costs

- 1 Data Factory instance: $0.50/month base
- Orchestration activities: $1.00 per 1000 runs (shared across all pods)
- Pipeline executions: $1.00 per 1000 runs (shared across all pods)
- Total minimum: $2.50/month

**Savings**: $5.00/month (66% reduction) even with minimal usage. With higher usage, the savings scale proportionally.

## Troubleshooting Guide

### Problem: Role Assignment Failed

**Error**: "The role assignment already exists but in a different state"

**Solution**: Wait 60 seconds for RBAC propagation, then retry:
```bash
terraform apply -auto-approve
```

### Problem: Linked Service Test Connection Fails

**Error**: "Access denied" when testing linked service connection

**Diagnosis**:
1. Check if role assignments were created:
```bash
az role assignment list \
  --assignee <adf-principal-id> \
  --scope <storage-account-id> \
  --output table
```

2. Wait for RBAC propagation (can take up to 5 minutes):
```bash
# Just wait, then retry
```

### Problem: Diagnostic Logs Not Appearing

**Error**: No logs showing up in Log Analytics

**Diagnosis**:
1. Verify diagnostic setting was created:
```bash
az monitor diagnostic-settings show \
  --resource <adf-resource-id> \
  --name adf-dev-diagnostics
```

2. Run a test pipeline to generate logs

3. Wait 5-10 minutes for logs to appear (there's a delay)

4. Query Log Analytics:
```kusto
AzureDiagnostics
| where ResourceType == "DATAFACTORIES"
| take 10
```

## Command Reference

Here's a complete list of all commands used in this step:

```bash
# Navigate to dev environment
cd C:\Users\User\Desktop\Delta_lake_project\terraform\environments\dev

# Clean up old infrastructure (if not already done)
terraform destroy -auto-approve

# Remove old module files
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\data-factory\main.tf"
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\data-factory\variables.tf"
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\data-factory\outputs.tf"

# Verify new module files exist
ls -la "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\data-factory\"

# Initialize Terraform
terraform init

# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Preview changes
terraform plan

# Deploy resources
terraform apply -auto-approve

# List Data Factory instances
az datafactory list \
  --resource-group rg-delta-lake-dev \
  --output table

# Show Data Factory with identity details
az datafactory show \
  --name adf-dev-platform \
  --resource-group rg-delta-lake-dev \
  --query "identity" \
  --output json

# List role assignments on source blob storage
az role assignment list \
  --scope /subscriptions/e97fa8c6-457d-495f-aa82-0d87e72f5842/resourceGroups/rg-delta-lake-dev/providers/Microsoft.Storage/storageAccounts/stblobdevshared123abc \
  --query "[?principalType=='ServicePrincipal'].{Role:roleDefinitionName, Principal:principalId}" \
  --output table

# List role assignments on data lake storage
az role assignment list \
  --scope /subscriptions/e97fa8c6-457d-495f-aa82-0d87e72f5842/resourceGroups/rg-delta-lake-dev/providers/Microsoft.Storage/storageAccounts/stdldevshared123abc \
  --query "[?principalType=='ServicePrincipal'].{Role:roleDefinitionName, Principal:principalId}" \
  --output table

# List linked services
az datafactory linked-service list \
  --factory-name adf-dev-platform \
  --resource-group rg-delta-lake-dev \
  --output table

# Show specific linked service details
az datafactory linked-service show \
  --factory-name adf-dev-platform \
  --resource-group rg-delta-lake-dev \
  --name LS_SourceBlobStorage \
  --output json

# List diagnostic settings
az monitor diagnostic-settings list \
  --resource /subscriptions/e97fa8c6-457d-495f-aa82-0d87e72f5842/resourceGroups/rg-delta-lake-dev/providers/Microsoft.DataFactory/factories/adf-dev-platform \
  --output table

# Get ADF portal URL
echo "https://adf.azure.com/en-us/home?factory=/subscriptions/e97fa8c6-457d-495f-aa82-0d87e72f5842/resourceGroups/rg-delta-lake-dev/providers/Microsoft.DataFactory/factories/adf-dev-platform"
```

## Files Modified/Created

```
terraform/modules/data-factory/
├── variables.tf   - REPLACED: Updated for shared model with storage account inputs
├── main.tf        - REPLACED: Single ADF, RBAC, diagnostics, linked services
└── outputs.tf     - REPLACED: Outputs for shared ADF and linked services

terraform/environments/dev/
└── main.tf        - TO BE UPDATED: Change from for_each to single instantiation
```

## What's Next

With the shared Data Factory infrastructure in place, the next steps are:

1. Create parameterized datasets that reference the linked services
2. Build pipelines that accept pod_id and domain parameters
3. Create event-based triggers for each pod's source blob folders
4. Test the end-to-end flow from file landing to bronze layer ingestion
5. Monitor pipeline runs in Log Analytics and verify pod isolation

The infrastructure is now ready to support multi-tenant data orchestration through a single shared platform.

## Key Takeaways

This step introduced several important concepts:

- Sharing a single Data Factory across multiple pods reduces costs by 66% while maintaining operational isolation through parameterized pipelines
- Managed identity authentication eliminates the need to store credentials or connection strings in your infrastructure code
- RBAC role assignments connect the managed identity to storage permissions, enabling secure access without secrets
- Linked services provide reusable connection definitions that pipelines and datasets reference
- Diagnostic logging with custom dimensions enables pod-specific monitoring in a shared infrastructure model
- Pipeline parameters (pod_id, domain) enable the same pipeline code to process data for different tenants by routing to different storage paths
- Event-driven triggers can pass pod-specific parameters to pipelines, maintaining isolation at the execution level
- Log Analytics queries can filter by pod_id to provide tenant-specific operational insights
- The depends_on blocks ensure resources are created in the correct order (ADF before identity before role assignments before linked services)
- This shared model scales better than per-pod instances because adding a new pod doesn't require deploying new infrastructure
