# Step 12: Shared Data Lake Gen2 Module with Folder-Based Pod Isolation

## Overview

In this step, we completely redesign the Data Lake Storage Gen2 architecture from a per-pod isolated storage model to a **shared infrastructure model with folder-based pod isolation**. This represents a fundamental architectural shift where all pods share a single ADLS Gen2 storage account with the medallion architecture implemented through a hierarchical folder structure.

## Architecture Evolution: From Isolated to Shared

### Previous Architecture (Per-Pod Isolation)

The original design created **3 separate ADLS Gen2 storage accounts**:

```
Pod A: stdldevpoda123abc/
├─ podabronze/ (filesystem)
│  ├─ hr/
│  └─ payroll/
├─ podasilver/ (filesystem)
│  ├─ hr/
│  └─ payroll/
└─ podagold/ (filesystem)
   ├─ hr/
   └─ payroll/

Pod B: stdldevpodb456def/
├─ podbbronze/
├─ podbsilver/
└─ podbgold/

Pod C: stdldevpodc789ghi/
├─ podcbronze/
├─ podcsilver/
└─ podcgold/
```

**Pros of Old Architecture**:
- Complete infrastructure isolation between pods
- Independent storage account limits per pod
- Separate encryption boundaries
- Clear cost allocation per pod
- No risk of one pod affecting another's performance

**Cons of Old Architecture**:
- Higher costs (3 storage accounts × ~$20/month = $60/month minimum)
- More complex infrastructure management
- Redundant configuration across pods
- Harder to implement cross-pod analytics
- More resources to monitor and secure

### New Architecture (Shared with Department-Level Isolation)

The new design creates **1 shared ADLS Gen2 storage account** with medallion layers as filesystems and a department-level folder hierarchy:

```
stdldevshared123abc/
├─ bronze/ (filesystem)
│  ├─ podA/
│  │  ├─ finance/
│  │  │  ├─ hr/
│  │  │  ├─ payroll/
│  │  │  ├─ finance/
│  │  │  ├─ inventory/
│  │  │  └─ ... (9 domains total)
│  │  ├─ operations/
│  │  │  ├─ hr/
│  │  │  ├─ payroll/
│  │  │  └─ ... (9 domains)
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
├─ silver/ (filesystem - same structure)
├─ gold/ (filesystem)
│  ├─ podA/
│  │  ├─ finance/
│  │  │  └─ analytics/
│  │  ├─ operations/
│  │  │  └─ analytics/
│  │  └─ ...
│  ├─ config/ (shared configuration)
│  └─ pipeline_metrics/ (shared observability)
```

**Pros of New Architecture**:
- Lower costs (~$20/month for shared account vs $60/month for 3 separate)
- **Department-level granularity**: Each department can be processed independently
- **Parallel processing**: All departments within a pod can run simultaneously
- **Cost attribution**: Track exact cost per department
- **Scalability**: Add new department = update variable, no infrastructure changes
- Simplified infrastructure management
- Easier cross-pod data sharing when needed
- Single pane of glass for monitoring all data
- Reduced Terraform code complexity
- Better for multi-pod analytics and reporting

**Cons of New Architecture**:
- Pods share the same storage account throughput limits
- RBAC must be carefully configured for folder-level isolation
- More complex folder structure (pod → department → domain)
- Folder structure must be consistently maintained
- One misconfigured policy could affect all pods

### Why Make This Change?

**Cost Optimization**: Reduces Azure storage costs by ~66% for development and ~50% for production environments.

**Department-Level Granularity**: Manager's requirement - each pod manages 3-4 departments (e.g., podA has finance, operations, marketing, IT). Each department processes data independently with its own job cluster.

**Parallel Department Processing**: All departments within a pod can process data simultaneously. Finance and Operations run at the same time with separate ephemeral job clusters.

**Cost Attribution**: Track exactly what each department costs. Power BI reports show finance department used 50 DBUs, operations used 35 DBUs.

**Operational Simplicity**: Managing one ADLS Gen2 account is significantly easier than managing three separate accounts.

**Scalability**: Adding a new department (e.g., podA adds "hr_local") just requires updating the `departments` variable and running `terraform apply`. No code changes needed.

**Cross-Pod Analytics**: Enables joining data across pods for enterprise-wide reporting without complex cross-account access.

**Compliance**: Many organizations prefer consolidating PII data in fewer storage accounts for easier audit and compliance management.

## Understanding ADLS Gen2 Hierarchical Namespace

### What Makes ADLS Gen2 Different from Blob Storage

Azure Data Lake Storage Gen2 is **not** regular blob storage. When you enable the hierarchical namespace (`is_hns_enabled = true`), you transform the storage account into a true file system with:

**True Directories**: ADLS Gen2 has real directories, not just simulated folders through blob name prefixes.

**Atomic Operations**: Directory rename and delete operations are atomic, meaning they complete fully or not at all.

**POSIX Compliance**: Supports file and directory-level access control lists (ACLs).

**Performance**: Optimized for big data analytics with high throughput for large files.

**Compatibility**: Works seamlessly with Databricks, Spark, and Hadoop ecosystems.

### Critical Difference: is_hns_enabled = true

```hcl
# BLOB STORAGE (is_hns_enabled = false)
# - Folders are simulated through blob name prefixes
# - No atomic directory operations
# - Limited access control granularity
# - Uses blob endpoint: https://account.blob.core.windows.net/

# ADLS GEN2 (is_hns_enabled = true)
# - True hierarchical directories
# - Atomic directory operations
# - Directory and file-level ACLs
# - Uses DFS endpoint: https://account.dfs.core.windows.net/
```

**WARNING**: Once you set `is_hns_enabled = true`, it **cannot be changed**. You must create a new storage account if you need to change this setting.

## Understanding the Medallion Architecture

The medallion architecture organizes data into three progressive refinement layers:

### Bronze Layer - Raw Data Landing Zone

**Purpose**: Store data exactly as received from source systems with minimal transformation.

