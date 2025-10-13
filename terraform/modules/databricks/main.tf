# Shared Databricks Module
# Provides a SINGLE Databricks workspace shared across all pods
# Each pod gets dedicated cluster pools and clusters for resource isolation
# Architecture supports infinite scalability - add podD, podE, etc. by updating pod_ids list

# Local variables for cluster configuration and workspace settings
locals {
  # Databricks workspace host URL (constructed from workspace_url attribute)
  databricks_host = "https://${azurerm_databricks_workspace.platform.workspace_url}"

  # Default cluster configuration applied to all pod clusters
  # These settings optimize for cost and performance in POC/dev environments
  default_cluster_config = {
    spark_version             = "13.3.x-scala2.12"  # Latest stable Databricks Runtime with Delta Lake support
    node_type_id              = var.cluster_node_type
    autoscale_min_workers     = var.cluster_autoscale_min
    autoscale_max_workers     = var.cluster_autoscale_max
    autotermination_minutes   = var.cluster_autotermination_minutes
  }
}

# Shared Databricks workspace for all pods
# Provides unified environment for notebooks, jobs, and data processing
# Each pod gets isolated clusters but shares the workspace UI and collaboration features
resource "azurerm_databricks_workspace" "platform" {
  name                        = "dbw-${var.environment}-platform"
  location                    = var.location
  resource_group_name         = var.resource_group_name
  sku                         = "standard"
  managed_resource_group_name = "rg-dbw-${var.environment}-platform-managed"
  public_network_access_enabled = true  # Enabled for POC; restrict in production

  tags = var.tags
}

# ═══════════════════════════════════════════════════════════════
# RBAC ROLE ASSIGNMENT
# ═══════════════════════════════════════════════════════════════
# NOTE: Standard SKU Databricks does not have storage_account_identity
# Data Lake access must be configured via:
#   1. Service Principal with cluster configuration
#   2. Storage account key in cluster Spark config
#   3. SAS tokens
#   4. Mount points using service principal credentials
#
# For Premium SKU, uncomment the role assignment below:
#
# resource "azurerm_role_assignment" "databricks_to_datalake" {
#   scope                = var.data_lake_id
#   role_definition_name = "Storage Blob Data Contributor"
#   principal_id         = azurerm_databricks_workspace.platform.storage_account_identity[0].principal_id
#   depends_on           = [azurerm_databricks_workspace.platform]
# }

# ═══════════════════════════════════════════════════════════════
# DIAGNOSTIC SETTINGS
# ═══════════════════════════════════════════════════════════════
# NOTE: Standard SKU Databricks has limited diagnostic logging support
# Most log categories and metrics require Premium SKU
# For production workloads, consider upgrading to Premium SKU for full monitoring
#
# Monitoring alternatives for Standard SKU:
#   1. Databricks Audit Logs (manual export via Databricks CLI)
#   2. Cluster event logs (available in Databricks UI)
#   3. Spark UI metrics (per-cluster monitoring)
#   4. Application Insights integration (custom telemetry)
#
# Uncomment the resource below if using Premium SKU:
#
# resource "azurerm_monitor_diagnostic_setting" "databricks_diagnostics" {
#   name                       = "dbw-${var.environment}-diagnostics"
#   target_resource_id         = azurerm_databricks_workspace.platform.id
#   log_analytics_workspace_id = var.log_analytics_workspace_id
#
#   enabled_log {
#     category = "dbfs"
#   }
#
#   enabled_log {
#     category = "clusters"
#   }
#
#   enabled_log {
#     category = "jobs"
#   }
#
#   enabled_log {
#     category = "notebook"
#   }
#
#   enabled_log {
#     category = "ssh"
#   }
#
#   enabled_log {
#     category = "workspace"
#   }
#
#   metric {
#     category = "AllMetrics"
#     enabled  = true
#   }
#
#   depends_on = [azurerm_databricks_workspace.platform]
# }

