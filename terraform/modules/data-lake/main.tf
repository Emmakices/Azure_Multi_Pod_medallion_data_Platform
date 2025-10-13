# Shared Data Lake Gen2 Module with Medallion Architecture
# Provides a SINGLE ADLS Gen2 storage account shared across all pods
# Department-level isolation: {layer}/{pod}/{department}/{domain}/

# Generate random suffix for globally unique storage account name
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Shared Data Lake Gen2 storage account for all pods
# Medallion architecture: Bronze (raw) → Silver (cleansed) → Gold (business-ready)
# Folder structure: {layer}/{pod}/{department}/{domain}/ for complete isolation
resource "azurerm_storage_account" "datalake_shared" {
  name                            = "stdl${var.environment}shared${random_string.suffix.result}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  is_hns_enabled                  = true # CRITICAL: Enables ADLS Gen2 hierarchical namespace
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  public_network_access_enabled   = true

  tags = var.tags
}

# ═══════════════════════════════════════════════════════════════
# MEDALLION LAYER CONTAINERS
# ═══════════════════════════════════════════════════════════════
# Three containers represent the three layers of data transformation

# Bronze Layer - Raw data ingestion zone
# Data arrives in original format from source blob storage
# Minimal transformation, schema-on-read approach
resource "azurerm_storage_data_lake_gen2_filesystem" "bronze" {
  name               = "bronze"
  storage_account_id = azurerm_storage_account.datalake_shared.id
}

# Silver Layer - Cleansed and validated data
# Data quality rules applied, schema enforced
# Conformed to standard formats, ready for analytics
resource "azurerm_storage_data_lake_gen2_filesystem" "silver" {
  name               = "silver"
  storage_account_id = azurerm_storage_account.datalake_shared.id
}

# Gold Layer - Business-ready aggregated data
# Optimized for consumption by BI tools and applications
# Aggregations, joins, and business logic applied
resource "azurerm_storage_data_lake_gen2_filesystem" "gold" {
  name               = "gold"
  storage_account_id = azurerm_storage_account.datalake_shared.id
}

# ═══════════════════════════════════════════════════════════════
# DEPARTMENT FOLDER STRUCTURE - ALL LAYERS
# ═══════════════════════════════════════════════════════════════
# Create department-level folders dynamically using for_each

locals {
  # Flatten department structure for iteration
  # Creates list of {pod, department} combinations
  company_folders = flatten([
    for pod, config in var.companies : [
      for company in config.companies : {
        pod        = pod
        department = company
        key        = "${pod}-${company}"
      }
    ]
  ])

  # Convert list to map for for_each
  company_map = { for item in local.company_folders : item.key => item }
}

# ═══════════════════════════════════════════════════════════════
# BRONZE LAYER - POD FOLDERS
# ═══════════════════════════════════════════════════════════════

resource "azurerm_storage_data_lake_gen2_path" "bronze_pod" {
  for_each = toset(var.pod_ids)

  path               = each.value
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.bronze.name
  storage_account_id = azurerm_storage_account.datalake_shared.id
  resource           = "directory"
}

# ═══════════════════════════════════════════════════════════════
# BRONZE LAYER - DEPARTMENT FOLDERS
# ═══════════════════════════════════════════════════════════════
# Creates: bronze/podA/finance/, bronze/podA/operations/, etc.

resource "azurerm_storage_data_lake_gen2_path" "bronze_company" {
  for_each = local.company_map

  path               = "${each.value.pod}/${each.value.department}"
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.bronze.name
  storage_account_id = azurerm_storage_account.datalake_shared.id
  resource           = "directory"

  depends_on = [azurerm_storage_data_lake_gen2_path.bronze_pod]
}

# ═══════════════════════════════════════════════════════════════
# BRONZE LAYER - DOMAIN FOLDERS (under departments)
# ═══════════════════════════════════════════════════════════════
# Creates: bronze/podA/finance/hr/, bronze/podA/finance/payroll/, etc.

locals {
  # Create all combinations of pod/department/domain
  bronze_domain_folders = flatten([
    for pod, config in var.companies : [
      for company in config.companies : [
        for domain in var.domains : {
          pod        = pod
          department = company
          domain     = domain
          key        = "${pod}-${company}-${domain}"
          path       = "${pod}/${company}/${domain}"
        }
      ]
    ]
  ])

  bronze_domain_map = { for item in local.bronze_domain_folders : item.key => item }
}

