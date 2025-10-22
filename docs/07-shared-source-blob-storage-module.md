# Step 10: Shared Source Blob Storage Module with Department-Level Isolation

## Overview

This module creates a **shared source blob storage account** with **department-level folder isolation** for multi-pod, multi-department data ingestion. This architecture supports the manager's requirement for department-granular processing, cost tracking, and reporting.

**Latest Update**: Enhanced from pod-level to **department-level folder structure** to support simultaneous department processing within each pod.

## Department-Level Architecture (New)

### Manager's Requirements

Each pod manages **3-4 departments**, and each department needs:
- **Simultaneous processing**: All departments process data in parallel
- **Independent reporting**: Each department tracked separately in Power BI
- **Cost attribution**: Know exactly what each department costs
- **Scalability**: Easy to add new departments without pipeline changes

### New Folder Structure

```
stblobdevshared123abc/
├─ hr-landing/
│  ├─ podA/
│  │  ├─ finance/      ← Department-level folders
│  │  ├─ operations/
│  │  ├─ marketing/
│  │  └─ it/
│  ├─ podB/
│  │  ├─ finance/
│  │  ├─ operations/
│  │  └─ sales/
│  └─ podC/
│     ├─ finance/
│     ├─ hr_central/
│     └─ compliance/
├─ payroll-landing/
│  └─ (same department structure)
└─ finance-landing/
   └─ (same department structure)
```

### File Upload Example

**Old (Pod-level)**:
```
hr-landing/podA/HR_EMPLOYEES.csv
```
[ERROR] Problem: Can't distinguish between Finance dept and Operations dept data

**New (Department-level)**:
```
hr-landing/podA/finance/HR_EMPLOYEES.csv
hr-landing/podA/operations/HR_EMPLOYEES.csv
```
[DONE] Benefit: Clear department separation, independent processing

### How Data Flows Through

```
External System
    ↓
Uploads file to: hr-landing/podA/finance/HR_EMPLOYEES.csv
    ↓
Event Grid fires event with path: podA/finance/HR_EMPLOYEES.csv
    ↓
ADF Pipeline filters: podA AND finance department
    ↓
Copies to: bronze/podA/finance/hr/HR_EMPLOYEES.parquet
    ↓
Databricks processes: silver/podA/finance/hr/employees (Delta)
    ↓
Aggregates to: gold/podA/finance/analytics/* (Delta)
    ↓
Power BI reports: Finance department metrics
```

### Archive Pattern: Preventing Reprocessing

**Problem**: Without archive folders, processed files remain in landing zone and get reprocessed on every pipeline run, creating duplicates and wasting cluster resources.

**Solution**: After successful processing, files are moved to `archive/{date}/` subfolder.

**Archive Folder Structure**:
```
landing/
├── podA/
│   ├── finance/
│   │   ├── archive/              ← Processed files moved here
│   │   │   ├── 20250115/         ← Date-stamped folders
│   │   │   │   ├── hr_data.csv
│   │   │   │   └── payroll.csv
│   │   │   └── 20250116/
│   │   │       └── hr_new.csv
│   │   └── (new files land here)  ← Active landing zone
│   ├── operations/
│   │   ├── archive/
│   │   └── (new files here)
│   └── ...
```

**How Archive Pattern Works**:

**Run 1** (new files arrive):
1. Check_Data_Exists: Finds 2 files in `landing/podA/finance/`
2. Copy_to_Bronze: Copies to bronze layer
3. Archive_Processed_Files: Moves files to `landing/podA/finance/archive/20250115/`
4. Landing folder now empty DONE

**Run 2** (1 new file arrives):
1. Check_Data_Exists: Finds 1 file in `landing/podA/finance/`
2. Copy_to_Bronze: Copies only the new file
3. Archive_Processed_Files: Moves to `landing/podA/finance/archive/20250115/`
4. Old files stay in archive, not reprocessed DONE

**Run 3** (no new files):
1. Check_Data_Exists: Finds 0 files in `landing/podA/finance/`
2. If_Has_Data returns FALSE
3. Entire pipeline skipped - no cluster created DONE

**Archive Folders Created via Terraform**:
- `landing/podA/finance/archive/.folder`
- `landing/podA/operations/archive/.folder`
- `landing/podA/marketing/archive/.folder`
- `landing/podA/it/archive/.folder`
- (Same for podB and podC - 10 archive folders total)

**Lifecycle Management**:
- Landing files: Auto-delete after 30 days (active processing zone)
- Archive files: Auto-delete after 90 days (audit/compliance retention)

**Benefits**:
- COMPLETED: No duplicate processing
- COMPLETED: Clear separation of new vs processed files
- COMPLETED: Complete audit trail with timestamps
- COMPLETED: Can reprocess from archive if needed
- COMPLETED: Automatic cleanup via lifecycle policies

### Why Department-Level Folders in Source Blob?

**Benefit 1: Event Filtering**
- ADF can filter events by exact department path
- Example: `hr-landing/podA/finance/*` triggers only Finance pipeline

**Benefit 2: Access Control**
- Grant Finance team upload access to only `podA/finance/*`
- Operations team can't accidentally upload to Finance folder

**Benefit 3: Clear Organization**
- Finance team knows exactly where to upload files
- No confusion about which department owns the data

