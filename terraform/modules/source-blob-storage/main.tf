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

# Container: Landing Zone
# Single container with pod-first organization
# Folder structure: landing/podA/finance/, landing/podA/operations/, etc.
resource "azurerm_storage_container" "landing" {
  name                  = "landing"
  storage_account_name  = azurerm_storage_account.source_shared.name
  container_access_type = "private"
}

# ═══════════════════════════════════════════════════════════════
# COMPANY FOLDER MARKERS - POD-FIRST STRUCTURE
# ═══════════════════════════════════════════════════════════════
# Azure Blob Storage doesn't have true folders, so we create placeholder blobs
# Each pod processes data for multiple companies (Finance company, Operations company, etc.)
# Structure: landing/podA/finance/, landing/podA/operations/, etc.

locals {
  # Flatten company structure for iteration
  company_folders = flatten([
    for pod, config in var.companies : [
      for company in config.companies : {
        pod     = pod
        company = company
        path    = "${pod}/${company}/.folder"
      }
    ]
  ])
}

resource "azurerm_storage_blob" "company_folders" {
  for_each = { for item in local.company_folders : "${item.pod}-${item.company}" => item }

  name                   = each.value.path
  storage_account_name   = azurerm_storage_account.source_shared.name
  storage_container_name = azurerm_storage_container.landing.name
  type                   = "Block"
  source_content         = "folder"
}

# Event Grid system topic for blob storage events
# Monitors ALL blob creation events across the entire storage account
# ADF pipelines will filter events by folder path (e.g., landing/podA/finance/*)
resource "azurerm_eventgrid_system_topic" "blob_events" {
  name                   = "egt-${var.environment}-shared-blob"
  resource_group_name    = var.resource_group_name
  location               = var.location
  source_arm_resource_id = azurerm_storage_account.source_shared.id
  topic_type             = "Microsoft.Storage.StorageAccounts"

  tags = var.tags
}

# Lifecycle management policy
# Automatically deletes files after 30 days to control storage costs
# Applies to landing container
resource "azurerm_storage_management_policy" "lifecycle" {
  storage_account_id = azurerm_storage_account.source_shared.id

  rule {
    name    = "delete-old-files"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 30
      }
    }
  }
}