**Characteristics**:
- Schema-on-read approach (no enforced schema)
- Preserves original data format (CSV, JSON, Parquet, etc.)
- Immutable historical archive
- Serves as recovery point if downstream processing fails

**Example Data**:
```
bronze/podA/finance/hr/
├─ employees_2025-01-15.csv (raw CSV from HRIS)
├─ timecards_2025-01-15.json (raw JSON from time tracking)
└─ org_structure_2025-01-15.xml (raw XML from directory)

bronze/podA/finance/payroll/
├─ payroll_2025-01-15.csv (raw CSV from payroll system)
```

### Silver Layer - Cleansed and Validated Data

**Purpose**: Store cleansed, validated, and conformed data ready for analytics.

**Characteristics**:
- Schema enforced (Delta Lake tables)
- Data quality rules applied
- Duplicates removed
- Data types validated and corrected
- Standardized formats

**Example Data**:
```
silver/podA/finance/hr/
├─ employees/ (Delta Lake table)
│  ├─ _delta_log/
│  ├─ part-00000.parquet
│  └─ part-00001.parquet
├─ timecards/ (Delta Lake table)
└─ org_structure/ (Delta Lake table)

silver/podA/operations/inventory/
├─ stock_levels/ (Delta Lake table)
└─ warehouse_transactions/ (Delta Lake table)
```

### Gold Layer - Business-Ready Aggregated Data

**Purpose**: Store aggregated, denormalized data optimized for consumption by BI tools.

**Characteristics**:
- Business logic applied
- Aggregations and KPIs calculated
- Denormalized for query performance
- Optimized partitioning for reporting

**Example Data**:
```
gold/podA/finance/analytics/
├─ employee_headcount_by_department/ (aggregated metrics)
├─ payroll_summary_monthly/ (KPIs)
└─ labor_cost_analysis/ (business intelligence)

gold/podA/operations/analytics/
├─ inventory_turnover/ (KPIs)
└─ warehouse_efficiency/ (business intelligence)

gold/config/ (SHARED ACROSS ALL PODS)
└─ departments/ (Delta table: department configuration)

gold/pipeline_metrics/ (SHARED ACROSS ALL PODS)
├─ execution_logs/ (Delta table: pipeline run history)
└─ cost_attribution/ (Delta table: cost per department)
```

## Department-Level Isolation Strategy

### How Department-Level Isolation Works

The architecture uses a **three-level hierarchy** for complete department isolation:

**Pod → Department → Domain**

Examples:
- **Pod A Finance Dept**: `bronze/podA/finance/hr/employees.csv`
- **Pod A Operations Dept**: `bronze/podA/operations/hr/employees.csv`
- **Pod B Finance Dept**: `bronze/podB/finance/hr/employees.csv`

All departments share the same storage account, but each department has its own complete folder hierarchy across all domains and layers.

### Department Configuration per Pod

Each pod has a unique set of departments:

| Pod | Departments |
|-----|-------------|
| **podA** | finance, operations, marketing, it |
| **podB** | finance, operations, sales |
| **podC** | finance, hr_central, compliance |

Each department processes **9 business domains**: hr, payroll, finance, inventory, campaigns, tickets, crm, benefits, audit_logs

### Enforcing Isolation with RBAC and ACLs

**Azure RBAC (Resource-Level)**:
Grant storage account-level roles with path conditions for department-level isolation:

```bash
# Pod A Finance Department job cluster gets access to podA/finance paths only
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee <finance-job-cluster-identity> \
  --scope /subscriptions/.../storageAccounts/stdldevshared123abc \
  --condition "container equals 'bronze' and path starts with 'podA/finance/'"
```

**ADLS Gen2 ACLs (Directory-Level)**:
Set access control lists directly on department directories:

```bash
# Grant Finance Department's job cluster rwx on bronze/podA/finance/ directory
az storage fs access set \
  --account-name stdldevshared123abc \
  --file-system bronze \
  --path podA/finance \
  --permissions "user:<finance-cluster-sp-object-id>:rwx" \
  --acl "default:user:<finance-cluster-sp-object-id>:rwx"
```

**The combination ensures**:
- Finance dept can only access `bronze/podA/finance/`, `silver/podA/finance/`, `gold/podA/finance/`
- Operations dept can only access `bronze/podA/operations/`, `silver/podA/operations/`, `gold/podA/operations/`
- Each department is completely isolated with its own folder hierarchy
- Job clusters are ephemeral - created with department-specific permissions, destroyed after use

## Part 1: Destroying Old Per-Pod Infrastructure

Before creating the new shared module, we need to completely destroy the old per-pod architecture.

### Complete Infrastructure Destruction

Navigate to the dev environment and destroy all existing resources:

```bash
cd C:\Users\User\Desktop\Delta_lake_project\terraform\environments\dev
terraform destroy -auto-approve
```

**Command Explanation**:
- `terraform destroy`: Command to delete all resources managed by Terraform
- `-auto-approve`: Automatically confirms destruction without prompting for "yes"
- Deletes all storage accounts, Databricks workspaces, ADF instances, Log Analytics, etc.
- Terraform state file is updated to reflect empty infrastructure
- Takes 10-15 minutes due to Databricks workspace deletion time

**Expected Output**:
```
Destroy complete! Resources: 67 destroyed.

The state file is empty. No resources are represented.
```

### Deleting Old Module Files

Remove the old per-pod data-lake module files:

```bash
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\data-lake\main.tf"
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\data-lake\variables.tf"
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\data-lake\outputs.tf"
```

**Command Explanation**:
- `rm`: Remove/delete command
- Quotes around paths handle Windows path format with backslashes
- Clears out the old per-pod architecture completely
- Prepares the module directory for new shared architecture files

**Verification**:
```bash
ls "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\data-lake\"
```

Should show empty directory or no files.

## Part 2: Module Variables (variables.tf)

The variables file introduces **department-level configuration** allowing each pod to have its own unique set of departments.

### Department-Level Variables

The current `terraform/modules/data-lake/variables.tf` contains:

