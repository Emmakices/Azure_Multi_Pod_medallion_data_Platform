# ============================================================================
# Azure Function for Hash Validation
# ============================================================================
# This creates a PowerShell-based Azure Function that validates hash files

# ============================================================================
# App Service Plan - Consumption Plan (Pay-per-use)
# ============================================================================

resource "azurerm_service_plan" "function_plan" {
  name                = "asp-hash-validation-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Windows"  # PowerShell functions need Windows
  sku_name            = "Y1"       # Y1 = Consumption plan (cheapest, pay-per-execution)

  tags = {
    environment = var.environment
    project     = "hash-validation"
    cost_center = "data_platform"
  }
}

# ============================================================================
# Storage Account for Function App (separate from data storage)
# ============================================================================
# Azure Functions need their own storage account for internal operations

resource "azurerm_storage_account" "function_storage" {
  name                     = "stfunc${var.environment}${random_string.suffix.result}"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  tags = {
    environment = var.environment
    project     = "hash-validation"
    purpose     = "function-app-storage"
  }
}

# Random string for unique storage account name
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ============================================================================
# Application Insights - For Function Monitoring
# ============================================================================

resource "azurerm_application_insights" "function_insights" {
  name                = "appi-hash-validation-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"

  tags = {
    environment = var.environment
    project     = "hash-validation"
  }
}

# ============================================================================
# Azure Function App (PowerShell)
# ============================================================================

resource "azurerm_windows_function_app" "hash_validator" {
  name                = "func-hash-validation-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.function_plan.id

  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key

  # Function runtime configuration
  site_config {
    application_stack {
      powershell_core_version = "7.2"  # PowerShell 7.2 runtime
    }

    # Enable Application Insights
    application_insights_key               = azurerm_application_insights.function_insights.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.function_insights.connection_string

    # Always on (not needed for consumption plan)
    # Consumption plans wake up automatically
  }

  # App settings / Environment variables
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "powershell"
    "FUNCTIONS_EXTENSION_VERSION"    = "~4"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.function_insights.instrumentation_key

    # Storage account connection for data processing
    "DATA_STORAGE_CONNECTION_STRING" = data.azurerm_storage_account.existing.primary_connection_string
    "TEST_CONTAINER_NAME"            = azurerm_storage_container.test.name
    "ARCHIVE_CONTAINER_NAME"         = azurerm_storage_container.archive.name
    "VALIDATION_TEMP_CONTAINER_NAME" = azurerm_storage_container.validation_temp.name

    # SQL Server connection (optional - for future logging)
    # "SQL_CONNECTION_STRING" = var.sql_connection_string

    # Email alert settings
    "ALERT_EMAIL_RECIPIENTS" = var.alert_email_recipients
    # "SENDGRID_API_KEY"       = var.sendgrid_api_key  # Optional: for email alerts
  }

  # Managed identity for accessing other Azure resources
  identity {
    type = "SystemAssigned"
  }

  tags = {
    environment = var.environment
    project     = "hash-validation"
    purpose     = "hash-validation-function"
  }
}

# ============================================================================
# Event Grid Trigger - Automatically trigger function when ZIP arrives
# ============================================================================
# NOTE: Commented out temporarily - will be added after function code is deployed
# Event Grid requires the function endpoint to exist before it can validate the subscription

# resource "azurerm_eventgrid_event_subscription" "blob_created" {
#   name  = "evgs-zip-file-arrival-${var.environment}"
#   scope = data.azurerm_storage_account.existing.id
#
#   # Filter for ZIP files in test container
#   subject_filter {
#     subject_begins_with = "/blobServices/default/containers/test/blobs/"
#     subject_ends_with   = ".zip"
#     case_sensitive      = false
#   }
#
#   # Only trigger on blob creation events
#   included_event_types = [
#     "Microsoft.Storage.BlobCreated"
#   ]
#
#   # Send events to Azure Function
#   azure_function_endpoint {
#     function_id = "${azurerm_windows_function_app.hash_validator.id}/functions/ValidateHash"
#
#     # Maximum events per batch
#     max_events_per_batch = 1
#
#     # Preferred batch size in KB
#     preferred_batch_size_in_kilobytes = 64
#   }
#
#   # Retry policy
#   retry_policy {
#     max_delivery_attempts = 3
#     event_time_to_live    = 1440  # 24 hours in minutes
#   }
#
#   depends_on = [
#     azurerm_windows_function_app.hash_validator
#   ]
# }

# ============================================================================
# Outputs
# ============================================================================

output "function_app_name" {
  description = "Name of the Azure Function App"
  value       = azurerm_windows_function_app.hash_validator.name
}

output "function_app_url" {
  description = "URL of the Azure Function App"
  value       = azurerm_windows_function_app.hash_validator.default_hostname
}

output "function_app_id" {
  description = "Resource ID of the Function App"
  value       = azurerm_windows_function_app.hash_validator.id
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.function_insights.instrumentation_key
  sensitive   = true
}
