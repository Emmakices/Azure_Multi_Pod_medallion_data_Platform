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