**Benefit 4: Parallel Processing**
- When Finance uploads at 8 AM and Operations at 8:01 AM, both process simultaneously
- No waiting for one department to finish before the next starts

## Architecture Evolution: From Isolated to Shared

### Previous Architecture (Per-Pod Isolation)

The original design created **3 separate storage accounts**:

```
Pod A: stblobdevpoda123abc/
├─ hr-landing/
├─ payroll-landing/
└─ finance-landing/

Pod B: stblobdevpodb456def/
├─ hr-landing/
├─ payroll-landing/
└─ finance-landing/

Pod C: stblobdevpodc789ghi/
├─ hr-landing/
├─ payroll-landing/
└─ finance-landing/

Event Grid Topics: 3 topics (one per storage account)
```

**Pros of Old Architecture**:
- Complete infrastructure isolation between pods
- Separate Event Grid topics for each pod
- Independent lifecycle policies per pod
- Clear ownership and access boundaries

**Cons of Old Architecture**:
- Higher costs (3 storage accounts + 3 Event Grid topics)
- More complex infrastructure management
- Redundant configuration across pods
- Harder to implement cross-pod data sharing scenarios

### New Architecture (Shared with Folder Isolation)

The new design creates **1 shared storage account** with folder-based separation:

```
stblobdevshared123abc/
├─ hr-landing/
│  ├─ podA/
│  ├─ podB/
│  └─ podC/
├─ payroll-landing/
│  ├─ podA/
│  ├─ podB/
│  └─ podC/
└─ finance-landing/
   ├─ podA/
   ├─ podB/
   └─ podC/

Event Grid Topic: 1 shared topic (monitors entire storage account)
```

**Pros of New Architecture**:
- Lower costs (1 storage account + 1 Event Grid topic)
- Simplified infrastructure management
- Easier cross-pod data sharing when needed
- Single pane of glass for monitoring all file ingestion
- Reduced Terraform code complexity

**Cons of New Architecture**:
- Pods share the same infrastructure resource
- Event filtering must be done at ADF pipeline level
- RBAC must be carefully configured to prevent cross-pod access
- Folder structure must be consistently maintained

### Why Make This Change?

**Cost Optimization**: Reduces Azure resource costs by ~66% for storage and Event Grid infrastructure.

**Operational Simplicity**: Managing one storage account is easier than managing three separate accounts with identical configurations.

**Scalability**: Adding a 4th pod (podD) just requires creating folders, not deploying new infrastructure.

**Event Grid Filtering**: Modern ADF event triggers support advanced path filtering, making folder-based isolation practical and secure.

**Compliance**: Many organizations prefer consolidating PII data in fewer storage accounts for easier audit and compliance management.

## Understanding Folder-Based Isolation

### How Azure Blob Storage Handles "Folders"

Azure Blob Storage is **not** a hierarchical file system. There are no true folders. Instead, "folders" are a user interface construct created by blob name prefixes.

When you create a blob named `podA/employee.csv`, Azure stores:
- Blob name: `podA/employee.csv` (the slash is just part of the name)
- The blob appears in a "folder" called `podA` in Storage Explorer

### Creating Folder Markers

To make folders visible in Azure Storage Explorer before any actual data files exist, we create placeholder blobs:

```hcl
resource "azurerm_storage_blob" "hr_poda_folder" {
  name                   = "podA/.folder"
  storage_account_name   = azurerm_storage_account.source_shared.name
  storage_container_name = azurerm_storage_container.hr_landing.name
  type                   = "Block"
  source_content         = "folder"
}
```

This creates an empty blob named `podA/.folder` which:
- Makes the `podA/` folder appear in Storage Explorer immediately
- Provides a visual structure before any real files are uploaded
- Has no functional impact on data processing (pipelines ignore `.folder` files)

We create **9 folder markers total**:
- 3 pods × 3 containers = 9 markers

### Event Grid Filtering with Folders

When a file is uploaded to `hr-landing/podA/employee.csv`:

1. Event Grid fires a BlobCreated event with:
   - Container: `hr-landing`
   - Blob name: `podA/employee.csv`
   - URL: `https://stblobdevshared123abc.blob.core.windows.net/hr-landing/podA/employee.csv`

2. ADF event trigger for Pod A filters events using:
   - Container filter: `hr-landing`
   - Blob name prefix: `podA/`

3. Only Pod A's ADF pipeline is triggered because the blob name starts with `podA/`

4. Pod B and Pod C's ADF pipelines have different prefix filters (`podB/` and `podC/`) so they ignore this event

This provides **logical isolation** through event filtering, not **physical isolation** through separate storage accounts.

## Part 1: Module Variables (variables.tf)

The variables file changes significantly because the module no longer needs `pod_id` as a required variable. Instead, it uses a list of pod IDs to create folders.

### Complete Destruction of Old Resources

Before recreating the module, we destroyed all existing resources:

```bash
cd terraform/environments/dev
terraform destroy -auto-approve
```

**Command Explanation**:
- `terraform destroy`: Command to delete all resources managed by Terraform
- `-auto-approve`: Automatically confirms destruction without prompting for "yes"
- Deletes all storage accounts, Event Grid topics, ADF instances, Databricks workspaces, etc.
- Terraform state is updated to reflect empty infrastructure