```hcl
# Variables for Shared Data Lake Gen2 Module
# This module creates ONE ADLS Gen2 storage account shared by all pods
# Medallion architecture with department-level folder isolation

variable "resource_group_name" {
  description = "Resource group name for shared data lake"
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

variable "departments" {
  description = "Map of pod to department configuration for folder creation"
  type = map(object({
    departments = list(string)
  }))
  default = {
    podA = {
      departments = ["finance", "operations", "marketing", "it"]
    }
    podB = {
      departments = ["finance", "operations", "sales"]
    }
    podC = {
      departments = ["finance", "hr_central", "compliance"]
    }
  }
}

variable "domains" {
  description = "List of business domains processed by departments (hr, payroll, inventory, etc.)"
  type        = list(string)
  default     = ["hr", "payroll", "finance", "inventory", "campaigns", "tickets", "crm", "benefits", "audit_logs"]
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
```

### Key Changes from Previous Version

**Added**: `variable "departments"` (map of pod to department list) - Each pod can have different departments

**Expanded**: `variable "domains"` - Now includes 9 domains instead of 3

**Storage Naming Change**:
- Old: `stdl${var.environment}${var.pod_id}${random}` → stdldevpoda123abc
- New: `stdl${var.environment}shared${random}` → stdldevshared123abc

### Understanding the Variables

**pod_ids**: List of pod identifiers. Default: `["podA", "podB", "podC"]`

**departments**: Map defining which departments belong to which pod. podA has 4 departments (finance, operations, marketing, it), while podB only has 3 (finance, operations, sales).

**domains**: List of business domains that each department processes. All departments get all 9 domain folders created.

**The combination creates the complete folder structure**:
- 3 layers (bronze, silver, gold)
- × 3 pods (podA, podB, podC)
- × 10 departments total (4 in podA + 3 in podB + 3 in podC)
- × 9 domains per department
- = **540 domain-level folders** + 30 department folders + 9 pod folders + 2 config folders = **~671 total directories**

## Part 3: Main Module Resources (main.tf)

The main file uses **dynamic Terraform loops** to create department-level folder structures based on configuration variables.

### Department-Level Folder Creation Strategy

The current `terraform/modules/data-lake/main.tf` contains:

1. **Random String Generator** (6 characters, lowercase alphanumeric)
2. **Shared ADLS Gen2 Storage Account** with `is_hns_enabled = true`
3. **3 Medallion Layer Filesystems** (bronze, silver, gold)
4. **Dynamic Department Folder Creation** using `for_each` loops
5. **Dynamic Domain Folder Creation** using nested `flatten` operations
6. **Shared Config and Pipeline Metrics Folders** in Gold layer

### Key Implementation Details

Instead of hardcoded resources for each folder, the module uses **Terraform locals** to dynamically generate folder structures:

```hcl
locals {
  # Flatten department structure for iteration
  department_folders = flatten([
    for pod, config in var.departments : [
      for dept in config.departments : {
        pod        = pod
        department = dept
        key        = "${pod}-${dept}"
      }
    ]
  ])

  department_map = { for item in local.department_folders : item.key => item }

  # Create all combinations of pod/department/domain
  bronze_domain_folders = flatten([
    for pod, config in var.departments : [
      for dept in config.departments : [
        for domain in var.domains : {
          pod        = pod
          department = dept
          domain     = domain
          key        = "${pod}-${dept}-${domain}"
          path       = "${pod}/${dept}/${domain}"
        }
      ]
    ]
  ])

  bronze_domain_map = { for item in local.bronze_domain_folders : item.key => item }
}
```

**This approach allows**:
- Adding a new department = just update `departments` variable
- No code changes required for scaling
- Consistent folder structure across all layers

### Understanding the Storage Account Configuration

```hcl
resource "azurerm_storage_account" "datalake_shared" {
  name                          = "stdl${var.environment}shared${random_string.suffix.result}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  account_kind                  = "StorageV2"
  is_hns_enabled                = true  # CRITICAL: Enables ADLS Gen2
  min_tls_version               = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled = true

  tags = var.tags
}
```

**Critical Parameters Explained**:

**name**: `stdldevshared123abc` format
- `stdl`: Storage Data Lake prefix
- `dev`: Environment identifier
- `shared`: Indicates this is shared across pods (not per-pod)
- `123abc`: Random 6-character suffix for global uniqueness

**is_hns_enabled = true**: **THE MOST CRITICAL SETTING**
- Transforms the storage account into ADLS Gen2
- Enables hierarchical namespace with true directories
- Cannot be changed after creation
- Required for Delta Lake and Spark workloads
- Enables POSIX-compliant file and directory ACLs

**account_tier = "Standard"**: Uses HDD-based storage
- Premium tier uses SSDs (faster, more expensive)
- Standard is appropriate for most data lake workloads
- Cost-effective for large datasets

**account_replication_type = "LRS"**: Locally Redundant Storage
- 3 copies within a single datacenter
- Cost-effective for dev environments
- Production should consider GRS (Geo-Redundant) or ZRS (Zone-Redundant)

### Understanding the Medallion Filesystems

```hcl
resource "azurerm_storage_data_lake_gen2_filesystem" "bronze" {
  name               = "bronze"
  storage_account_id = azurerm_storage_account.datalake_shared.id
}
```

**What is a Filesystem?**
- In ADLS Gen2, a "filesystem" is equivalent to a "container" in blob storage
- Think of it as the top-level organizational unit
- We create three filesystems representing the three medallion layers
- Each filesystem will contain pod folders and domain subfolders

**Why Bronze, Silver, Gold as Filesystems?**
- Organizes data by refinement level at the highest tier
- Makes it easy to apply different policies per layer (e.g., retention, access)
- Clear separation of raw data from production-ready data
- Aligns with industry-standard medallion architecture

### Understanding the Directory Structure

The module creates **~671 directories** in a four-level hierarchy using dynamic `for_each` loops:

