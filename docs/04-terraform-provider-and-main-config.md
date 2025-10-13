# Step 4: Terraform Provider and Main Configuration

## Overview

In this step, we create the core Terraform configuration files that define how Terraform will interact with Azure and orchestrate your Delta Lake infrastructure. These files form the foundation of your infrastructure-as-code setup and determine what resources will be created and how they'll be configured.

## Understanding Terraform Configuration Files

A typical Terraform environment configuration consists of four main files, each serving a specific purpose:

**provider.tf**: Specifies which cloud provider to use and configures authentication and feature flags
**variables.tf**: Declares input variables that make your configuration flexible and reusable
**main.tf**: Contains the actual resource definitions and module calls that build your infrastructure
**outputs.tf**: Defines values that Terraform will display after deployment, useful for downstream automation

This separation of concerns makes your Terraform code organized, maintainable, and easier to understand.

## Part 1: Provider Configuration (provider.tf)

The provider configuration file tells Terraform which cloud platform you're using and establishes the connection parameters. It also specifies version constraints to ensure consistency across your team.

### Creating the Provider Configuration

Create a file named `provider.tf` in the `terraform/environments/dev/` directory:

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~> 1.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }

    storage {
      prevent_deletion_if_contains_resources = false
    }
  }
}

provider "azapi" {
}
```

### Understanding the Configuration

**Terraform Version Requirement**:
```hcl
required_version = ">= 1.5.0"
```
This ensures that anyone running this configuration has at least Terraform version 1.5.0 installed. This prevents issues where newer syntax or features might not work on older versions.

**Required Providers Block**:
The `required_providers` section specifies which provider plugins Terraform needs to download. We're using two providers:

**azurerm**: The primary Azure provider that manages most Azure resources. The version constraint `~> 3.0` means "use any version 3.x but not 4.0 or higher". This allows automatic minor and patch updates while preventing breaking changes.

**azapi**: A supplementary Azure provider that gives access to newer Azure features that haven't been added to azurerm yet. This is useful for cutting-edge services or preview features.

**Provider Features Block**:
The `features` block within the azurerm provider configures provider-level behaviors:

**Resource Group Settings**:
```hcl
prevent_deletion_if_contains_resources = false
```
By default, Azure prevents deleting resource groups that contain resources. Setting this to false allows Terraform to delete non-empty resource groups during `terraform destroy`. This is convenient for dev environments but should be set to true in production.

**Key Vault Settings**:
```hcl
purge_soft_delete_on_destroy    = true
recover_soft_deleted_key_vaults = true
```
Key Vaults in Azure have soft-delete enabled by default, meaning deleted vaults remain recoverable for a period. Setting `purge_soft_delete_on_destroy` to true makes Terraform permanently delete key vaults instead of soft-deleting them. The recovery setting allows Terraform to recover previously deleted key vaults with the same name.

**Storage Settings**:
```hcl
prevent_deletion_if_contains_resources = false
```
Similar to resource groups, this allows Terraform to delete storage accounts even if they contain blobs or containers.

### Authentication

Notice there's no explicit authentication configuration in the provider block. This is intentional. The azurerm provider automatically uses your Azure CLI credentials from the `az login` command you ran earlier. For production or CI/CD environments, you would typically configure authentication using:

- Service Principal with client credentials
- Managed Identity (when running on Azure resources)
- Environment variables

## Part 2: Variables Configuration (variables.tf)

Variables make your Terraform configuration flexible and reusable. Instead of hardcoding values, you declare variables with types and defaults, then reference them throughout your configuration.

### Creating the Variables File

Create a file named `variables.tf` in the `terraform/environments/dev/` directory:

```hcl
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "project_name" {
  description = "Project name to be used in resource naming"
  type        = string
  default     = "deltalake"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "rg-delta-lake-dev"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "dev"
    Project     = "Delta Lake"
    ManagedBy   = "Terraform"
  }
}

# Data Lake Variables
variable "storage_account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "storage_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"
}

variable "data_lake_containers" {
  description = "List of data lake containers to create"
  type        = list(string)
  default     = ["raw", "bronze", "silver", "gold"]
}

