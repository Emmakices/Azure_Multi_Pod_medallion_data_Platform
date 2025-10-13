# Outputs for Shared Databricks Module
# Provides workspace details and recommended cluster configurations per pod
# Use these outputs to create cluster pools and clusters in Databricks UI or via API

output "databricks_workspace_id" {
  description = "Shared Databricks workspace resource ID"
  value       = azurerm_databricks_workspace.platform.id
}

output "databricks_workspace_name" {
  description = "Shared Databricks workspace name"
  value       = azurerm_databricks_workspace.platform.name
}

output "databricks_workspace_url" {
  description = "Databricks workspace URL - use this to access the UI and create clusters"
  value       = azurerm_databricks_workspace.platform.workspace_url
}

output "databricks_workspace_resource_id" {
  description = "Databricks workspace resource ID for API calls"
  value       = azurerm_databricks_workspace.platform.workspace_id
}

output "databricks_host" {
  description = "Databricks host URL for REST API and Databricks Terraform provider configuration"
  value       = "https://${azurerm_databricks_workspace.platform.workspace_url}"
}

output "databricks_managed_resource_group" {
  description = "Managed resource group created by Databricks (contains cluster VMs and storage)"
  value       = azurerm_databricks_workspace.platform.managed_resource_group_name
}

output "recommended_cluster_pools" {
  description = "Recommended cluster pool configuration per pod - create these in Databricks UI or via Databricks Terraform provider"
  value = {
    for pod_id in var.pod_ids :
    pod_id => {
      pool_name                   = "${pod_id}-pool"
      instance_type               = var.cluster_node_type
      min_idle_instances          = 0
      max_capacity                = 10
      idle_instance_autotermination_minutes = 15
      preloaded_spark_version     = "13.3.x-scala2.12"
      preloaded_docker_image      = null
      tags = {
        pod_id      = pod_id
        environment = var.environment
        pool_type   = "general"
        managed_by  = "terraform"
      }
    }
  }
}

output "recommended_clusters" {
  description = "Recommended all-purpose cluster configuration per pod - create these in Databricks UI or via Databricks Terraform provider"
  value = {
    for pod_id in var.pod_ids :
    pod_id => {
      cluster_name                = "${pod_id}-interactive"
      cluster_pool_name           = "${pod_id}-pool"
      spark_version               = "13.3.x-scala2.12"
      node_type_id                = var.cluster_node_type
      autoscale_min_workers       = var.cluster_autoscale_min
      autoscale_max_workers       = var.cluster_autoscale_max
      autotermination_minutes     = var.cluster_autotermination_minutes
      spark_conf = {
        "spark.databricks.delta.preview.enabled" = "true"
        "spark.sql.adaptive.enabled"              = "true"
        "spark.databricks.cluster.profile"        = "singleNode"
      }
      custom_tags = {
        pod_id       = pod_id
        workload     = "interactive"
        environment  = var.environment
        cost_center  = pod_id
        managed_by   = "terraform"
      }
      data_lake_mount_paths = [
        "abfss://bronze@<storage-account>.dfs.core.windows.net/${pod_id}/",
        "abfss://silver@<storage-account>.dfs.core.windows.net/${pod_id}/",
        "abfss://gold@<storage-account>.dfs.core.windows.net/${pod_id}/"
      ]
    }
  }
}

output "cluster_creation_instructions" {
  description = "Step-by-step instructions for creating clusters per pod"
  value = <<-EOT
    CLUSTER CREATION INSTRUCTIONS:

    Option 1: Create via Databricks UI (Simplest)
    ---------------------------------------------
    1. Navigate to: ${azurerm_databricks_workspace.platform.workspace_url}
    2. Click "Compute" in left sidebar
    3. For each pod (${join(", ", var.pod_ids)}):

       a. Create Cluster Pool:
          - Click "Pools" tab → "Create Pool"
          - Name: <pod_id>-pool (e.g., podA-pool)
          - Instance Type: ${var.cluster_node_type}
          - Min Idle: 0
          - Max Capacity: 10
          - Idle Termination: 15 minutes
          - Tags: pod_id=<pod_id>, environment=${var.environment}

       b. Create All-Purpose Cluster:
          - Click "All-Purpose Clusters" tab → "Create Cluster"
          - Name: <pod_id>-interactive (e.g., podA-interactive)
          - Pool: <pod_id>-pool
          - Autoscaling: ${var.cluster_autoscale_min}-${var.cluster_autoscale_max} workers
          - Auto Termination: ${var.cluster_autotermination_minutes} minutes
          - Tags: pod_id=<pod_id>, workload=interactive

    Option 2: Create via Databricks REST API (Automated)
    ---------------------------------------------------
    Use the Databricks CLI or REST API with the configurations from 'recommended_cluster_pools' and 'recommended_clusters' outputs.

    Option 3: Create via Databricks Terraform Provider (Infrastructure-as-Code)
    --------------------------------------------------------------------------
    Add the databricks provider to your Terraform configuration:

    provider "databricks" {
      host = "${azurerm_databricks_workspace.platform.workspace_url}"
      azure_workspace_resource_id = "${azurerm_databricks_workspace.platform.id}"
    }

    Then use databricks_cluster_pool and databricks_cluster resources with the recommended configurations.

    SCALABILITY:
    -----------
    To add a new pod (e.g., podD):
    1. Update var.pod_ids in your terraform.tfvars: pod_ids = ["podA", "podB", "podC", "podD"]
    2. Run: terraform apply
    3. Check updated 'recommended_cluster_pools' and 'recommended_clusters' outputs
    4. Create podD-pool and podD-interactive cluster using any of the 3 options above
  EOT
}

output "scalability_summary" {
  description = "Quick reference for adding new pods"
  value = {
    current_pods     = var.pod_ids
    clusters_per_pod = 1
    total_clusters   = length(var.pod_ids) * 1
    to_add_new_pod   = "Add pod ID to var.pod_ids list, run terraform apply, create cluster pool and cluster using outputs"
    max_pods         = "Unlimited (workspace supports 100+ clusters)"
  }
}

output "cost_tracking_tags" {
  description = "Tags to use for cost allocation per pod"
  value = {
    for pod_id in var.pod_ids :
    pod_id => {
      pod_id      = pod_id
      environment = var.environment
      cost_center = pod_id
      managed_by  = "terraform"
    }
  }
}

output "data_lake_access_verification" {
  description = "Commands to verify Databricks can access Data Lake"
  value = <<-EOT
    After creating clusters, verify Data Lake access with these Databricks notebook commands:

    # Python - Test read access to bronze layer
    df = spark.read.format("delta").load("abfss://bronze@<storage-account>.dfs.core.windows.net/podA/hr/")
    display(df)

    # Python - Test write access to bronze layer
    test_df = spark.createDataFrame([(1, "test")], ["id", "value"])
    test_df.write.format("delta").mode("overwrite").save("abfss://bronze@<storage-account>.dfs.core.windows.net/podA/test/")

    # Scala - Test read access
    val df = spark.read.format("delta").load("abfss://bronze@<storage-account>.dfs.core.windows.net/podA/hr/")
    display(df)

    If you get access denied errors:
    1. Verify RBAC role assignment exists (Storage Blob Data Contributor)
    2. Wait 5 minutes for RBAC propagation
    3. Restart cluster to pick up new permissions
  EOT
}
