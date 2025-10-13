# Variables for Shared Source Blob Storage Module
# This module creates ONE storage account shared by all pods with folder-based isolation
# Now supports department-level granularity for multi-tenant data ingestion

variable "resource_group_name" {
  description = "Resource group name for shared storage"
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
  description = "List of pod identifiers for folder creation"
  type        = list(string)
  default     = ["podA", "podB", "podC"]
}

variable "companies" {
  description = "Map of pod to company/account configuration. Each pod processes data for multiple companies. Structure: landing/podA/finance/, landing/podA/operations/"
  type = map(object({
    companies = list(string)
  }))
  default = {
    podA = {
      companies = ["finance", "operations", "marketing", "it"]
    }
    podB = {
      companies = ["finance", "operations", "sales"]
    }
    podC = {
      companies = ["finance", "hr_central", "compliance"]
    }
  }
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