# Databricks Variables
variable "databricks_sku" {
  description = "Databricks workspace SKU"
  type        = string
  default     = "standard"
}

# Log Analytics Variables
variable "log_analytics_sku" {
  description = "Log Analytics workspace SKU"
  type        = string
  default     = "PerGB2018"
}

variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}
```

### Understanding Variable Declarations

Each variable follows this structure:

**description**: Human-readable explanation of what the variable controls
**type**: The data type (string, number, bool, list, map, object, etc.)
**default**: The value used if no override is provided

### Key Variables Explained

**Environment Variables**:
The `environment`, `location`, and `project_name` variables form the foundation of your naming strategy. These values get interpolated into resource names throughout your configuration.

**Resource Group Name**:
While we set a default, this can be overridden via terraform.tfvars or command-line flags.

**Tags**:
The tags variable uses `map(string)` type, creating key-value pairs that Azure applies to resources for organization, cost tracking, and automation. Every resource in your infrastructure will receive these tags.

**Data Lake Containers**:
This list variable defines the medallion architecture layers:
- **raw**: Landing zone for ingested data in its original format
- **bronze**: Validated and enriched raw data
- **silver**: Cleaned, conformed, and aggregated data
- **gold**: Business-level aggregates and models ready for analytics

This is a common pattern in modern data lake architectures.

**Storage Configuration**:
- **storage_account_tier**: "Standard" uses HDD-based storage (cheaper), "Premium" uses SSD (faster)
- **storage_replication_type**: "LRS" (Locally Redundant) is cheapest, suitable for dev; production might use "GRS" (Geo-Redundant)

**Databricks SKU**:
"standard" is the basic tier. Other options include "premium" (adds role-based access control) and "trial" (limited time).

**Log Analytics**:
- **log_analytics_sku**: "PerGB2018" is the current standard pricing model based on data ingestion
- **log_retention_days**: How long to keep logs; 30 days is reasonable for dev, production often uses 90-365 days

## Part 3: Main Configuration (main.tf)

The main configuration file orchestrates your entire infrastructure by creating resources and calling modules.

### Creating the Main Configuration

Create a file named `main.tf` in the `terraform/environments/dev/` directory:

```hcl
# Main Terraform configuration for Delta Lake project - Dev Environment

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# Log Analytics Module
module "log_analytics" {
  source = "../../modules/log-analytics"

  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  project_name        = var.project_name
  sku                 = var.log_analytics_sku
  retention_days      = var.log_retention_days
  tags                = var.tags
}

# Data Lake Module
module "data_lake" {
  source = "../../modules/data-lake"

  environment            = var.environment
  location               = var.location
  resource_group_name    = azurerm_resource_group.main.name
  project_name           = var.project_name
  account_tier           = var.storage_account_tier
  replication_type       = var.storage_replication_type
  containers             = var.data_lake_containers
  log_analytics_workspace_id = module.log_analytics.workspace_id
  tags                   = var.tags
}

# Databricks Module
module "databricks" {
  source = "../../modules/databricks"

  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  project_name        = var.project_name
  sku                 = var.databricks_sku
  tags                = var.tags

  depends_on = [module.data_lake]
}

# Data Factory Module
module "data_factory" {
  source = "../../modules/data-factory"

  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  project_name        = var.project_name
  storage_account_id  = module.data_lake.storage_account_id
  tags                = var.tags

  depends_on = [module.data_lake]
}
```

### Understanding the Configuration Structure

**Resource Group**:
The first resource we create is the resource group, which serves as a logical container for all other resources. Notice we use `var.resource_group_name` to reference the variable we declared earlier.

**Module Blocks**:
Each module block instantiates a reusable module. The general structure is:

```hcl
module "name" {
  source = "path/to/module"

