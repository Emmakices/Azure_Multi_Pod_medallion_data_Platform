# Variables for Shared Data Factory Module
# This module creates ONE Azure Data Factory shared by all pods
# Pipelines use parameters to route data to pod-specific storage folders

variable "resource_group_name" {
  description = "Resource group name for shared Data Factory"
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

variable "source_blob_storage_id" {
  description = "Source blob storage account resource ID for RBAC"
  type        = string
}

variable "source_blob_storage_name" {
  description = "Source blob storage account name for linked service"
  type        = string
}

variable "data_lake_id" {
  description = "Data Lake Gen2 storage account resource ID for RBAC"
  type        = string
}

variable "data_lake_endpoint" {
  description = "Data Lake Gen2 primary DFS endpoint for linked service"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace ID for diagnostics"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