**Output**:
```
Destroy complete! Resources: 67 destroyed.
```

### Deleting Old Module Files

Before creating the new module, we removed the old per-pod architecture files:

```bash
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\source-blob-storage\main.tf"
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\source-blob-storage\variables.tf"
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\source-blob-storage\outputs.tf"
```

**Command Explanation**:
- `rm`: Remove/delete command
- Quotes around paths handle Windows path format with backslashes
- Clears out the old per-pod architecture completely

### Creating the New Variables File

Create `terraform/modules/source-blob-storage/variables.tf`:

```hcl
# Variables for Shared Source Blob Storage Module
# This module creates ONE storage account shared by all pods with folder-based isolation

variable "resource_group_name" {
  description = "Resource group name for shared storage"
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

variable "pod_ids" {
  description = "List of pod identifiers for folder creation"
  type        = list(string)
  default     = ["podA", "podB", "podC"]
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
```

### Key Changes from Previous Version

**Removed**: `variable "pod_id"` (singular) - Old architecture needed this to create per-pod storage accounts

**Added**: `variable "pod_ids"` (plural list) - New architecture uses this to create folders for all pods in the shared storage

**Removed**: Validation blocks for `pod_id` and `environment` - Simplified for cleaner code

**Storage Naming Change**:
- Old: `stblob${var.environment}${var.pod_id}${random}`
- New: `stblob${var.environment}shared${random}`

The `pod_ids` variable defaults to `["podA", "podB", "podC"]` but can be overridden to support different pod configurations (e.g., `["podHR", "podFinance", "podSales"]`).

## Part 2: Main Module Resources (main.tf)

The main file undergoes the most significant transformation, replacing per-pod storage accounts with a single shared account and adding folder marker creation logic.

### Creating the New Main File

Create `terraform/modules/source-blob-storage/main.tf`:

```hcl
# Shared Source Blob Storage Module
# Provides a SINGLE storage account shared across all pods with folder-based isolation
# Each pod gets dedicated folders within shared containers for multi-tenant data ingestion

# Generate random suffix for globally unique storage account name
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Shared source blob storage account for all pods
# Pod isolation achieved through folder structure (podA/, podB/, podC/) within each container
resource "azurerm_storage_account" "source_shared" {
  name                          = "stblob${var.environment}shared${random_string.suffix.result}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  account_kind                  = "StorageV2"
  is_hns_enabled                = false
  min_tls_version               = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled = true

  # Blob-specific features for versioning, auditing, and event tracking
  blob_properties {
    versioning_enabled       = true
    change_feed_enabled      = true  # Required for Event Grid blob events
    last_access_time_enabled = true

    # Soft delete for blobs (7-day recovery window)
    delete_retention_policy {
      days = 7
    }

    # Soft delete for containers (7-day recovery window)
    container_delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# Container: HR Landing Zone
# Receives HR data files from external systems
# Folder structure: hr-landing/podA/, hr-landing/podB/, hr-landing/podC/
resource "azurerm_storage_container" "hr_landing" {
  name                  = "hr-landing"
  storage_account_name  = azurerm_storage_account.source_shared.name
  container_access_type = "private"
}

# Container: Payroll Landing Zone
# Receives payroll data files from external systems
# Folder structure: payroll-landing/podA/, payroll-landing/podB/, payroll-landing/podC/
resource "azurerm_storage_container" "payroll_landing" {
  name                  = "payroll-landing"
  storage_account_name  = azurerm_storage_account.source_shared.name
  container_access_type = "private"
}

# Container: Finance Landing Zone
# Receives finance data files from external systems
# Folder structure: finance-landing/podA/, payroll-landing/podB/, finance-landing/podC/
resource "azurerm_storage_container" "finance_landing" {
  name                  = "finance-landing"
  storage_account_name  = azurerm_storage_account.source_shared.name
  container_access_type = "private"
}

# ═══════════════════════════════════════════════════════════════
# POD FOLDER MARKERS - HR LANDING CONTAINER
# ═══════════════════════════════════════════════════════════════
# Azure Blob Storage doesn't have true folders, so we create placeholder blobs
# to establish the folder structure visible in Storage Explorer and Azure Portal

resource "azurerm_storage_blob" "hr_poda_folder" {
  name                   = "podA/.folder"
  storage_account_name   = azurerm_storage_account.source_shared.name
  storage_container_name = azurerm_storage_container.hr_landing.name
  type                   = "Block"
  source_content         = "folder"
}

resource "azurerm_storage_blob" "hr_podb_folder" {
  name                   = "podB/.folder"
  storage_account_name   = azurerm_storage_account.source_shared.name
  storage_container_name = azurerm_storage_container.hr_landing.name
  type                   = "Block"
  source_content         = "folder"
}

resource "azurerm_storage_blob" "hr_podc_folder" {
  name                   = "podC/.folder"
  storage_account_name   = azurerm_storage_account.source_shared.name
  storage_container_name = azurerm_storage_container.hr_landing.name
  type                   = "Block"
  source_content         = "folder"
}

# ═══════════════════════════════════════════════════════════════
# POD FOLDER MARKERS - PAYROLL LANDING CONTAINER
# ═══════════════════════════════════════════════════════════════

resource "azurerm_storage_blob" "payroll_poda_folder" {
  name                   = "podA/.folder"
  storage_account_name   = azurerm_storage_account.source_shared.name
  storage_container_name = azurerm_storage_container.payroll_landing.name
  type                   = "Block"
  source_content         = "folder"
}

resource "azurerm_storage_blob" "payroll_podb_folder" {
  name                   = "podB/.folder"
  storage_account_name   = azurerm_storage_account.source_shared.name
  storage_container_name = azurerm_storage_container.payroll_landing.name
  type                   = "Block"
  source_content         = "folder"
}

resource "azurerm_storage_blob" "payroll_podc_folder" {
  name                   = "podC/.folder"
  storage_account_name   = azurerm_storage_account.source_shared.name
  storage_container_name = azurerm_storage_container.payroll_landing.name
  type                   = "Block"
  source_content         = "folder"
}

# ═══════════════════════════════════════════════════════════════
# POD FOLDER MARKERS - FINANCE LANDING CONTAINER
# ═══════════════════════════════════════════════════════════════

resource "azurerm_storage_blob" "finance_poda_folder" {
  name                   = "podA/.folder"
  storage_account_name   = azurerm_storage_account.source_shared.name
  storage_container_name = azurerm_storage_container.finance_landing.name
  type                   = "Block"
  source_content         = "folder"
}

resource "azurerm_storage_blob" "finance_podb_folder" {
  name                   = "podB/.folder"
  storage_account_name   = azurerm_storage_account.source_shared.name
  storage_container_name = azurerm_storage_container.finance_landing.name
  type                   = "Block"
  source_content         = "folder"
}

resource "azurerm_storage_blob" "finance_podc_folder" {
  name                   = "podC/.folder"
  storage_account_name   = azurerm_storage_account.source_shared.name
  storage_container_name = azurerm_storage_container.finance_landing.name
  type                   = "Block"
  source_content         = "folder"
}

# Event Grid system topic for blob storage events
# Monitors ALL blob creation events across the entire storage account
# ADF pipelines will filter events by folder path (e.g., hr-landing/podA/*)
resource "azurerm_eventgrid_system_topic" "blob_events" {
  name                   = "egt-${var.environment}-shared-blob"
  resource_group_name    = var.resource_group_name
  location               = var.location
  source_arm_resource_id = azurerm_storage_account.source_shared.id
  topic_type             = "Microsoft.Storage.StorageAccounts"

  tags = var.tags
}

# Lifecycle management policy
# Two-tier retention strategy:
# 1. Landing files (active processing): Delete after 30 days
# 2. Archive files (audit trail): Delete after 90 days
resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.source_shared.id

  # Rule 1: Delete old landing files (NOT in archive folder)
  rule {
    name    = "delete-old-landing-files"
    enabled = true

    filters {
      prefix_match = ["landing/podA/", "landing/podB/", "landing/podC/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 30
      }
    }
  }

  # Rule 2: Delete old archive files (audit trail retention)
  rule {
    name    = "delete-old-archive-files"
    enabled = true

    filters {
      prefix_match = ["landing/podA/*/archive/", "landing/podB/*/archive/", "landing/podC/*/archive/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 90
      }
    }
  }
}
```

