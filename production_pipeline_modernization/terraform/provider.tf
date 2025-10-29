# ============================================================================
# Terraform Provider Configuration
# ============================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  # Backend configuration for storing Terraform state
  # Uncomment and configure for team collaboration
  # backend "azurerm" {
  #   resource_group_name  = "rg-terraform-state"
  #   storage_account_name = "sttfstate"
  #   container_name       = "tfstate"
  #   key                  = "hash-validation.tfstate"
  # }
}

provider "azurerm" {
  features {
    # Feature flags for resource behavior
    resource_group {
      prevent_deletion_if_contains_resources = true
    }

    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }

  # Use environment variables or Azure CLI authentication
  # No need to specify credentials here if using Azure CLI
}

provider "random" {
  # No configuration needed
}

provider "local" {
  # No configuration needed
}
