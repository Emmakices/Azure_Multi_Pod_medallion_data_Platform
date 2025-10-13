# Variables for Shared Data Lake Gen2 Module
# This module creates ONE ADLS Gen2 storage account shared by all pods
# Medallion architecture with company-level folder isolation
# Each pod processes data for 3-4 companies (Finance company, Operations company, etc.)

variable "resource_group_name" {
  description = "Resource group name for shared data lake"
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
  description = "List of pod identifiers (processing units)"
  type        = list(string)
  default     = ["podA", "podB", "podC"]
}

variable "companies" {
  description = "Map of pod to company/account configuration. Each pod processes data for multiple companies."
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

variable "domains" {
  description = "List of data types/domains processed for each company (hr, payroll, inventory, etc.). Each company folder contains these domain subfolders."
  type        = list(string)
  default     = ["hr", "payroll", "finance", "inventory", "campaigns", "tickets", "crm", "benefits", "audit_logs"]
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