### Key Changes from Previous Version

**Storage Account Resource Name Changed**:
- Old: `azurerm_storage_account.source` (per-pod)
- New: `azurerm_storage_account.source_shared` (shared)

**Storage Account Naming Changed**:
- Old: `stblob${var.environment}${var.pod_id}${random}` → stblobdevpoda123abc
- New: `stblob${var.environment}shared${random}` → stblobdevshared123abc

**Added 9 Folder Marker Resources**:
- `azurerm_storage_blob` resources create `.folder` files in each pod folder
- HR container: podA/.folder, podB/.folder, podC/.folder
- Payroll container: podA/.folder, podB/.folder, podC/.folder
- Finance container: podA/.folder, podB/.folder, podC/.folder

**Event Grid Topic Naming Changed**:
- Old: `egt-${var.pod_id}-${var.environment}-blob` → egt-poda-dev-blob (3 topics)
- New: `egt-${var.environment}-shared-blob` → egt-dev-shared-blob (1 topic)

**Event Grid Isolation Approach Changed**:
- Old: Each pod has its own Event Grid topic monitoring only its storage account
- New: Single Event Grid topic monitors all events, ADF pipelines filter by blob path prefix

### Understanding the Folder Marker Pattern

The folder marker creation follows a systematic pattern:

```hcl
resource "azurerm_storage_blob" "<container>_<pod>_folder" {
  name                   = "<podID>/.folder"
  storage_account_name   = azurerm_storage_account.source_shared.name
  storage_container_name = azurerm_storage_container.<container>_landing.name
  type                   = "Block"
  source_content         = "folder"
}
```

This creates 9 resources with specific naming:
- `hr_poda_folder`, `hr_podb_folder`, `hr_podc_folder`
- `payroll_poda_folder`, `payroll_podb_folder`, `payroll_podc_folder`
- `finance_poda_folder`, `finance_podb_folder`, `finance_podc_folder`

