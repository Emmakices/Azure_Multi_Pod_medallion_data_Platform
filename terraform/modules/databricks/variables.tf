# Variables for Shared Databricks Module
# This module creates ONE Databricks workspace shared by all pods
# Each pod gets dedicated cluster pools and clusters for resource isolation
# Add new pods by updating pod_ids list - clusters scale automatically

variable "resource_group_name" {
  description = "Resource group name for shared Databricks workspace"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
}

variable "pod_ids" {
  description = "List of pod identifiers - cluster pools and clusters will be created per pod. Add new pods here (e.g., podD, podE) for automatic scaling."
  type        = list(string)
  default     = ["podA", "podB", "podC"]
}

variable "data_lake_id" {
  description = "Data Lake Gen2 storage account resource ID for RBAC"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace ID for diagnostics"
  type        = string
}

variable "cluster_node_type" {
  description = "Azure VM size for Databricks cluster nodes (e.g., Standard_DS3_v2, Standard_DS4_v2)"
  type        = string
  default     = "Standard_DS3_v2"
}

variable "cluster_autoscale_min" {
  description = "Minimum number of worker nodes per cluster (cost optimization: set to 1)"
  type        = number
  default     = 1
}

variable "cluster_autoscale_max" {
  description = "Maximum number of worker nodes per cluster (performance: set to 3-5 for dev, higher for prod)"
  type        = number
  default     = 3
}

variable "cluster_autotermination_minutes" {
  description = "Auto-terminate clusters after N minutes of inactivity (cost optimization: 15-30 min recommended)"
  type        = number
  default     = 20
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