**Level 1: Pod Folders (9 directories)**
```hcl
# Dynamically create pod folders using for_each
resource "azurerm_storage_data_lake_gen2_path" "bronze_pod" {
  for_each = toset(var.pod_ids)

  path               = each.value
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.bronze.name
  storage_account_id = azurerm_storage_account.datalake_shared.id
  resource           = "directory"
}
```

Creates: `bronze/podA/`, `bronze/podB/`, `bronze/podC/` (and same for silver/gold)

**Level 2: Department Folders (30 directories)**
```hcl
# Dynamically create department folders using flattened map
resource "azurerm_storage_data_lake_gen2_path" "bronze_department" {
  for_each = local.department_map

  path               = "${each.value.pod}/${each.value.department}"
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.bronze.name
  storage_account_id = azurerm_storage_account.datalake_shared.id
  resource           = "directory"

  depends_on = [azurerm_storage_data_lake_gen2_path.bronze_pod]
}
```

Creates:
- `bronze/podA/finance/`, `bronze/podA/operations/`, `bronze/podA/marketing/`, `bronze/podA/it/`
- `bronze/podB/finance/`, `bronze/podB/operations/`, `bronze/podB/sales/`
- `bronze/podC/finance/`, `bronze/podC/hr_central/`, `bronze/podC/compliance/`
- Same pattern for silver and gold layers

**Level 3: Domain Folders (540 directories)**
```hcl
# Dynamically create domain folders under each department
resource "azurerm_storage_data_lake_gen2_path" "bronze_domain" {
  for_each = local.bronze_domain_map

  path               = each.value.path  # e.g., "podA/finance/hr"
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.bronze.name
  storage_account_id = azurerm_storage_account.datalake_shared.id
  resource           = "directory"

  depends_on = [azurerm_storage_data_lake_gen2_path.bronze_department]
}
```

Creates all combinations (10 departments × 9 domains × 3 layers):
- `bronze/podA/finance/hr/`, `bronze/podA/finance/payroll/`, ... (9 domains)
- `bronze/podA/operations/hr/`, `bronze/podA/operations/payroll/`, ... (9 domains)
- Same for all departments, all pods, all layers

**Level 4: Analytics and Config Folders (Gold layer)**
```hcl
# Gold analytics folders per department
resource "azurerm_storage_data_lake_gen2_path" "gold_analytics" {
  for_each = local.department_map

  path               = "${each.value.pod}/${each.value.department}/analytics"
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.gold.name
  storage_account_id = azurerm_storage_account.datalake_shared.id
  resource           = "directory"

  depends_on = [azurerm_storage_data_lake_gen2_path.gold_department]
}

# Shared config and metrics folders
resource "azurerm_storage_data_lake_gen2_path" "gold_config" {
  path               = "config"
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.gold.name
  storage_account_id = azurerm_storage_account.datalake_shared.id
  resource           = "directory"
}

resource "azurerm_storage_data_lake_gen2_path" "gold_pipeline_metrics" {
  path               = "pipeline_metrics"
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.gold.name
  storage_account_id = azurerm_storage_account.datalake_shared.id
  resource           = "directory"
}
```

**The depends_on Block**:
```hcl
depends_on = [azurerm_storage_data_lake_gen2_path.bronze_department]
```

This ensures:
- Parent directory (`podA/finance/`) is created before child directory (`podA/finance/hr/`)
- Prevents race conditions during parallel resource creation
- Terraform creates directories in correct hierarchical order

### Complete Folder Hierarchy Visualization

```
stdldevshared123abc/
│
├─ bronze/ (filesystem)
│  ├─ podA/ (directory)
│  │  ├─ finance/ (department directory)
│  │  │  ├─ hr/ (domain directory)
│  │  │  ├─ payroll/
│  │  │  ├─ finance/
│  │  │  ├─ inventory/
│  │  │  ├─ campaigns/
│  │  │  ├─ tickets/
│  │  │  ├─ crm/
│  │  │  ├─ benefits/
│  │  │  └─ audit_logs/
│  │  ├─ operations/ (department directory)
│  │  │  ├─ hr/
│  │  │  ├─ payroll/
│  │  │  └─ ... (9 domains)
│  │  ├─ marketing/ (department directory)
│  │  │  └─ ... (9 domains)
│  │  └─ it/ (department directory)
│  │     └─ ... (9 domains)
│  ├─ podB/ (directory)
│  │  ├─ finance/
│  │  │  └─ ... (9 domains)
│  │  ├─ operations/
│  │  │  └─ ... (9 domains)
│  │  └─ sales/
│  │     └─ ... (9 domains)
│  └─ podC/ (directory)
│     ├─ finance/
│     │  └─ ... (9 domains)
│     ├─ hr_central/
│     │  └─ ... (9 domains)
│     └─ compliance/
│        └─ ... (9 domains)
│
├─ silver/ (filesystem - same department/domain structure as bronze)
│  ├─ podA/
│  │  ├─ finance/
│  │  │  ├─ hr/
│  │  │  └─ ... (9 domains)
│  │  ├─ operations/
│  │  ├─ marketing/
│  │  └─ it/
│  ├─ podB/
│  └─ podC/
│
└─ gold/ (filesystem)
   ├─ podA/
   │  ├─ finance/
   │  │  └─ analytics/
   │  ├─ operations/
   │  │  └─ analytics/
   │  ├─ marketing/
   │  │  └─ analytics/
   │  └─ it/
   │     └─ analytics/
   ├─ podB/
   │  ├─ finance/
   │  │  └─ analytics/
   │  ├─ operations/
   │  │  └─ analytics/
   │  └─ sales/
   │     └─ analytics/
   ├─ podC/
   │  ├─ finance/
   │  │  └─ analytics/
   │  ├─ hr_central/
   │  │  └─ analytics/
   │  └─ compliance/
   │     └─ analytics/
   ├─ config/ (SHARED CONFIGURATION)
   │  └─ departments/ (Delta table with dept metadata)
   └─ pipeline_metrics/ (SHARED OBSERVABILITY)
      ├─ execution_logs/
      └─ cost_attribution/
```

