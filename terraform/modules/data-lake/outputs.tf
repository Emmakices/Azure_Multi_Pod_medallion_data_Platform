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