Each creates a blob named `podX/.folder` containing the text "folder", which makes the pod folders visible in Azure Storage Explorer before any real data files are uploaded.

## Part 3: Module Outputs (outputs.tf)

The outputs file changes to reflect the shared storage account and single Event Grid topic.

### Creating the New Outputs File

Create `terraform/modules/source-blob-storage/outputs.tf`:

```hcl
# Outputs for Shared Source Blob Storage Module
# Event Grid monitors entire storage, ADF will filter events by path

output "storage_account_id" {
  description = "Shared source blob storage account ID"
  value       = azurerm_storage_account.source_shared.id
}

output "storage_account_name" {
  description = "Shared source blob storage account name"
  value       = azurerm_storage_account.source_shared.name
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint for file uploads"
  value       = azurerm_storage_account.source_shared.primary_blob_endpoint
}

output "hr_container_name" {
  description = "HR landing container name"
  value       = azurerm_storage_container.hr_landing.name
}

output "payroll_container_name" {
  description = "Payroll landing container name"
  value       = azurerm_storage_container.payroll_landing.name
}

output "finance_container_name" {
  description = "Finance landing container name"
  value       = azurerm_storage_container.finance_landing.name
}

output "eventgrid_topic_id" {
  description = "Event Grid system topic ID for ADF triggers"
  value       = azurerm_eventgrid_system_topic.blob_events.id
}

output "eventgrid_topic_name" {
  description = "Event Grid system topic name"
  value       = azurerm_eventgrid_system_topic.blob_events.name
}
```

### Key Changes from Previous Version

**Updated Resource References**:
- Old: `azurerm_storage_account.source.*`
- New: `azurerm_storage_account.source_shared.*`

**Output Descriptions Updated**:
- Now mention "Shared" to clarify this is not per-pod
- Event Grid outputs reference the single shared topic

**Removed Output**: `eventgrid_topic_type` (not critical for integration)

**Usage Change**:
- Old: External systems received different storage account names per pod
- New: All external systems upload to the same storage account but different folder paths

## Security Implications of Shared Storage

### RBAC Configuration for Pod Isolation

With shared storage, RBAC (Role-Based Access Control) becomes critical for preventing cross-pod data access.

**Scenario**: Pod A's ADF should only access `hr-landing/podA/*`, not `hr-landing/podB/*`

**Solution**: Use Azure RBAC conditions (currently in preview) or folder-level access patterns:

```bash
# Grant Pod A's ADF managed identity "Storage Blob Data Contributor" with conditions
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee <pod-a-adf-managed-identity-id> \
  --scope /subscriptions/.../storageAccounts/stblobdevshared123abc \
  --condition "blob path starts with 'hr-landing/podA/'"
```

Alternatively, use storage account keys or SAS tokens with path restrictions to limit access scope.

### Container-Level Access Control

While pods share the storage account, you can still apply container-level permissions:

**Pod A HR Access**: Read/Write to `hr-landing` container, `podA/*` path only
**Pod B HR Access**: Read/Write to `hr-landing` container, `podB/*` path only

This is enforced through:
1. Azure AD RBAC conditions
2. SAS tokens with path restrictions
3. ADF linked service configurations with folder filters

### Network Security Considerations

**Shared Firewall Rules**: All pods share the same firewall configuration. If you whitelist an external HR system's IP, it can access the entire storage account, so RBAC becomes even more critical.

**Private Endpoints**: Creating a private endpoint for the shared storage grants network access to all pods' data. Design your VNet/subnet architecture accordingly.

**Shared Access Signatures (SAS)**: Generate SAS tokens with:
- Specific container scope (`hr-landing` only)
- Path prefix restrictions (`podA/*` only)
- Minimal permissions (Write only, no Read/Delete)
- Short expiration times (7-30 days)

## Event Grid Filtering in ADF

### Creating Pod-Specific Event Triggers in ADF

With a shared Event Grid topic, ADF event triggers must filter events by blob path.

**Pod A's HR Trigger Configuration**:
```json
{
  "eventTrigger": {
    "scope": "/subscriptions/.../providers/Microsoft.EventGrid/systemTopics/egt-dev-shared-blob",
    "events": ["Microsoft.Storage.BlobCreated"],
    "advancedFilters": [
      {
        "key": "subject",
        "operatorType": "StringBeginsWith",
        "values": ["/blobServices/default/containers/hr-landing/blobs/podA/"]
      }
    ]
  }
}
```

This trigger only fires when:
- Event type is `BlobCreated`
- Blob path starts with `/blobServices/default/containers/hr-landing/blobs/podA/`

**Pod B's HR Trigger** uses the same pattern but with `podB/` in the path filter.

### Event Filtering Best Practices

**Use Precise Path Prefixes**: Filter by exact folder path to avoid triggering on wrong pods

**Test with Sample Events**: Upload test files to each pod folder and verify only the correct ADF pipeline triggers

**Monitor Failed Event Deliveries**: Check Event Grid metrics for delivery failures which indicate misconfigured triggers

**Implement Retry Logic**: ADF pipelines should handle duplicate events gracefully (Event Grid provides at-least-once delivery)

## Cost Comparison: Old vs. New Architecture

### Old Architecture (Per-Pod) Monthly Costs