  # Input variables for the module
  variable_name = value
}
```

**Module Source Paths**:
The `source` parameter uses relative paths: `../../modules/log-analytics` means "go up two directories, then into modules/log-analytics". This points to the module directories we created earlier.

**Passing Values to Modules**:
Each module receives the variables it needs. Some come from our variables.tf file (`var.environment`), while others come from resource attributes (`azurerm_resource_group.main.name`).

**Resource Dependency Chain**:
Notice the `depends_on` meta-argument in the databricks and data_factory modules. This explicitly tells Terraform to wait until the data lake module is fully created before starting these modules. While Terraform automatically figures out most dependencies, explicit dependencies ensure correct ordering when it's critical.

**Module Output References**:
The data_lake module receives `log_analytics_workspace_id = module.log_analytics.workspace_id`. This references an output from the log_analytics module. The module must define this output (which we'll do later) for this reference to work.

### Deployment Order

Terraform will create resources in this order:
1. Resource group (everything else depends on this)
2. Log Analytics workspace (independent, can run parallel with next steps)
3. Data Lake storage (uses Log Analytics workspace ID for diagnostics)
4. Databricks workspace (depends on data lake)
5. Data Factory (depends on data lake)

## Part 4: Outputs Configuration (outputs.tf)

Outputs expose information about your infrastructure after Terraform creates it. This is useful for:
- Seeing connection information (like URLs or IDs)
- Passing values to other Terraform configurations
- Providing data to automation scripts

### Creating the Outputs File

Create a file named `outputs.tf` in the `terraform/environments/dev/` directory:

```hcl
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_location" {
  description = "Location of the resource group"
  value       = azurerm_resource_group.main.location
}

# Data Lake Outputs
output "data_lake_storage_account_name" {
  description = "Name of the data lake storage account"
  value       = module.data_lake.storage_account_name
}

output "data_lake_storage_account_id" {
  description = "ID of the data lake storage account"
  value       = module.data_lake.storage_account_id
}

output "data_lake_primary_dfs_endpoint" {
  description = "Primary DFS endpoint for the data lake"
  value       = module.data_lake.primary_dfs_endpoint
}

output "data_lake_containers" {
  description = "List of created data lake containers"
  value       = module.data_lake.container_names
}

# Databricks Outputs
output "databricks_workspace_id" {
  description = "ID of the Databricks workspace"
  value       = module.databricks.workspace_id
}

output "databricks_workspace_url" {
  description = "URL of the Databricks workspace"
  value       = module.databricks.workspace_url
}

# Data Factory Outputs
output "data_factory_id" {
  description = "ID of the Data Factory"
  value       = module.data_factory.data_factory_id
}

output "data_factory_name" {
  description = "Name of the Data Factory"
  value       = module.data_factory.data_factory_name
}

# Log Analytics Outputs
output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace"
  value       = module.log_analytics.workspace_id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = module.log_analytics.workspace_name
}
```

### Understanding Output Declarations

Each output follows this pattern:

**description**: Explains what the output represents
**value**: The actual value to output, can reference resources, modules, or variables

**Direct Resource Outputs**:
```hcl
value = azurerm_resource_group.main.name
```
This directly accesses an attribute from a resource defined in main.tf.

**Module Outputs**:
```hcl
value = module.data_lake.storage_account_name
```
This accesses an output that the data_lake module explicitly exports. The module must define these outputs in its own outputs.tf file.

### Why These Specific Outputs

**Storage Account Information**: You'll need the storage account name and DFS endpoint to configure Databricks and other tools to access your data lake.

**Databricks Workspace URL**: After deployment, you'll use this URL to access the Databricks web interface.

**Resource IDs**: Many Azure services require resource IDs for integration. Having these as outputs makes it easy to reference them in other tools or scripts.

**Container Names**: Useful for validation and for configuring data pipelines that need to know the exact container names.

## File Organization Summary

After completing this step, your `terraform/environments/dev/` directory should contain:

```
terraform/environments/dev/
├── backend.tf    (from previous step)
├── provider.tf   (new)
├── variables.tf  (new)
├── main.tf       (new)
└── outputs.tf    (new)
```

## How These Files Work Together

When you run Terraform commands, here's what happens:

1. **Terraform reads provider.tf** and determines it needs to download the azurerm and azapi providers
2. **It reads backend.tf** and configures remote state storage in Azure
3. **It processes variables.tf** to understand what inputs are available and their defaults
4. **It evaluates main.tf** to build a dependency graph of resources and modules
5. **After creating resources, it evaluates outputs.tf** to determine what to display

## Variable Override Options

While we set defaults in variables.tf, you can override them in several ways:

### Option 1: Create terraform.tfvars

Create a file named `terraform.tfvars` in the same directory:

```hcl
environment = "dev"
location    = "westus2"
log_retention_days = 60
```

Terraform automatically loads this file. Remember, `.tfvars` files are in .gitignore because they often contain secrets.

### Option 2: Use Environment Variables

```bash
export TF_VAR_location="westus2"
export TF_VAR_log_retention_days=60
terraform plan
```

### Option 3: Command Line Flags

```bash
terraform apply -var="location=westus2" -var="log_retention_days=60"
```

### Option 4: Use a Custom Variable File

```bash
terraform apply -var-file="custom.tfvars"
```

## Verifying Your Configuration Files

After creating all four files, verify they're in place:

```bash
# List files in the dev environment directory
ls terraform/environments/dev/
```

You should see:
```
backend.tf
main.tf
outputs.tf
provider.tf
variables.tf
```

Check the syntax of your configuration:

```bash
# Navigate to the dev environment directory
cd terraform/environments/dev