### Why Pre-Create All Directories?

**Consistency**: Every department has exactly the same domain folder structure across all layers.

**Department Isolation**: Each department gets its own complete folder hierarchy for independent processing.

**Access Control**: Directories can have ACLs set during creation, establishing department-level security from the start.

**Documentation**: The infrastructure-as-code documents the expected data organization at department level.

**Validation**: Ensures the structure exists before department-specific pipelines run, preventing runtime errors.

**Governance**: Prevents ad-hoc folder creation that could violate data governance policies.

**Parallel Processing**: Each department folder is independent, enabling simultaneous processing by separate job clusters.

## Part 4: Module Outputs (outputs.tf)

The outputs file provides connection information and folder paths for integration with Databricks, ADF, and other services.

### Creating the New Outputs File

Create `terraform/modules/data-lake/outputs.tf`:

```hcl
# Outputs for Shared Data Lake Gen2 Module
# Provides connection information for all pods to access shared medallion architecture

output "storage_account_id" {
  description = "Shared Data Lake Gen2 storage account resource ID"
  value       = azurerm_storage_account.datalake_shared.id
}

output "storage_account_name" {
  description = "Shared Data Lake Gen2 storage account name"
  value       = azurerm_storage_account.datalake_shared.name
}

output "primary_dfs_endpoint" {
  description = "Primary ADLS Gen2 endpoint (abfss:// protocol)"
  value       = azurerm_storage_account.datalake_shared.primary_dfs_endpoint
}

output "bronze_filesystem_name" {
  description = "Bronze layer container name"
  value       = azurerm_storage_data_lake_gen2_filesystem.bronze.name
}

output "silver_filesystem_name" {
  description = "Silver layer container name"
  value       = azurerm_storage_data_lake_gen2_filesystem.silver.name
}

output "gold_filesystem_name" {
  description = "Gold layer container name"
  value       = azurerm_storage_data_lake_gen2_filesystem.gold.name
}

output "pod_folder_structure" {
  description = "Complete medallion folder structure per pod"
  value = {
    for pod_id in var.pod_ids :
    pod_id => {
      bronze_paths = [for domain in var.domains : "bronze/${pod_id}/${domain}/"]
      silver_paths = [for domain in var.domains : "silver/${pod_id}/${domain}/"]
      gold_paths   = [for domain in var.domains : "gold/${pod_id}/${domain}/"]
    }
  }
}
```

### Understanding the Outputs

**storage_account_id**: Full Azure resource ID
```
/subscriptions/e97fa8c6-457d-495f-aa82-0d87e72f5842/resourceGroups/rg-delta-lake-dev/providers/Microsoft.Storage/storageAccounts/stdldevshared123abc
```

Used for:
- RBAC role assignments to grant Databricks access
- Diagnostic settings configuration
- Linking to ADF or other services

**storage_account_name**: Globally unique name like `stdldevshared123abc`

Used for:
- Constructing connection strings
- Configuring Azure Storage Explorer
- CLI commands and SDK connections

**primary_dfs_endpoint**: The ADLS Gen2 DFS endpoint
```
https://stdldevshared123abc.dfs.core.windows.net/
```

**CRITICAL**: Notice `.dfs.` instead of `.blob.` in the URL
- This is the Data File System endpoint specific to ADLS Gen2
- Databricks and Spark use this endpoint for Delta Lake operations
- Regular blob endpoint won't work for hierarchical namespace features

**Filesystem Name Outputs**: Provides the names `bronze`, `silver`, `gold`

Used for:
- Configuring Databricks mount points
- ADF pipeline destinations
- Monitoring dashboards
- Documentation

**pod_folder_structure**: **Dynamic Computed Output**

Example output value:
```json
{
  "podA": {
    "bronze_paths": ["bronze/podA/hr/", "bronze/podA/payroll/", "bronze/podA/finance/"],
    "silver_paths": ["silver/podA/hr/", "silver/podA/payroll/", "silver/podA/finance/"],
    "gold_paths": ["gold/podA/hr/", "gold/podA/payroll/", "gold/podA/finance/"]
  },
  "podB": {
    "bronze_paths": ["bronze/podB/hr/", "bronze/podB/payroll/", "bronze/podB/finance/"],
    "silver_paths": ["silver/podB/hr/", "silver/podB/payroll/", "silver/podB/finance/"],
    "gold_paths": ["gold/podB/hr/", "gold/podB/payroll/", "gold/podB/finance/"]
  },
  "podC": {
    "bronze_paths": ["bronze/podC/hr/", "bronze/podC/payroll/", "bronze/podC/finance/"],
    "silver_paths": ["silver/podC/hr/", "silver/podC/payroll/", "silver/podC/finance/"],
    "gold_paths": ["gold/podC/hr/", "gold/podC/payroll/", "gold/podC/finance/"]
  }
}
```

**This output is extremely valuable for**:
- Programmatically accessing all folder paths
- Generating Databricks mount point configurations
- Creating ADF pipeline parameters
- Documentation generation
- Testing and validation scripts

## Accessing ADLS Gen2 from Databricks

### Databricks Mount Points

Databricks can mount ADLS Gen2 paths to make them accessible as file system paths:

```python
# Mount Pod A's bronze HR folder
configs = {
  "fs.azure.account.auth.type": "OAuth",
  "fs.azure.account.oauth.provider.type": "org.apache.hadoop.fs.azurebfs.oauth2.ClientCredsTokenProvider",
  "fs.azure.account.oauth2.client.id": "<databricks-service-principal-id>",
  "fs.azure.account.oauth2.client.secret": "<service-principal-secret>",
  "fs.azure.account.oauth2.client.endpoint": "https://login.microsoftonline.com/<tenant-id>/oauth2/token"
}

dbutils.fs.mount(
  source = "abfss://bronze@stdldevshared123abc.dfs.core.windows.net/podA/hr",
  mount_point = "/mnt/bronze/poda/hr",
  extra_configs = configs
)
```

