# ═══════════════════════════════════════════════════════════════════════════════
# MAIN TERRAFORM CONFIGURATION - SHARED INFRASTRUCTURE MODEL
# ═══════════════════════════════════════════════════════════════════════════════
# Architecture: Single shared resources with folder-based pod isolation
# Cost Optimization: 60-70% reduction vs. per-pod isolated resources
# Scalability: Add new pods by updating pod_ids list - infrastructure auto-scales
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 1: TERRAFORM AND PROVIDER CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

# Get current Azure context for subscription and tenant information
data "azurerm_client_config" "current" {}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 2: RESOURCE GROUP
# ═══════════════════════════════════════════════════════════════════════════════
# Single resource group for all shared platform resources
# Simplifies management, RBAC, and cost tracking

resource "azurerm_resource_group" "platform" {
  name     = "rg-platform-${var.environment}"
  location = var.location
  tags     = var.common_tags
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 3: LOG ANALYTICS (Central Monitoring)
# ═══════════════════════════════════════════════════════════════════════════════
# Central Log Analytics workspace for monitoring all pods
# All services send diagnostic logs here with pod_id tags for filtering

module "log_analytics" {
  source = "../../modules/log-analytics"

  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  environment         = var.environment
  project_name        = "platform"
  tags                = var.common_tags
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 4: SOURCE BLOB STORAGE (Landing Zone)
# ═══════════════════════════════════════════════════════════════════════════════
# Shared source blob storage with folder-based pod isolation
# Structure: hr-landing/podA/, payroll-landing/podB/, finance-landing/podC/
# Event Grid triggers ADF pipelines when files land in pod folders

module "source_blob_storage" {
  source = "../../modules/source-blob-storage"

  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  environment         = var.environment
  pod_ids             = var.pod_ids
  companies           = var.companies
  tags                = var.common_tags
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 5: DATA LAKE (Medallion Architecture)
# ═══════════════════════════════════════════════════════════════════════════════
# Shared Data Lake Gen2 with Bronze/Silver/Gold layers and pod folders
# Structure: bronze/podA/hr/, silver/podB/payroll/, gold/podC/finance/
# ADLS Gen2 with hierarchical namespace for performance and POSIX compliance

module "data_lake" {
  source = "../../modules/data-lake"

  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  environment         = var.environment
  pod_ids             = var.pod_ids
  companies           = var.companies
  domains             = var.domains
  tags                = var.common_tags
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 6: DATA FACTORY (Orchestration)
# ═══════════════════════════════════════════════════════════════════════════════
# Shared Data Factory with parameterized pipelines for all pods
# Managed identity authentication eliminates credential storage
# Pipeline parameter: pod_id dynamically routes data to correct folders

module "data_factory" {
  source = "../../modules/data-factory"

  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  environment         = var.environment

  # Storage account references for linked services
  source_blob_storage_id   = module.source_blob_storage.storage_account_id
  source_blob_storage_name = module.source_blob_storage.storage_account_name
  data_lake_id             = module.data_lake.storage_account_id
  data_lake_endpoint       = module.data_lake.primary_dfs_endpoint

  # Monitoring
  log_analytics_workspace_id = module.log_analytics.workspace_id

  tags = var.common_tags

  # Explicit dependency ensures storage accounts exist before ADF tries to access them
  depends_on = [
    module.source_blob_storage,
    module.data_lake,
    module.log_analytics
  ]
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 7: DATABRICKS (Transformation Engine)
# ═══════════════════════════════════════════════════════════════════════════════
# Shared Databricks workspace with per-pod cluster pools
# Workspace hosts all pods, cluster pools provide resource isolation
# Each pod gets dedicated cluster pool (podA-pool, podB-pool, podC-pool)

module "databricks" {
  source = "../../modules/databricks"

  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  environment         = var.environment
  pod_ids             = var.pod_ids

  # Data Lake access via managed identity RBAC
  data_lake_id = module.data_lake.storage_account_id

  # Monitoring
  log_analytics_workspace_id = module.log_analytics.workspace_id

  tags = var.common_tags

  # Explicit dependency ensures data lake and monitoring exist first
  depends_on = [
    module.data_lake,
    module.log_analytics
  ]
}

# ═══════════════════════════════════════════════════════════════════════════════
# DEPLOYMENT NOTES:
# ═══════════════════════════════════════════════════════════════════════════════
# 1. Initialize: terraform init
# 2. Plan:       terraform plan -out=tfplan
# 3. Apply:      terraform apply tfplan
# 4. Verify:     terraform output
#
# Expected Resources Created:
# - 1 Resource Group (rg-platform-dev)
# - 1 Log Analytics Workspace
# - 1 Source Blob Storage Account (3 containers, 9 pod folders)
# - 1 Data Lake Gen2 Storage Account (3 filesystems, 36 directories)
# - 1 Data Factory (2 linked services, managed identity RBAC)
# - 1 Databricks Workspace (managed identity RBAC to data lake)
#
# TOTAL: ~8 core resources (vs. 20+ in old per-pod architecture)
# ═══════════════════════════════════════════════════════════════════════════════