**Storage Accounts**: 3 × $0.50 (minimal usage) = $1.50
**Event Grid Topics**: 3 × $0.60 per million events ≈ $0.30 (low volume)
**Storage Transactions**: 3 × $0.50 = $1.50
**Total**: ~$3.30/month for development environment

### New Architecture (Shared) Monthly Costs

**Storage Account**: 1 × $0.50 = $0.50
**Event Grid Topic**: 1 × $0.60 per million events = $0.20
**Storage Transactions**: 1 × $0.60 (slightly higher due to consolidated traffic) = $0.60
**Total**: ~$1.30/month for development environment

**Savings**: ~$2/month (60% reduction)

For production with higher volumes, savings scale proportionally. With 10 pods, savings could reach $20-50/month.

### TCO (Total Cost of Ownership) Considerations

**Operational Costs**: Managing one storage account requires less overhead than managing ten.

**Monitoring Costs**: Fewer Log Analytics queries needed since all events flow through one Event Grid topic.

**Complexity Costs**: Simpler Terraform code means faster development and fewer bugs.

**However**: RBAC complexity increases slightly to enforce folder-level access controls.

## Deployment Commands Summary

### Step 1: Navigate to Module Directory

```bash
cd C:\Users\User\Desktop\Delta_lake_project\terraform\modules\source-blob-storage
```

**Purpose**: Change to the source-blob-storage module directory where we'll create new files.

### Step 2: Delete Old Module Files

```bash
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\source-blob-storage\main.tf"
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\source-blob-storage\variables.tf"
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\source-blob-storage\outputs.tf"
```

**Purpose**: Remove the old per-pod architecture files before creating the new shared architecture.

**Note**: On Windows Git Bash, use quotes around paths with backslashes.

### Step 3: Create New Module Files

Files were created using the Write tool with the complete code shown in Parts 1-3 above.

### Step 4: Verify Module Files Created

```bash
ls -la C:\Users\User\Desktop\Delta_lake_project\terraform\modules\source-blob-storage\
```

**Expected Output**:
```
-rw-r--r-- 1 User 197121  7234 Oct  4 15:22 main.tf
-rw-r--r-- 1 User 197121   612 Oct  4 15:21 variables.tf
-rw-r--r-- 1 User 197121  1043 Oct  4 15:23 outputs.tf
```

## Next Steps

With the shared source blob storage module created, the next steps are:

### 1. Update Dev Environment Configuration

Edit `terraform/environments/dev/main.tf` to instantiate the new shared module:

```hcl
# Shared Source Blob Storage Module - Single storage account with folder-based pod isolation
module "source_blob_storage_shared" {
  source = "../../modules/source-blob-storage"

  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  pod_ids             = var.pods
  tags                = var.tags
}
```

**Key Difference**: No `for_each` loop because this module creates only ONE storage account shared by all pods.

### 2. Deploy the Shared Module

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply -auto-approve
```

### 3. Verify Folder Structure Created

```bash
# List all blobs in hr-landing to see folder markers
az storage blob list \
  --account-name stblobdevshared123abc \
  --container-name hr-landing \
  --output table
```

**Expected Output**:
```
Name             Blob Type    Blob Tier    Length    Content Type
---------------  -----------  -----------  --------  --------------
podA/.folder     BlockBlob    Hot          6         application/octet-stream
podB/.folder     BlockBlob    Hot          6         application/octet-stream
podC/.folder     BlockBlob    Hot          6         application/octet-stream
```

### 4. Configure ADF Event Triggers with Path Filtering

Create event triggers in each pod's ADF instance that:
- Subscribe to the shared Event Grid topic `egt-dev-shared-blob`
- Filter events by blob path prefix (e.g., `podA/` for Pod A's pipeline)
- Route files to the correct pod's data lake bronze layer

### 5. Test End-to-End with Sample Files (Department-Level)

Upload test files to each department folder:

```bash
# Test Pod A Finance department HR ingestion
echo "employee_id,name,department\n1,John Doe,Finance" > HR_EMPLOYEES_FINANCE.csv
az storage blob upload \
  --account-name stblobdevshared123abc \
  --container-name hr-landing \
  --name podA/finance/HR_EMPLOYEES.csv \
  --file HR_EMPLOYEES_FINANCE.csv \
  --auth-mode login

# Test Pod A Operations department HR ingestion
echo "employee_id,name,department\n2,Jane Smith,Operations" > HR_EMPLOYEES_OPS.csv
az storage blob upload \
  --account-name stblobdevshared123abc \
  --container-name hr-landing \
  --name podA/operations/HR_EMPLOYEES.csv \
  --file HR_EMPLOYEES_OPS.csv \
  --auth-mode login

# Test Pod B Finance department Payroll ingestion
echo "payroll_id,amount\n1,5000" > PAYROLL_FINANCE.csv
az storage blob upload \
  --account-name stblobdevshared123abc \
  --container-name payroll-landing \
  --name podB/finance/PAYROLL.csv \
  --file PAYROLL_FINANCE.csv \
  --auth-mode login