# Format all Terraform files to standard style
terraform fmt

# Validate the configuration syntax
terraform validate
```

Note: `terraform validate` will fail at this point because the modules referenced in main.tf don't exist yet. This is expected. We'll create the modules in the next steps.

## Common Configuration Patterns

### Conditional Resource Creation

You can use the `count` meta-argument to conditionally create resources:

```hcl
variable "create_databricks" {
  type    = bool
  default = true
}

module "databricks" {
  count  = var.create_databricks ? 1 : 0
  source = "../../modules/databricks"
  # ... other parameters
}
```

### Dynamic Blocks

For repeating nested blocks, use dynamic blocks:

```hcl
dynamic "ip_rule" {
  for_each = var.allowed_ips
  content {
    ip_address_or_range = ip_rule.value
  }
}
```

## What's Next

Now that you have the main configuration files in place, the next steps are:

1. Create the module definitions for log-analytics, data-lake, databricks, and data-factory
2. Each module will have its own variables.tf, main.tf, and outputs.tf
3. After modules are complete, run `terraform init` to initialize the configuration
4. Run `terraform plan` to see what will be created
5. Run `terraform apply` to deploy your infrastructure

The modules are where the actual Azure resources get defined. The configuration we created here orchestrates those modules.

## Command Reference

Here's a quick reference of relevant commands:

```bash
# Navigate to the dev environment
cd terraform/environments/dev

# Format Terraform files
terraform fmt

# Validate configuration syntax
terraform validate

# Initialize Terraform (downloads providers, configures backend)
terraform init

# Show what Terraform will create
terraform plan

# Apply the configuration
terraform apply

# Show current state
terraform show

# List all outputs
terraform output

# Show a specific output
terraform output databricks_workspace_url

# Destroy all infrastructure
terraform destroy
```

## Files Created in This Step

```
terraform/environments/dev/
├── provider.tf   - Provider configuration and version constraints
├── variables.tf  - Input variable declarations with defaults
├── main.tf      - Resource and module definitions
└── outputs.tf   - Output value declarations
```

## Key Takeaways

- The provider.tf file configures how Terraform connects to Azure and sets provider-level behaviors
- Variables make your configuration flexible and reusable across environments
- The main.tf file orchestrates your infrastructure by calling modules and creating resources
- Outputs expose important information after deployment for use in automation or manual reference
- Terraform uses these files together to build a complete picture of your desired infrastructure
- Variable values can be overridden through multiple mechanisms for flexibility
- The configuration references modules that don't exist yet, which we'll create next
- Always use version constraints to prevent unexpected breaking changes
- Tags applied consistently help with cost tracking and resource organization
- Resource dependencies can be explicit (depends_on) or implicit (resource references)
