# ============================================================================
# Terraform Variables for Hash Validation Pipeline
# ============================================================================

# ============================================================================
# Basic Configuration
# ============================================================================

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be dev, test, or prod"
  }
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "Canada Central"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

# ============================================================================
# Storage Account Configuration
# ============================================================================

variable "storage_account_name" {
  description = "Name of the existing storage account for data"
  type        = string
  default     = "stdldevshared77b5h3"
}

# ============================================================================
# SQL Server Configuration
# ============================================================================

variable "sql_server_name" {
  description = "Name of the existing SQL Server"
  type        = string
}

variable "sql_database_name" {
  description = "Name of the SQL database for logging"
  type        = string
  default     = "hash_validation_db"
}

variable "sql_connection_string" {
  description = "SQL Server connection string"
  type        = string
  sensitive   = true
}

# ============================================================================
# Alert Configuration
# ============================================================================

variable "alert_email_recipients" {
  description = "Comma-separated list of email addresses for alerts"
  type        = string
  default     = "manager@company.com,team@company.com"
}

variable "sendgrid_api_key" {
  description = "SendGrid API key for email alerts (optional)"
  type        = string
  default     = ""
  sensitive   = true
}

# ============================================================================
# Tags
# ============================================================================

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default = {
    project     = "hash-validation"
    managed_by  = "terraform"
    cost_center = "data_platform"
  }
}