```

Verify that:
- Pod A Finance pipeline triggers for `podA/finance/HR_EMPLOYEES.csv`
- Pod A Operations pipeline triggers for `podA/operations/HR_EMPLOYEES.csv`
- Both pipelines run **simultaneously** (parallel processing)
- Pod A Finance pipeline does NOT trigger for Operations files (department isolation)

### 6. Verify Folder Structure Created

```bash
# List all folders in hr-landing (should see department-level structure)
az storage blob list \
  --account-name stblobdevshared123abc \
  --container-name hr-landing \
  --output table

# Expected output:
# Name                                   Blob Type
# -------------------------------------  -----------
# podA/finance/.folder                   BlockBlob
# podA/finance/HR_EMPLOYEES.csv          BlockBlob
# podA/operations/.folder                BlockBlob
# podA/operations/HR_EMPLOYEES.csv       BlockBlob
# podA/marketing/.folder                 BlockBlob
# podA/it/.folder                        BlockBlob
# podB/finance/.folder                   BlockBlob
# podB/operations/.folder                BlockBlob
# podB/sales/.folder                     BlockBlob
# podC/finance/.folder                   BlockBlob
# podC/hr_central/.folder                BlockBlob
# podC/compliance/.folder                BlockBlob
```

### 7. Understanding Folder Creation (Automatic vs Manual)

**Important**: Folders in Data Lake Gen2 are created automatically when files are written. You have two options:

**Option 1: Let Terraform Create Department Folders (Recommended)**
- Terraform creates `.folder` placeholder blobs for each department
- Folders visible immediately in Azure Portal
- Run: `terraform apply` and folders are created

**Option 2: Folders Created Automatically When Data Arrives**
- External systems upload files to `podA/finance/file.csv`
- Azure automatically creates the folder structure
- No manual intervention needed

**We use Option 1 (Terraform)** because:
- [DONE] Folders visible before any data arrives
- [DONE] Clear structure for external teams to upload to
- [DONE] Prevents typos in folder names
- [DONE] Infrastructure as code (repeatable)

## Command Reference

Complete command reference for this step:

```bash
# ═══════════════════════════════════════════════════════════════
# CLEANUP COMMANDS
# ═══════════════════════════════════════════════════════════════

# Destroy all existing infrastructure
cd terraform/environments/dev
terraform destroy -auto-approve

# Delete old module files
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\source-blob-storage\main.tf"
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\source-blob-storage\variables.tf"
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\source-blob-storage\outputs.tf"

# ═══════════════════════════════════════════════════════════════
# MODULE CREATION
# ═══════════════════════════════════════════════════════════════

# Navigate to module directory
cd C:\Users\User\Desktop\Delta_lake_project\terraform\modules\source-blob-storage

# Verify files created (after using Write tool)
ls -la

# ═══════════════════════════════════════════════════════════════
# DEPLOYMENT COMMANDS
# ═══════════════════════════════════════════════════════════════

# Navigate to dev environment
cd C:\Users\User\Desktop\Delta_lake_project\terraform\environments\dev

# Initialize Terraform with new module
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# Preview deployment
terraform plan

# Deploy resources
terraform apply -auto-approve

# ═══════════════════════════════════════════════════════════════
# VERIFICATION COMMANDS
# ═══════════════════════════════════════════════════════════════

# List storage accounts (should see 1 shared account)
az storage account list \
  --resource-group rg-delta-lake-dev \
  --query "[?starts_with(name, 'stblob')].{Name:name, SKU:sku.name, HNS:isHnsEnabled}" \
  --output table

# List containers in shared storage
az storage container list \
  --account-name stblobdevshared123abc \
  --output table

# List folder markers in hr-landing
az storage blob list \
  --account-name stblobdevshared123abc \
  --container-name hr-landing \
  --output table

# Verify Event Grid topic (should see 1 shared topic)
az eventgrid system-topic list \
  --resource-group rg-delta-lake-dev \
  --output table

# Check change feed enabled
az storage account blob-service-properties show \
  --account-name stblobdevshared123abc \
  --resource-group rg-delta-lake-dev \
  --query changeFeed.enabled

# ═══════════════════════════════════════════════════════════════
# TESTING COMMANDS
# ═══════════════════════════════════════════════════════════════

# Upload test file to Pod A HR folder
echo "Pod A HR test data" > test-poda-hr.txt
az storage blob upload \
  --account-name stblobdevshared123abc \
  --container-name hr-landing \
  --name podA/test-poda-hr.txt \
  --file test-poda-hr.txt \
  --auth-mode login

# Upload test file to Pod B Payroll folder
echo "Pod B Payroll test data" > test-podb-payroll.txt
az storage blob upload \
  --account-name stblobdevshared123abc \
  --container-name payroll-landing \
  --name podB/test-podb-payroll.txt \
  --file test-podb-payroll.txt \
  --auth-mode login

# List all blobs to verify folder structure
az storage blob list \
  --account-name stblobdevshared123abc \
  --container-name hr-landing \
  --prefix podA/ \
  --output table

# Download a test file
az storage blob download \
  --account-name stblobdevshared123abc \
  --container-name hr-landing \
  --name podA/test-poda-hr.txt \
  --file downloaded-test.txt \
  --auth-mode login

# Delete a test file
az storage blob delete \
  --account-name stblobdevshared123abc \
  --container-name hr-landing \
  --name podA/test-poda-hr.txt \
  --auth-mode login