### ABFSS Protocol

The `abfss://` protocol is specific to ADLS Gen2:
- **abfss** = Azure Blob File System Secure (HTTPS)
- **abfs** = Azure Blob File System (HTTP)
- Format: `abfss://<filesystem>@<storage-account>.dfs.core.windows.net/<path>`

Example paths:
- `abfss://bronze@stdldevshared123abc.dfs.core.windows.net/podA/hr/employees.parquet`
- `abfss://silver@stdldevshared123abc.dfs.core.windows.net/podB/payroll/timecards/`
- `abfss://gold@stdldevshared123abc.dfs.core.windows.net/podC/finance/monthly_summary/`

## Security Implementation for Shared Storage

### RBAC Strategy

**Grant storage account-level roles**:

```bash
# Pod A's Databricks workspace managed identity
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee <pod-a-databricks-managed-identity-object-id> \
  --scope /subscriptions/.../resourceGroups/rg-delta-lake-dev/providers/Microsoft.Storage/storageAccounts/stdldevshared123abc
```

**This grants full access to the storage account. To restrict to specific paths, use Azure RBAC conditions** (currently in preview):

```bash
az role assignment create \
  --role "Storage Blob Data Contributor" \
  --assignee <pod-a-identity> \
  --scope /subscriptions/.../storageAccounts/stdldevshared123abc \
  --condition "
    (
      (containers equals 'bronze' and path starts with 'podA/')
      or
      (containers equals 'silver' and path starts with 'podA/')
      or
      (containers equals 'gold' and path starts with 'podA/')
    )
  "
```

### ADLS Gen2 ACL Strategy

Set directory-level ACLs for granular control:

```bash
# Grant Pod A's service principal rwx on bronze/podA/ and all subdirectories
az storage fs access set \
  --account-name stdldevshared123abc \
  --file-system bronze \
  --path podA \
  --permissions "user:<pod-a-sp-object-id>:rwx" \
  --acl "default:user:<pod-a-sp-object-id>:rwx"
```

The `default:` ACL ensures new files/folders inherit the same permissions.

### Testing Isolation

Verify Pod A cannot access Pod B's data:

```python
# In Pod A's Databricks notebook
# This should work (Pod A accessing its own data)
df = spark.read.parquet("abfss://bronze@stdldevshared123abc.dfs.core.windows.net/podA/hr/employees.parquet")

# This should fail with access denied (Pod A trying to access Pod B's data)
df = spark.read.parquet("abfss://bronze@stdldevshared123abc.dfs.core.windows.net/podB/hr/employees.parquet")
```

## Data Flow Through Medallion Layers - Department-Level Example

### Example: Pod A Finance Department HR Data Pipeline

**Step 1: Ingestion to Bronze (ADF Copy Activity)**
```python
# ADF copies raw CSV from source blob storage to bronze
source_path = "abfss://hr-landing@stblobdevshared123abc.blob.core.windows.net/podA/finance/employees_2025-01-15.csv"
bronze_path = "abfss://bronze@stdldevshared123abc.dfs.core.windows.net/podA/finance/hr/employees_2025-01-15.csv"

# Data Factory Copy Activity
# Triggered by file upload event in hr-landing/podA/finance/
# Copies file as-is with no transformation
```

**Step 2: Bronze to Silver Transformation (Databricks Job Cluster)**
```python
# Finance Department Job Cluster runs this notebook
# Parameters: pod_id="podA", department="finance", domain="hr"

bronze_df = spark.read.csv(
    "abfss://bronze@stdldevshared123abc.dfs.core.windows.net/podA/finance/hr/employees_2025-01-15.csv",
    header=True,
    inferSchema=True
)

# Apply data quality rules
cleaned_df = bronze_df \
    .dropDuplicates(["employee_id"]) \
    .na.drop(subset=["employee_id", "email"]) \
    .withColumn("hire_date", col("hire_date").cast("date")) \
    .withColumn("department", lit("finance"))  # Tag with department

# Write to silver as Delta Lake table
cleaned_df.write.format("delta").mode("overwrite") \
    .save("abfss://silver@stdldevshared123abc.dfs.core.windows.net/podA/finance/hr/employees")

# Job cluster destroyed after completion
```

**Step 3: Silver to Gold Aggregation (Databricks Job Cluster)**
```python
# Finance Department Job Cluster runs aggregation
# Read from silver Delta table
silver_df = spark.read.format("delta") \
    .load("abfss://silver@stdldevshared123abc.dfs.core.windows.net/podA/finance/hr/employees")

# Create business-level aggregation for Finance department
headcount_metrics = silver_df.groupBy("location") \
    .agg(
        count("employee_id").alias("headcount"),
        avg("salary").alias("avg_salary"),
        sum("salary").alias("total_payroll")
    ) \
    .withColumn("department", lit("finance")) \
    .withColumn("pod", lit("podA")) \
    .withColumn("report_date", current_date())

# Write to gold analytics folder
headcount_metrics.write.format("delta").mode("append") \
    .save("abfss://gold@stdldevshared123abc.dfs.core.windows.net/podA/finance/analytics/headcount_metrics")

# Job cluster destroyed after completion
```

