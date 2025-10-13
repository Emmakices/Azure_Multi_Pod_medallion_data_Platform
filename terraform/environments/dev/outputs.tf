# ═══════════════════════════════════════════════════════════════════════════════
# OUTPUTS - SHARED INFRASTRUCTURE MODEL
# ═══════════════════════════════════════════════════════════════════════════════
# Terraform outputs for accessing shared platform resources
# Use these outputs to configure pipelines, notebooks, and applications
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# RESOURCE GROUP
# ═══════════════════════════════════════════════════════════════════════════════

output "resource_group" {
  description = "Platform resource group name"
  value       = azurerm_resource_group.platform.name
}

output "resource_group_location" {
  description = "Platform resource group location"
  value       = azurerm_resource_group.platform.location
}

# ═══════════════════════════════════════════════════════════════════════════════
# LOG ANALYTICS (Central Monitoring)
# ═══════════════════════════════════════════════════════════════════════════════

output "log_analytics" {
  description = "Central Log Analytics workspace for monitoring all pods"
  value = {
    workspace_id   = module.log_analytics.workspace_id
    workspace_name = module.log_analytics.workspace_name
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# SOURCE BLOB STORAGE (Landing Zone)
# ═══════════════════════════════════════════════════════════════════════════════

output "source_blob_storage" {
  description = "Shared source blob storage with pod-first organization. Each pod processes data for multiple companies (landing/podA/finance/, landing/podA/operations/)"
  value = {
    storage_name    = module.source_blob_storage.storage_account_name
    storage_id      = module.source_blob_storage.storage_account_id
    blob_endpoint   = module.source_blob_storage.primary_blob_endpoint
    eventgrid_topic = module.source_blob_storage.eventgrid_topic_name

    # Container name (pod-first structure)
    landing_container = module.source_blob_storage.landing_container_name

    # Company paths for file uploads (each pod processes multiple companies)
    company_paths = module.source_blob_storage.company_paths
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# DATA LAKE (Medallion Architecture)
# ═══════════════════════════════════════════════════════════════════════════════

output "data_lake" {
  description = "Shared Data Lake Gen2 with medallion architecture (bronze/silver/gold) and pod isolation"
  value = {
    storage_name = module.data_lake.storage_account_name
    storage_id   = module.data_lake.storage_account_id
    dfs_endpoint = module.data_lake.primary_dfs_endpoint

    # Medallion layer filesystems
    bronze_filesystem = module.data_lake.bronze_filesystem_name
    silver_filesystem = module.data_lake.silver_filesystem_name
    gold_filesystem   = module.data_lake.gold_filesystem_name

    # Pod folder structure (e.g., bronze/podA/hr/, silver/podB/payroll/, gold/podC/finance/)
    pod_structure = module.data_lake.pod_folder_structure
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# DATA FACTORY (Orchestration)
# ═══════════════════════════════════════════════════════════════════════════════

output "data_factory" {
  description = "Shared Data Factory for orchestration with parameterized pipelines"
  value = {
    adf_name = module.data_factory.data_factory_name
    adf_id   = module.data_factory.data_factory_id

    # Managed identity for RBAC
    managed_identity_principal_id = module.data_factory.data_factory_identity_principal_id

    # Linked service names for pipeline creation
    source_blob_linked_service = module.data_factory.source_blob_linked_service_name
    datalake_linked_service    = module.data_factory.datalake_linked_service_name
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# DATABRICKS (Transformation Engine)
# ═══════════════════════════════════════════════════════════════════════════════

output "databricks" {
  description = "Shared Databricks workspace with per-pod cluster pools"
  value = {
    workspace_id          = module.databricks.databricks_workspace_id
    workspace_name        = module.databricks.databricks_workspace_name
    workspace_url         = module.databricks.databricks_workspace_url
    workspace_resource_id = module.databricks.databricks_workspace_resource_id
    databricks_host       = module.databricks.databricks_host

    # Managed resource group (contains cluster VMs)
    managed_resource_group = module.databricks.databricks_managed_resource_group

    # Cluster pool recommendations per pod
    recommended_cluster_pools = module.databricks.recommended_cluster_pools

    # Cluster recommendations per pod
    recommended_clusters = module.databricks.recommended_clusters

    # Scalability information
    scalability_summary = module.databricks.scalability_summary

    # Cost tracking tags per pod
    cost_tracking_tags = module.databricks.cost_tracking_tags
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLUSTER CREATION INSTRUCTIONS (Databricks)
# ═══════════════════════════════════════════════════════════════════════════════

output "cluster_creation_instructions" {
  description = "Step-by-step instructions for creating Databricks clusters per pod"
  value       = module.databricks.cluster_creation_instructions
}

# ═══════════════════════════════════════════════════════════════════════════════
# DATA LAKE ACCESS VERIFICATION (Databricks)
# ═══════════════════════════════════════════════════════════════════════════════

output "data_lake_access_verification" {
  description = "Commands to verify Databricks can access Data Lake from notebooks"
  value       = module.databricks.data_lake_access_verification
}

# ═══════════════════════════════════════════════════════════════════════════════
# QUICK REFERENCE SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

output "deployment_summary" {
  description = "Quick reference summary of deployed resources"
  value = {
    environment        = var.environment
    location           = var.location
    resource_group     = azurerm_resource_group.platform.name
    pods_configured    = var.pod_ids
    domains_configured = var.domains

    # Access URLs
    databricks_url = "https://${module.databricks.databricks_workspace_url}"

    # Storage account names
    source_blob_storage = module.source_blob_storage.storage_account_name
    data_lake_storage   = module.data_lake.storage_account_name

    # Orchestration
    data_factory_name = module.data_factory.data_factory_name

    # Monitoring
    log_analytics_workspace = module.log_analytics.workspace_name

    # Architecture notes
    architecture_type = "Shared Infrastructure with Folder-Based Pod Isolation"
    cost_optimization = "60-70% reduction vs. per-pod isolated resources"
    scalability_model = "Add pods by updating pod_ids variable - folders auto-create"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# USAGE EXAMPLES:
# ═══════════════════════════════════════════════════════════════════════════════
# 1. View all outputs:          terraform output
# 2. View specific output:       terraform output databricks
# 3. View in JSON format:        terraform output -json > outputs.json
# 4. Get Databricks URL:         terraform output -raw databricks.workspace_url
# 5. Get cluster instructions:   terraform output -raw cluster_creation_instructions
# 6. Get deployment summary:     terraform output deployment_summary
# ═══════════════════════════════════════════════════════════════════════════════
