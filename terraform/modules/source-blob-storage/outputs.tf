# Outputs for Shared Source Blob Storage Module
# Pod-first organization: landing/podA/finance/, landing/podB/operations/, etc.

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

output "landing_container_name" {
  description = "Landing container name (pod-first structure)"
  value       = azurerm_storage_container.landing.name
}

output "eventgrid_topic_id" {
  description = "Event Grid system topic ID for ADF triggers"
  value       = azurerm_eventgrid_system_topic.blob_events.id
}

output "eventgrid_topic_name" {
  description = "Event Grid system topic name"
  value       = azurerm_eventgrid_system_topic.blob_events.name
}

output "company_paths" {
  description = "Company folder paths for file uploads. Each pod processes data for multiple companies."
  value = {
    for pod, config in var.companies :
    pod => [for company in config.companies : "${pod}/${company}/"]
  }
}