resource "azurerm_storage_data_lake_gen2_path" "bronze_domain" {
  for_each = local.bronze_domain_map

  path               = each.value.path
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.bronze.name
  storage_account_id = azurerm_storage_account.datalake_shared.id
  resource           = "directory"

  depends_on = [azurerm_storage_data_lake_gen2_path.bronze_company]
}

# ═══════════════════════════════════════════════════════════════
# SILVER LAYER - POD FOLDERS
# ═══════════════════════════════════════════════════════════════

resource "azurerm_storage_data_lake_gen2_path" "silver_pod" {
  for_each = toset(var.pod_ids)

  path               = each.value
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.silver.name
  storage_account_id = azurerm_storage_account.datalake_shared.id
  resource           = "directory"
}

# ═══════════════════════════════════════════════════════════════
# SILVER LAYER - DEPARTMENT FOLDERS
# ═══════════════════════════════════════════════════════════════

resource "azurerm_storage_data_lake_gen2_path" "silver_company" {
  for_each = local.company_map

  path               = "${each.value.pod}/${each.value.department}"
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.silver.name
  storage_account_id = azurerm_storage_account.datalake_shared.id
  resource           = "directory"

  depends_on = [azurerm_storage_data_lake_gen2_path.silver_pod]
}

# ═══════════════════════════════════════════════════════════════
# SILVER LAYER - DOMAIN FOLDERS (under departments)
# ═══════════════════════════════════════════════════════════════

locals {
  silver_domain_folders = flatten([
    for pod, config in var.companies : [
      for company in config.companies : [
        for domain in var.domains : {
          pod        = pod
          department = company
          domain     = domain
          key        = "${pod}-${company}-${domain}"
          path       = "${pod}/${company}/${domain}"
        }
      ]
    ]
  ])

  silver_domain_map = { for item in local.silver_domain_folders : item.key => item }
}

resource "azurerm_storage_data_lake_gen2_path" "silver_domain" {
  for_each = local.silver_domain_map

  path               = each.value.path
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.silver.name
  storage_account_id = azurerm_storage_account.datalake_shared.id
  resource           = "directory"

  depends_on = [azurerm_storage_data_lake_gen2_path.silver_company]
}

# ═══════════════════════════════════════════════════════════════
# GOLD LAYER - POD FOLDERS
# ═══════════════════════════════════════════════════════════════

resource "azurerm_storage_data_lake_gen2_path" "gold_pod" {
  for_each = toset(var.pod_ids)

  path               = each.value
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.gold.name
  storage_account_id = azurerm_storage_account.datalake_shared.id
  resource           = "directory"
}

# ═══════════════════════════════════════════════════════════════
# GOLD LAYER - DEPARTMENT FOLDERS
# ═══════════════════════════════════════════════════════════════

resource "azurerm_storage_data_lake_gen2_path" "gold_company" {
  for_each = local.company_map

  path               = "${each.value.pod}/${each.value.department}"
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.gold.name
  storage_account_id = azurerm_storage_account.datalake_shared.id
  resource           = "directory"

  depends_on = [azurerm_storage_data_lake_gen2_path.gold_pod]
}

# ═══════════════════════════════════════════════════════════════
# GOLD LAYER - ANALYTICS FOLDERS (under departments)
# ═══════════════════════════════════════════════════════════════
# Gold layer has analytics aggregations, not raw domains

resource "azurerm_storage_data_lake_gen2_path" "gold_analytics" {
  for_each = local.company_map

  path               = "${each.value.pod}/${each.value.department}/analytics"
  filesystem_name    = azurerm_storage_data_lake_gen2_filesystem.gold.name
  storage_account_id = azurerm_storage_account.datalake_shared.id
  resource           = "directory"

  depends_on = [azurerm_storage_data_lake_gen2_path.gold_company]
}

# ═══════════════════════════════════════════════════════════════
# GOLD LAYER - SHARED FOLDERS (config, pipeline_metrics)
# ═══════════════════════════════════════════════════════════════
# These are shared across all pods for configuration and observability

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
