# ═══════════════════════════════════════════════════════════════════════════════
# VARIABLES - SHARED INFRASTRUCTURE MODEL
# ═══════════════════════════════════════════════════════════════════════════════
# Configuration variables for multi-pod data platform with folder-based isolation
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# CORE ENVIRONMENT VARIABLES
# ═══════════════════════════════════════════════════════════════════════════════

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus"
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    Environment  = "dev"
    Project      = "Delta Lake Platform"
    ManagedBy    = "Terraform"
    Architecture = "Shared Infrastructure"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# POD CONFIGURATION - FOLDER-BASED ISOLATION
# ═══════════════════════════════════════════════════════════════════════════════

variable "pod_ids" {
  description = "List of pod identifiers for folder-based isolation. Add new pods here (e.g., podD, podE) to automatically scale infrastructure."
  type        = list(string)
  default     = ["podA", "podB", "podC"]

  validation {
    condition     = length(var.pod_ids) > 0
    error_message = "At least one pod ID must be specified."
  }
}

variable "companies" {
  description = "Map of pod to company/account configuration. Each pod processes data for 3-4 different companies (e.g., Finance company, Operations company, etc.)"
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
  description = "List of business domains/data types processed for each company (e.g., hr, payroll, inventory). Each company folder contains these domain subfolders."
  type        = list(string)
  default     = ["hr", "payroll", "finance", "inventory", "campaigns", "tickets", "crm", "benefits", "audit_logs"]

  validation {
    condition     = length(var.domains) > 0
    error_message = "At least one domain must be specified."
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# LEGACY VARIABLES (Kept for backward compatibility - not used in shared model)
# ═══════════════════════════════════════════════════════════════════════════════

variable "project_name" {
  description = "[DEPRECATED] Project name - replaced by pod_ids and domains for shared model"
  type        = string
  default     = "deltalake"
}

variable "resource_group_name" {
  description = "[DEPRECATED] Resource group name - now auto-generated as rg-platform-{environment}"
  type        = string
  default     = "rg-delta-lake-dev"
}

variable "tags" {
  description = "[DEPRECATED] Use common_tags instead for shared infrastructure model"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "Delta Lake"
    ManagedBy   = "Terraform"
  }
}

variable "pods" {
  description = "[DEPRECATED] Use pod_ids instead (renamed for consistency across modules)"
  type        = list(string)
  default     = ["poda", "podb", "podc"]
}

variable "databricks_sku" {
  description = "[DEPRECATED] Databricks SKU is now defined in module defaults (Standard SKU)"
  type        = string
  default     = "standard"
}

variable "log_analytics_sku" {
  description = "[DEPRECATED] Log Analytics SKU is now defined in module defaults (PerGB2018)"
  type        = string
  default     = "PerGB2018"
}

variable "log_retention_days" {
  description = "[DEPRECATED] Log retention is now defined in module defaults (30 days)"
  type        = number
  default     = 30
}

# ═══════════════════════════════════════════════════════════════════════════════
# USAGE NOTES:
# ═══════════════════════════════════════════════════════════════════════════════
# 1. To add new pods: Update pod_ids list (e.g., ["podA", "podB", "podC", "podD"])
# 2. To add new domains: Update domains list (e.g., ["hr", "payroll", "finance", "sales"])
# 3. Run: terraform plan to preview folder structure changes
# 4. Run: terraform apply to create new pod/domain folders
#
# The shared infrastructure automatically creates:
# - Source blob folders: <container>/<pod_id>/ (3 containers × N pods)
# - Data lake folders: <layer>/<pod_id>/<domain>/ (3 layers × N pods × M domains)
# - Cluster pool configs: <pod_id>-pool (N pods)
# - Cluster configs: <pod_id>-interactive (N pods)
# ═══════════════════════════════════════════════════════════════════════════════
