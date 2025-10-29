# ============================================================================
# Storage Containers for Hash Validation Pipeline
# ============================================================================
# This creates the test container where data files arrive
# and the archive container for storing processed files

# Reference to existing storage account (assuming it already exists)
# If you need to create a new storage account, uncomment the resource below

# Uncomment if you need to create the storage account
# resource "azurerm_storage_account" "hash_validation" {
#   name                     = "stdldevshared77b5h3"  # Replace with your name
#   resource_group_name      = var.resource_group_name
#   location                 = var.location
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
#   account_kind             = "StorageV2"
#   is_hns_enabled           = true  # Enable hierarchical namespace for ADLS Gen2
#
#   tags = {
#     environment = "dev"
#     project     = "hash-validation"
#     purpose     = "hr-payroll-data-processing"
#   }
# }

# Data source to reference existing storage account
data "azurerm_storage_account" "existing" {
  name                = var.storage_account_name
  resource_group_name = var.resource_group_name
}

# ============================================================================
# TEST Container - Landing Zone
# ============================================================================
# This is where ZIP files and hash files arrive for validation

resource "azurerm_storage_container" "test" {
  name                  = "test"
  storage_account_name  = data.azurerm_storage_account.existing.name
  container_access_type = "private"

  # No public access - files are sensitive
  # Only Azure services and authorized users can access
}

# ============================================================================
# Archive Container - For Processed Files
# ============================================================================
# After validation and processing, files are moved here for retention

resource "azurerm_storage_container" "archive" {
  name                  = "archive"
  storage_account_name  = data.azurerm_storage_account.existing.name
  container_access_type = "private"
}

# ============================================================================
# Validation Temp Container - For Azure Function Processing
# ============================================================================
# Azure Function downloads files here temporarily during validation

resource "azurerm_storage_container" "validation_temp" {
  name                  = "validation-temp"
  storage_account_name  = data.azurerm_storage_account.existing.name
  container_access_type = "private"

  # This container can have lifecycle management to auto-delete old files
}

# ============================================================================
# Outputs - Use these values in other modules
# ============================================================================

output "test_container_name" {
  description = "Name of the test container where files arrive"
  value       = azurerm_storage_container.test.name
}

output "archive_container_name" {
  description = "Name of the archive container"
  value       = azurerm_storage_container.archive.name
}

output "validation_temp_container_name" {
  description = "Name of the temporary validation container"
  value       = azurerm_storage_container.validation_temp.name
}

output "storage_account_name" {
  description = "Storage account name"
  value       = data.azurerm_storage_account.existing.name
}

output "storage_account_primary_key" {
  description = "Primary access key for storage account"
  value       = data.azurerm_storage_account.existing.primary_access_key
  sensitive   = true
}