**Step 4: BI Tool Consumption (Power BI Direct Query)**
```sql
-- Power BI connects to gold layer analytics tables
SELECT
    pod,
    department,
    location,
    headcount,
    avg_salary,
    total_payroll,
    report_date
FROM delta.`abfss://gold@stdldevshared123abc.dfs.core.windows.net/podA/finance/analytics/headcount_metrics`
WHERE report_date >= CURRENT_DATE - INTERVAL 30 DAYS
ORDER BY report_date DESC, location;
```

**Parallel Processing**: While Finance processes HR data, Operations department simultaneously processes its own HR data:
```python
# Operations Department Job Cluster (runs in parallel)
"abfss://bronze@stdldevshared123abc.dfs.core.windows.net/podA/operations/hr/employees_2025-01-15.csv"
→ "abfss://silver@stdldevshared123abc.dfs.core.windows.net/podA/operations/hr/employees"
→ "abfss://gold@stdldevshared123abc.dfs.core.windows.net/podA/operations/analytics/headcount_metrics"
```

## Cost Comparison: Old vs. New Architecture

### Old Architecture (Per-Pod) Monthly Costs

**Storage Accounts**: 3 × $23 (with data) = $69
**Storage Transactions**: 3 × $2 = $6
**Total**: ~$75/month for development environment

### New Architecture (Shared) Monthly Costs

**Storage Account**: 1 × $25 = $25
**Storage Transactions**: 1 × $2.50 = $2.50
**Total**: ~$27.50/month for development environment

**Savings**: ~$47.50/month (63% reduction)

For production with higher data volumes:
- Old: ~$300/month (3 accounts with 1TB each)
- New: ~$120/month (1 account with 3TB total)
- **Savings: ~$180/month (60% reduction)**

### Cost Optimization Strategies

**Lifecycle Management**: Move old bronze data to cool storage after 90 days

**Compaction**: Optimize Delta Lake tables to reduce small file overhead

**Partitioning**: Partition large tables by date to enable partition pruning

**Z-Ordering**: Optimize data layout for common query patterns

## Deployment Commands Summary

### Step 1: Verify Module Files Created

```bash
ls -la "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\data-lake\"
```

**Expected Output**:
```
-rw-r--r-- 1 User 197121 15234 Oct  4 18:45 main.tf
-rw-r--r-- 1 User 197121   812 Oct  4 18:44 variables.tf
-rw-r--r-- 1 User 197121  1243 Oct  4 18:46 outputs.tf
```

### Step 2: Format and Validate Module

```bash
cd "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\data-lake"

# Format code to ensure proper HCL syntax
terraform fmt

# Validate configuration
terraform validate
```

**Expected Output**:
```
Success! The configuration is valid.
```

### Step 3: Update Dev Environment

Edit `terraform/environments/dev/main.tf` to instantiate the new shared module:

```hcl
# Shared Data Lake Gen2 Module - Single ADLS Gen2 account with medallion architecture
module "data_lake_shared" {
  source = "../../modules/data-lake"

  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  pod_ids             = var.pods
  domains             = ["hr", "payroll", "finance"]
  tags                = var.tags
}
```

**Key Difference**: No `for_each` loop because this module creates only ONE storage account shared by all pods.

### Step 4: Deploy the Shared Module

```bash
cd "C:\Users\User\Desktop\Delta_lake_project\terraform\environments\dev"

# Initialize Terraform with new module
terraform init

# Preview deployment
terraform plan

# Deploy resources
terraform apply -auto-approve
```

**Expected Resources to be Created**:
- 1 random string
- 1 ADLS Gen2 storage account
- 3 filesystems (bronze, silver, gold)
- 36 directories (9 pod folders + 27 domain folders)
- **Total: 41 resources**

### Step 5: Verify Folder Structure Created

```bash
# List filesystems (containers)
az storage fs list \
  --account-name stdldevshared123abc \
  --auth-mode login \
  --output table
```

**Expected Output**:
```
Name    LastModified
------  -------------------------
bronze  2025-10-04T20:15:32+00:00
silver  2025-10-04T20:15:33+00:00
gold    2025-10-04T20:15:34+00:00
```

```bash
# List directories in bronze filesystem
az storage fs directory list \
  --account-name stdldevshared123abc \
  --file-system bronze \
  --auth-mode login \
  --output table
```

**Expected Output**:
```
Name    IsDirectory
------  -------------
podA    True
podB    True
podC    True
```

```bash
# List department directories under bronze/podA
az storage fs directory list \
  --account-name stdldevshared123abc \
  --file-system bronze \
  --path podA \
  --auth-mode login \
  --output table
```

**Expected Output**:
```
Name               IsDirectory
-----------------  -------------
podA/finance       True
podA/operations    True
podA/marketing     True
podA/it            True
```

```bash
# List domain directories under bronze/podA/finance
az storage fs directory list \
  --account-name stdldevshared123abc \
  --file-system bronze \
  --path podA/finance \
  --auth-mode login \
  --output table
```

**Expected Output**:
```
Name                        IsDirectory
--------------------------  -------------
podA/finance/hr             True
podA/finance/payroll        True
podA/finance/finance        True
podA/finance/inventory      True
podA/finance/campaigns      True
podA/finance/tickets        True
podA/finance/crm            True
podA/finance/benefits       True
podA/finance/audit_logs     True
```

### Step 6: Test Data Upload

```bash
# Create test file
echo "employee_id,name,department
1,John Doe,Engineering
2,Jane Smith,Finance" > test_employees.csv

# Upload to Pod A Finance Department's bronze HR folder
az storage fs file upload \
  --account-name stdldevshared123abc \
  --file-system bronze \
  --path "podA/finance/hr/test_employees.csv" \
  --source test_employees.csv \
  --auth-mode login
```

```bash
# Verify file uploaded to Finance department folder
az storage fs file list \
  --account-name stdldevshared123abc \
  --file-system bronze \
  --path "podA/finance/hr" \
  --auth-mode login \
  --output table
```

**Expected Output**:
```
Name                                    ContentLength  IsDirectory
--------------------------------------  ---------------  -------------
podA/finance/hr/test_employees.csv      86              False
```

```bash
# Upload to Operations department (parallel processing test)
az storage fs file upload \
  --account-name stdldevshared123abc \
  --file-system bronze \
  --path "podA/operations/hr/test_employees.csv" \
  --source test_employees.csv \
  --auth-mode login