# ═══════════════════════════════════════════════════════════════
# CLUSTER POOLS AND CLUSTERS - CONFIGURATION REFERENCE
# ═══════════════════════════════════════════════════════════════
# NOTE: The azurerm provider creates the workspace but NOT clusters/pools
#
# Cluster creation requires one of the following approaches:
#   1. Databricks Terraform Provider (databricks/databricks)
#      - Requires: provider authentication with PAT or Service Principal
#      - Benefit: Fully automated, version-controlled clusters
#      - Setup: Add databricks provider block with host and token/sp config
#
#   2. Databricks REST API (via Terraform null_resource + local-exec)
#      - Requires: REST API calls using workspace URL and authentication token
#      - Benefit: Automated without additional provider dependencies
#      - Setup: Use null_resource with curl commands to Databricks API
#
#   3. Manual Creation in Databricks UI (least ideal)
#      - Requires: Manual point-and-click in Databricks workspace
#      - Benefit: No additional setup, immediate feedback
#      - Drawback: Not infrastructure-as-code, hard to reproduce
#
# RECOMMENDED STRUCTURE FOR CLUSTER POOLS (one per pod):
#
# Current pods (podA, podB, podC) would create 3 cluster pools:
#
# Pool: podA-pool
#   - Instance Type: Standard_DS3_v2 (4 cores, 14GB RAM)
#   - Min Idle Instances: 0 (no idle instances to minimize cost)
#   - Max Capacity: 10 (can scale up to 10 instances for this pod)
#   - Idle Instance Autotermination: 15 minutes
#   - Preloaded Spark Version: 13.3.x-scala2.12
#   - Tags: { pod_id: "podA", environment: "dev", pool_type: "general" }
#
# Pool: podB-pool
#   - Instance Type: Standard_DS3_v2
#   - Min Idle Instances: 0
#   - Max Capacity: 10
#   - Idle Instance Autotermination: 15 minutes
#   - Preloaded Spark Version: 13.3.x-scala2.12
#   - Tags: { pod_id: "podB", environment: "dev", pool_type: "general" }
#
# Pool: podC-pool
#   - Instance Type: Standard_DS3_v2
#   - Min Idle Instances: 0
#   - Max Capacity: 10
#   - Idle Instance Autotermination: 15 minutes
#   - Preloaded Spark Version: 13.3.x-scala2.12
#   - Tags: { pod_id: "podC", environment: "dev", pool_type: "general" }
#
# RECOMMENDED STRUCTURE FOR ALL-PURPOSE CLUSTERS (one per pod):
#
# Current pods (podA, podB, podC) would create 3 interactive clusters:
#
# Cluster: podA-interactive
#   - Cluster Pool: podA-pool
#   - Cluster Mode: Standard (all-purpose)
#   - Databricks Runtime: 13.3.x-scala2.12 (inherits from pool)
#   - Autoscaling: Enabled (1-3 workers)
#   - Autotermination: 20 minutes of inactivity
#   - Spark Config:
#       spark.databricks.delta.preview.enabled = true
#       spark.sql.adaptive.enabled = true
#   - Init Scripts: (optional) Mount ADLS Gen2 paths for podA
#   - Tags: { pod_id: "podA", workload: "interactive", environment: "dev" }
#
# Cluster: podB-interactive
#   - Cluster Pool: podB-pool
#   - Cluster Mode: Standard
#   - Databricks Runtime: 13.3.x-scala2.12
#   - Autoscaling: Enabled (1-3 workers)
#   - Autotermination: 20 minutes
#   - Spark Config: (same as podA)
#   - Tags: { pod_id: "podB", workload: "interactive", environment: "dev" }
#
# Cluster: podC-interactive
#   - Cluster Pool: podC-pool
#   - Cluster Mode: Standard
#   - Databricks Runtime: 13.3.x-scala2.12
#   - Autoscaling: Enabled (1-3 workers)
#   - Autotermination: 20 minutes
#   - Spark Config: (same as podA)
#   - Tags: { pod_id: "podC", workload: "interactive", environment: "dev" }
#
# SCALABILITY MODEL:
#
# Adding podD (new pod):
#   1. Update var.pod_ids in terraform.tfvars: pod_ids = ["podA", "podB", "podC", "podD"]
#   2. Run terraform apply (no workspace changes, but outputs update with podD config)
#   3. In Databricks UI or via API, create:
#      - Cluster Pool: podD-pool (using recommended_cluster_pools output)
#      - Cluster: podD-interactive (using recommended_clusters output)
#   4. Done - podD now has isolated compute resources
#
# Adding podE, podF, etc.: Same process, supports unlimited pods
#
# COST ISOLATION:
#   - Each cluster pool tracks DBU (Databricks Unit) consumption separately
#   - Tags enable cost allocation reports per pod_id
#   - Independent autoscaling means Pod A's spike doesn't affect Pod B's capacity
#
# RESOURCE ISOLATION:
#   - Separate pools prevent one pod from consuming all workspace capacity
#   - Max capacity per pool ensures fair resource distribution
#   - Autotermination minimizes idle resource costs
#
# ═══════════════════════════════════════════════════════════════
# FUTURE ENHANCEMENT OPTIONS
# ═══════════════════════════════════════════════════════════════
#
# 1. JOB CLUSTERS (for production workloads):
#    Create job-specific clusters per pod that auto-terminate after job completion:
#      - Cluster: podA-bronze-to-silver-job
#      - Cluster: podB-silver-to-gold-job
#    Benefits: Lower cost (no idle time), optimized for specific workloads
#
# 2. HIGH-CONCURRENCY CLUSTERS (for BI/SQL analytics):
#    Create shared clusters optimized for concurrent queries:
#      - Cluster: podA-sql-analytics
#      - Mode: High Concurrency (supports multiple users)
#      - Table ACLs: Enabled (for data security)
#    Benefits: Multiple analysts can share cluster, credential passthrough
#
# 3. INSTANCE POOL TYPES PER WORKLOAD:
#    Create specialized pools for different workload types:
#      - podA-compute-pool: Memory-optimized for transformations
#      - podA-analytics-pool: Compute-optimized for aggregations
#      - podA-ml-pool: GPU-enabled for machine learning
#    Benefits: Right-sized instances for specific use cases
#
# 4. MULTI-REGION DEPLOYMENT:
#    Deploy separate workspaces per region but same pod structure:
#      - dbw-dev-platform-eastus (pods A, B, C)
#      - dbw-dev-platform-westus (pods A, B, C)
#    Benefits: Data residency compliance, disaster recovery
#
# ═══════════════════════════════════════════════════════════════
