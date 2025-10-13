# Shared Data Factory Module
# Provides a SINGLE Azure Data Factory instance shared across all pods
# Pod isolation achieved through parameterized pipelines (pod_id parameter)
# Pipelines dynamically route data based on pod_id to appropriate storage folders

# Shared Azure Data Factory for all pods
# Orchestrates data movement and transformation across medallion layers
# Uses managed identity for secure, credential-free authentication to storage accounts
resource "azurerm_data_factory" "platform" {
  name                            = "adf-${var.environment}-platform"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  managed_virtual_network_enabled = true
  public_network_enabled          = true  # Enabled for POC; restrict in production

  # System-assigned managed identity for authentication to storage accounts
  # This identity will be granted Storage Blob Data Contributor role on source and data lake storage
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# ═══════════════════════════════════════════════════════════════
# RBAC ROLE ASSIGNMENTS
# ═══════════════════════════════════════════════════════════════
# Grant ADF's managed identity permissions to read/write storage accounts

# Role Assignment: ADF to Source Blob Storage
# Grants read access to source blob storage for file ingestion
# Applies to all pod folders (hr-landing/podA/, hr-landing/podB/, etc.)
resource "azurerm_role_assignment" "adf_to_source_blob" {
  scope                = var.source_blob_storage_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.platform.identity[0].principal_id

  depends_on = [azurerm_data_factory.platform]
}

# Role Assignment: ADF to Data Lake Gen2
# Grants read/write access to data lake for all medallion layers
# Applies to all pod folders (bronze/podA/, silver/podA/, gold/podA/, etc.)
resource "azurerm_role_assignment" "adf_to_datalake" {
  scope                = var.data_lake_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_data_factory.platform.identity[0].principal_id

  depends_on = [azurerm_data_factory.platform]
}

# ═══════════════════════════════════════════════════════════════
# DIAGNOSTIC SETTINGS
# ═══════════════════════════════════════════════════════════════
# Send all ADF logs to central Log Analytics for monitoring and troubleshooting
# Logs include pod_id in customDimensions for filtering by pod

resource "azurerm_monitor_diagnostic_setting" "adf_diagnostics" {
  name                       = "adf-${var.environment}-diagnostics"
  target_resource_id         = azurerm_data_factory.platform.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  # Activity Runs: Individual activity executions within pipelines
  # Use to track which pod's data is being processed
  enabled_log {
    category = "ActivityRuns"
  }

  # Pipeline Runs: Overall pipeline execution tracking
  # Filter by pod_id parameter to monitor specific pod workloads
  enabled_log {
    category = "PipelineRuns"
  }

  # Trigger Runs: Event-based trigger executions
  # Track which pod folders triggered ingestion pipelines
  enabled_log {
    category = "TriggerRuns"
  }

  # All performance and health metrics
  metric {
    category = "AllMetrics"
    enabled  = true
  }

  depends_on = [azurerm_data_factory.platform]
}

# ═══════════════════════════════════════════════════════════════
# LINKED SERVICES
# ═══════════════════════════════════════════════════════════════
# Connections to external storage accounts using managed identity authentication

# Linked Service: Source Blob Storage
# Connects to shared source blob storage where external systems drop files
# ADF reads from pod-specific folders (hr-landing/podA/, payroll-landing/podB/, etc.)
resource "azurerm_data_factory_linked_service_azure_blob_storage" "source_blob" {
  name              = "LS_SourceBlobStorage"
  data_factory_id   = azurerm_data_factory.platform.id
  use_managed_identity = true

  # Connection string without account key (managed identity provides authentication)
  connection_string = "DefaultEndpointsProtocol=https;AccountName=${var.source_blob_storage_name};EndpointSuffix=core.windows.net"

  depends_on = [
    azurerm_data_factory.platform,
    azurerm_role_assignment.adf_to_source_blob
  ]
}

# Linked Service: Data Lake Gen2
# Connects to shared ADLS Gen2 data lake with medallion architecture
# ADF writes to pod-specific folders (bronze/podA/hr/, silver/podB/payroll/, etc.)
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