# Now both Finance and Operations departments have the same file
# They will process it independently with separate job clusters
```

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
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\data-lake\main.tf"
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\data-lake\variables.tf"
rm "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\data-lake\outputs.tf"

# ═══════════════════════════════════════════════════════════════
# MODULE CREATION AND VALIDATION
# ═══════════════════════════════════════════════════════════════

# Navigate to module directory
cd "C:\Users\User\Desktop\Delta_lake_project\terraform\modules\data-lake"

# Verify files created
ls -la

# Format code
terraform fmt

# Validate syntax
terraform validate

# ═══════════════════════════════════════════════════════════════
# DEPLOYMENT COMMANDS
# ═══════════════════════════════════════════════════════════════

# Navigate to dev environment
cd "C:\Users\User\Desktop\Delta_lake_project\terraform\environments\dev"

# Initialize with new module
terraform init

# Preview changes
terraform plan

# Deploy resources
terraform apply -auto-approve

# ═══════════════════════════════════════════════════════════════
# VERIFICATION COMMANDS
# ═══════════════════════════════════════════════════════════════

# List storage accounts (should see 1 shared account)
az storage account list \
  --resource-group rg-delta-lake-dev \
  --query "[?starts_with(name, 'stdl')].{Name:name, SKU:sku.name, HNS:isHnsEnabled}" \
  --output table

# Show storage account details
az storage account show \
  --name stdldevshared123abc \
  --resource-group rg-delta-lake-dev \
  --query "{Name:name, HNS:isHnsEnabled, DFSEndpoint:primaryEndpoints.dfs}" \
  --output table

# List filesystems (bronze, silver, gold)
az storage fs list \
  --account-name stdldevshared123abc \
  --auth-mode login \
  --output table

# List pod directories in bronze
az storage fs directory list \
  --account-name stdldevshared123abc \
  --file-system bronze \
  --auth-mode login \
  --output table

# List domain directories under podA in bronze
az storage fs directory list \
  --account-name stdldevshared123abc \
  --file-system bronze \
  --path podA \
  --auth-mode login \
  --output table

# ═══════════════════════════════════════════════════════════════
# TESTING COMMANDS
# ═══════════════════════════════════════════════════════════════

# Create test CSV file
echo "employee_id,name,department
1,John Doe,Engineering
2,Jane Smith,Finance
3,Bob Johnson,HR" > test_employees.csv

# Upload to Pod A bronze HR
az storage fs file upload \
  --account-name stdldevshared123abc \
  --file-system bronze \
  --path "podA/hr/test_employees.csv" \
  --source test_employees.csv \
  --auth-mode login

# Upload to Pod B bronze payroll
echo "employee_id,hours,rate
1,160,50
2,160,65" > test_payroll.csv

az storage fs file upload \
  --account-name stdldevshared123abc \
  --file-system bronze \
  --path "podB/payroll/test_payroll.csv" \
  --source test_payroll.csv \
  --auth-mode login

# List all files in Pod A bronze HR
az storage fs file list \
  --account-name stdldevshared123abc \
  --file-system bronze \
  --path "podA/hr" \
  --auth-mode login \
  --output table

# Download a file for verification
az storage fs file download \
  --account-name stdldevshared123abc \
  --file-system bronze \
  --path "podA/hr/test_employees.csv" \
  --file downloaded_test.csv \
  --auth-mode login

# View downloaded file content
cat downloaded_test.csv

# Delete test file
az storage fs file delete \
  --account-name stdldevshared123abc \
  --file-system bronze \
  --path "podA/hr/test_employees.csv" \
  --auth-mode login \
  --yes

# ═══════════════════════════════════════════════════════════════
# TROUBLESHOOTING COMMANDS
# ═══════════════════════════════════════════════════════════════

# Check if HNS is enabled
az storage account show \
  --name stdldevshared123abc \
  --resource-group rg-delta-lake-dev \
  --query "isHnsEnabled" \
  --output tsv

# Get DFS endpoint
az storage account show \
  --name stdldevshared123abc \
  --resource-group rg-delta-lake-dev \
  --query "primaryEndpoints.dfs" \
  --output tsv

# Check directory permissions
az storage fs access show \
  --account-name stdldevshared123abc \
  --file-system bronze \
  --path podA/hr \
  --auth-mode login
```

## Files Modified/Created in This Step

```
terraform/modules/data-lake/
├── variables.tf   - REPLACED: Removed pod_id, added pod_ids and domains lists
├── main.tf        - REPLACED: Single shared ADLS Gen2, 36 directories, medallion filesystems
└── outputs.tf     - REPLACED: Updated to reference datalake_shared, added pod_folder_structure

terraform/environments/dev/
└── main.tf        - TO BE UPDATED: Change from for_each loop to single module instantiation
```

## Key Takeaways

- **Shared ADLS Gen2 reduces costs by 60-66%** compared to per-pod isolated storage accounts
- **Department-level granularity**: ~671 directories created (pod → department → domain hierarchy)
- **Dynamic Terraform loops**: Using `for_each` and `flatten` to create all department/domain combinations
- **Each pod has unique departments**: podA has 4 departments, podB has 3, podC has 3
- **9 business domains per department**: hr, payroll, finance, inventory, campaigns, tickets, crm, benefits, audit_logs
- **Parallel department processing**: Finance and Operations departments process data simultaneously with separate job clusters
- **Cost attribution**: Each department's compute and storage costs tracked independently
- **Scalability**: Add new department = update `departments` variable, run `terraform apply` (no code changes)
- **is_hns_enabled = true is mandatory** for ADLS Gen2 hierarchical namespace (cannot be changed after creation)
- **RBAC and ACLs enforce department isolation** - Finance dept cannot access Operations dept folders
- **DFS endpoint (.dfs. not .blob.)** is critical for Databricks and Spark access to ADLS Gen2
- **Medallion architecture** organizes data by refinement level: Bronze (raw) → Silver (cleansed) → Gold (business-ready)
- **Gold layer has shared folders**: `gold/config/` and `gold/pipeline_metrics/` for cross-department configuration and observability
- **Job clusters are ephemeral**: Created per department, destroyed after extraction (85-96% cost savings vs always-on clusters)
- **Department-level paths enable multi-tenancy**: `bronze/podA/finance/hr/` vs `bronze/podA/operations/hr/`
- **Cross-pod analytics** becomes easier when all data resides in the same storage account