```

## Files Modified/Created in This Step

```
terraform/modules/source-blob-storage/
├── variables.tf   - REPLACED: Removed pod_id, added pod_ids list
├── main.tf        - REPLACED: Single shared storage, 9 folder markers, 1 Event Grid topic
└── outputs.tf     - REPLACED: Updated resource references to source_shared

terraform/environments/dev/
└── main.tf        - TO BE UPDATED: Change from for_each loop to single module instantiation
```

## Latest Update: Archive Folders for Preventing Reprocessing

### What Was Added (October 2025)

**Problem Solved**: Files in landing zone were being reprocessed on every pipeline run, creating duplicates and wasting resources.

**Solution Implemented**: Archive pattern with Terraform-managed folder structure.

### Terraform Changes Made

**File**: `terraform/modules/source-blob-storage/main.tf`

**Added Local Variable for Archive Folders**:
```hcl
locals {
  # Archive folders for processed files (prevents reprocessing)
  # Structure: landing/{pod}/{company}/archive/
  archive_folders = flatten([
    for pod, config in var.companies : [
      for company in config.companies : {
        pod     = pod
        company = company
        path    = "${pod}/${company}/archive/.folder"
      }
    ]
  ])
}
```

**Added Archive Folder Resource**:
```hcl
# Archive folder structure for processed files
# Prevents reprocessing by moving completed files to archive with date stamps
resource "azurerm_storage_blob" "archive_folders" {
  for_each = { for item in local.archive_folders : "${item.pod}-${item.company}-archive" => item }

  name                   = each.value.path
  storage_account_name   = azurerm_storage_account.source_shared.name
  storage_container_name = azurerm_storage_container.landing.name
  type                   = "Block"
  source_content         = "archive_folder"
}
```

**Enhanced Lifecycle Management**:
- Old: Delete all files after 30 days
- New: Landing files (30 days), Archive files (90 days for audit trail)

### Archive Folders Created

**10 archive folders across all pods**:
- podA: finance/archive/, operations/archive/, marketing/archive/, it/archive/
- podB: finance/archive/, operations/archive/, sales/archive/
- podC: finance/archive/, hr_central/archive/, compliance/archive/

### ADF Integration

**Step 16a in ADF Pipeline**:
After `Copy_to_Bronze` activity succeeds, `Archive_Processed_Files` activity:
1. Copies files from `landing/{pod}/{company}/` to `landing/{pod}/{company}/archive/{yyyymmdd}/`
2. Deletes source files (moves them)
3. Next run only sees NEW files

**Dataset Required**: `ds_landing_archive` with parameters:
- `pod_id`, `company`, `archive_date`, `file_name`

### Verification Commands

```bash
# List all archive folders
az storage blob list \
  --account-name stblobdevsharedb0re7y \
  --container-name landing \
  --query "[?contains(name, 'archive')].name" \
  -o table

# Expected output:
# podA/finance/archive/.folder
# podA/operations/archive/.folder
# podA/marketing/archive/.folder
# podA/it/archive/.folder
# podB/finance/archive/.folder
# podB/operations/archive/.folder
# podB/sales/archive/.folder
# podC/finance/archive/.folder
# podC/hr_central/archive/.folder
# podC/compliance/archive/.folder
```

### Current Storage Structure

```
stblobdevsharedb0re7y/
└── landing/
    ├── podA/
    │   ├── finance/
    │   │   ├── archive/          ← NEW: Processed files
    │   │   │   ├── 20250115/     ← Date-stamped
    │   │   │   └── 20250116/
    │   │   └── *.csv             ← Active: New files
    │   ├── operations/
    │   │   ├── archive/          ← NEW
    │   │   └── *.csv
    │   ├── marketing/
    │   │   ├── archive/          ← NEW
    │   │   └── *.csv
    │   └── it/
    │       ├── archive/          ← NEW
    │       └── *.csv
    ├── podB/ (same structure)
    └── podC/ (same structure)
```

### Benefits Achieved

- COMPLETED: No duplicate processing - files processed once, then archived
- COMPLETED: Smart processing - only new files trigger clusters
- COMPLETED: Cost optimization - empty runs skip cluster creation
- COMPLETED: Audit trail - 90-day archive retention for compliance
- COMPLETED: Reprocessing capability - can restore from archive if needed
- COMPLETED: Automatic cleanup - lifecycle policies manage storage costs

## Key Takeaways

- **Shared infrastructure reduces costs by 60%** compared to per-pod isolated storage
- **Folder-based isolation** provides logical separation without physical infrastructure duplication
- **Event Grid filtering in ADF** ensures pod isolation even with a shared Event Grid topic
- **Folder markers** (`.folder` blobs) make the folder structure visible before data files exist
- **Archive pattern prevents reprocessing** - processed files moved to archive with date stamps
- **Two-tier lifecycle management** - 30 days landing, 90 days archive
- **RBAC becomes more critical** when pods share infrastructure resources
- **One storage account, one container, 10 companies, 10 archive folders** serve all pods
- **Terraform code is simpler** without `for_each` loops for storage account creation
- **Scalability improves** - adding company just requires folders, not new infrastructure
- **Operational overhead decreases** with fewer resources to monitor and manage
- **ADF event triggers** must use path prefix filters to ensure correct pod routing
