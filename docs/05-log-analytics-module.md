# Step 5: Creating the Log Analytics Module

## Overview

In this step, we build the first of our Terraform modules: the Log Analytics workspace. This workspace will serve as the central nervous system for monitoring your entire Delta Lake infrastructure. Every service we deploy - Data Factory, Databricks, and Data Lake Storage - will send their diagnostic logs, metrics, and telemetry to this workspace, giving you a single pane of glass for observability.

## Understanding Log Analytics in Azure

Azure Log Analytics is a service that collects and analyzes telemetry data from various sources. Think of it as a centralized logging and monitoring database where all your infrastructure components report their health, performance metrics, and operational data.

### Why Log Analytics Comes First

We're creating the Log Analytics module before other modules for a strategic reason: when we create subsequent resources like storage accounts and Databricks workspaces, we want to immediately configure them to send their diagnostic logs to Log Analytics. If we created the workspace later, we'd have to go back and update all existing resources.

### What Log Analytics Provides

**Centralized Logging**: Instead of checking logs in multiple places, everything flows to one location.

**Query Capabilities**: You can use Kusto Query Language (KQL) to search, filter, and analyze logs across all services.

**Alerting**: Set up alerts based on log patterns or metric thresholds.

**Dashboards**: Create visual dashboards to monitor the health of your infrastructure.

**Retention Control**: Define how long to keep logs for compliance and cost management.

**Integration**: Works seamlessly with other Azure services for diagnostics and monitoring.

## Module Structure

Like all well-designed Terraform modules, our Log Analytics module consists of four files, each serving a specific purpose:

**variables.tf**: Defines the inputs the module accepts
**main.tf**: Contains the actual resource definitions
**outputs.tf**: Exposes values for use by other modules or configurations
**README.md**: Documents how to use the module

## Part 1: Module Variables (variables.tf)

The variables file defines what parameters users of this module can customize.

### Creating the Variables File

Create a file named `variables.tf` in `terraform/modules/log-analytics/`:

```hcl
variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "project_name" {
  description = "Project name to be used in resource naming"
  type        = string
}

variable "sku" {
  description = "SKU for Log Analytics workspace"
  type        = string
  default     = "PerGB2018"
  validation {
    condition     = contains(["Free", "PerNode", "PerGB2018", "Standard", "Standalone", "Premium"], var.sku)
    error_message = "SKU must be one of: Free, PerNode, PerGB2018, Standard, Standalone, Premium."
  }
}

variable "retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
  validation {
    condition     = var.retention_days >= 30 && var.retention_days <= 730
    error_message = "Retention days must be between 30 and 730."
  }
}

variable "daily_quota_gb" {
  description = "Daily ingestion quota in GB. -1 means unlimited"
  type        = number
  default     = -1
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}
```

### Understanding the Variables

**Required Variables** (no defaults):
These must be provided by whoever calls the module:

- **environment**: Identifies which environment this workspace belongs to (dev, staging, prod)
- **location**: The Azure region where the workspace will be created
- **resource_group_name**: The resource group that will contain the workspace
- **project_name**: Used in naming the workspace

**Optional Variables with Defaults**:

**sku**: The pricing tier for Log Analytics. We default to "PerGB2018", which is the current standard pricing model where you pay based on the amount of data ingested per gigabyte.

Other SKU options:
- **Free**: 500 MB per day limit, 7 day retention (good for testing)
- **PerNode**: Charges per monitored node
- **Standard/Standalone/Premium**: Older pricing models, mostly deprecated

**retention_days**: How long logs are stored before being deleted. The default is 30 days, which balances cost with having enough historical data for troubleshooting. Azure requires a minimum of 30 days and allows up to 730 days (2 years).

**daily_quota_gb**: A cost control mechanism. Setting this to a positive number limits how much data can be ingested per day. Once the quota is hit, no more data is accepted until the next day. The default of -1 means unlimited, which is fine for development but should be reconsidered for production.

**tags**: A map of key-value pairs applied to the workspace for organization and cost tracking.

### Variable Validation

Notice the `validation` blocks in the SKU and retention_days variables:

```hcl
validation {
  condition     = var.retention_days >= 30 && var.retention_days <= 730
  error_message = "Retention days must be between 30 and 730."
}
```

These validation blocks prevent invalid values from being used. If someone tries to set `retention_days = 10`, Terraform will fail with a clear error message before attempting to create any resources. This is defensive programming that catches configuration errors early.

## Part 2: Main Module Resources (main.tf)

The main file defines the actual Azure resources that will be created.

### Creating the Main File

Create a file named `main.tf` in `terraform/modules/log-analytics/`:

```hcl
# Log Analytics Workspace for centralized monitoring and diagnostics

locals {
  workspace_name = "log-${var.project_name}-${var.environment}"
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = local.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  retention_in_days   = var.retention_days
  daily_quota_gb      = var.daily_quota_gb

  tags = var.tags
}

# Log Analytics Solutions for enhanced monitoring

resource "azurerm_log_analytics_solution" "container_insights" {
  solution_name         = "ContainerInsights"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }

  tags = var.tags
}

resource "azurerm_log_analytics_solution" "security" {
  solution_name         = "Security"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Security"
  }

  tags = var.tags
}

resource "azurerm_log_analytics_solution" "updates" {
  solution_name         = "Updates"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Updates"
  }

  tags = var.tags
}

resource "azurerm_log_analytics_solution" "sql_assessment" {
  solution_name         = "SQLAssessment"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/SQLAssessment"
  }

  tags = var.tags
}
```

### Understanding the Configuration

**Local Values**:
```hcl
locals {
  workspace_name = "log-${var.project_name}-${var.environment}"
}
```

The `locals` block defines local variables computed from input variables. We create a standardized naming convention: `log-deltalake-dev`. Using locals keeps our naming consistent and makes it easy to change the pattern in one place if needed.

**The Log Analytics Workspace Resource**:

This is the primary resource the module creates:

```hcl
resource "azurerm_log_analytics_workspace" "main" {
  name                = local.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  retention_in_days   = var.retention_days
  daily_quota_gb      = var.daily_quota_gb
  tags                = var.tags
}
```

Each parameter is passed through from the module's input variables, giving the caller full control over the configuration.

**Log Analytics Solutions**:

Solutions are add-ons that enhance the Log Analytics workspace with pre-built queries, views, and dashboards for specific scenarios. We're adding four solutions:

**Container Insights**:
Provides monitoring for containerized applications. While we're not running traditional containers, Databricks uses container-based compute, and this solution can provide insights into those workloads.

**Security**:
The Security solution provides:
- Security event collection and analysis
- Threat detection
- Vulnerability assessment
- Security compliance dashboards

This is valuable for any production infrastructure to identify potential security issues.

**Updates**:
Tracks system updates and patches across your infrastructure. This helps ensure systems are up to date and compliant with organizational policies.

**SQL Assessment**:
Although we're primarily using Delta Lake (Parquet files), if you extend your infrastructure with Azure SQL databases for metadata or catalogs, this solution provides:
- SQL Server health checks
- Performance recommendations
- Best practice assessments
- Configuration analysis

### Why These Solutions

These solutions are free to add (you only pay for data ingestion) and provide immediate value. They come with pre-configured dashboards and queries that would take significant time to build manually. Even if you don't use all of them immediately, having them configured means they'll be ready when needed.

### Solution Dependencies

Each solution resource references the workspace:

```hcl
workspace_resource_id = azurerm_log_analytics_workspace.main.id
workspace_name        = azurerm_log_analytics_workspace.main.name
```

This creates an implicit dependency, ensuring Terraform creates the workspace before attempting to add solutions to it.

## Part 3: Module Outputs (outputs.tf)

Outputs expose information about created resources so other modules can use them.

### Creating the Outputs File

Create a file named `outputs.tf` in `terraform/modules/log-analytics/`:

```hcl
output "workspace_id" {
  description = "The ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "workspace_name" {
  description = "The name of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.name
}

output "workspace_resource_id" {
  description = "The resource ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.id
}

output "primary_shared_key" {
  description = "The primary shared key for the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive   = true
}

output "secondary_shared_key" {
  description = "The secondary shared key for the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.secondary_shared_key
  sensitive   = true
}

output "workspace_customer_id" {
  description = "The workspace (customer) ID for the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.workspace_id
}

output "location" {
  description = "The location of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.main.location
}
```

### Understanding the Outputs

**workspace_id**:
The Azure resource ID of the workspace. This is what other resources use when configuring diagnostic settings. For example, when we create the Data Lake storage account, we'll configure it to send diagnostics to this workspace ID.

**workspace_name**:
The human-readable name. Useful for documentation and manual operations.

**Shared Keys**:
The primary and secondary shared keys are authentication credentials used by services that push logs to this workspace. Notice these outputs are marked `sensitive = true`, which prevents Terraform from displaying them in console output or logs. They're still stored in the state file, but won't accidentally appear in build logs or terminal history.

**workspace_customer_id**:
This is confusingly named in Azure's API. It's also called the "workspace ID" in some contexts. Some older services use this ID instead of the resource ID when configuring log shipping. We expose both to support all scenarios.

**location**:
The Azure region where the workspace was created. Sometimes useful for ensuring resources are co-located.

### Why These Specific Outputs

These outputs were chosen because they're the information other modules and services need to integrate with Log Analytics:

- Diagnostic settings require the workspace resource ID
- Log shipping agents need the customer ID and shared key
- Documentation and automation scripts benefit from having the name and location

## Part 4: Module Documentation (README.md)

Good modules include documentation explaining how to use them.

### Creating the README File

Create a file named `README.md` in `terraform/modules/log-analytics/`:

```markdown
# Log Analytics Module

## Overview

This module creates an Azure Log Analytics workspace that serves as the central monitoring and observability hub for the Delta Lake infrastructure. All diagnostic logs, metrics, and telemetry from other services flow into this workspace.

## Resources Created

- **Log Analytics Workspace**: The main workspace for log collection and analysis
- **Container Insights Solution**: For monitoring containerized workloads
- **Security Solution**: For security monitoring and threat detection
- **Updates Solution**: For tracking system updates and patches
- **SQL Assessment Solution**: For SQL database health and performance monitoring

## Usage

```hcl
module "log_analytics" {
  source = "../../modules/log-analytics"

  environment         = "dev"
  location            = "eastus"
  resource_group_name = "rg-delta-lake-dev"
  project_name        = "deltalake"
  sku                 = "PerGB2018"
  retention_days      = 30
  tags = {
    Environment = "dev"
    Project     = "Delta Lake"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| environment | Environment name (dev, staging, prod) | string | - | yes |
| location | Azure region for resources | string | - | yes |
| resource_group_name | Name of the resource group | string | - | yes |
| project_name | Project name to be used in resource naming | string | - | yes |
| sku | SKU for Log Analytics workspace | string | PerGB2018 | no |
| retention_days | Number of days to retain logs | number | 30 | no |
| daily_quota_gb | Daily ingestion quota in GB (-1 for unlimited) | number | -1 | no |
| tags | Tags to apply to resources | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| workspace_id | The ID of the Log Analytics workspace |
| workspace_name | The name of the Log Analytics workspace |
| workspace_customer_id | The workspace (customer) ID for authentication |
| primary_shared_key | The primary shared key (sensitive) |
| secondary_shared_key | The secondary shared key (sensitive) |
| location | The location of the workspace |

## Features

### Log Retention
Configurable retention period between 30-730 days for compliance and cost management.

### Daily Quota
Optional daily ingestion quota to control costs in non-production environments.

### Monitoring Solutions
Pre-configured solutions for container monitoring, security, updates, and SQL assessment.

## Notes

- The workspace uses the PerGB2018 pricing tier by default, which charges based on data ingestion
- Sensitive outputs (shared keys) are marked as sensitive and won't display in console output
- The workspace name follows the pattern: `log-{project_name}-{environment}`
```

### Why Documentation Matters

This README serves multiple purposes:

**Onboarding**: New team members can understand what the module does without reading the code.

**Reference**: The inputs and outputs tables serve as quick reference for using the module.

**Examples**: The usage example shows exactly how to call the module.

**Maintenance**: Documents design decisions and configuration patterns for future updates.

## Verifying the Module Structure

After creating all four files, verify they're in place:

```bash
# List files in the log-analytics module directory
ls terraform/modules/log-analytics/
```

You should see:
```
README.md
main.tf
outputs.tf
variables.tf
```

Check that file contents are correct:

```bash
# Display the structure of the module
tree terraform/modules/log-analytics/
```

You can also use a simple directory listing:

```bash
# Windows Command Prompt
dir terraform\modules\log-analytics

# PowerShell
Get-ChildItem terraform\modules\log-analytics

# Bash/Linux/Mac
ls -la terraform/modules/log-analytics/
```

## Testing the Module Syntax

While we can't fully test the module yet (we need the dev environment configuration to call it), we can validate the syntax:

```bash
# Navigate to the module directory
cd terraform/modules/log-analytics

# Format the Terraform files
terraform fmt

# Initialize Terraform in the module directory (downloads providers)
terraform init

# Validate the configuration
terraform validate
```

The validation will check for syntax errors and ensure resource references are correct. However, since this module expects variables to be passed in, you might see warnings about missing values. That's expected.

## How This Module Will Be Used

In the dev environment's main.tf, we already created a module block that calls this module:

```hcl
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
```

When we eventually run `terraform apply` from the dev environment, Terraform will:

1. Read this module block
2. Navigate to the module source path
3. Process the module's variables.tf, main.tf, and outputs.tf
4. Create the Log Analytics workspace and solutions
5. Make the module's outputs available for other resources to reference

## Cost Considerations

Understanding the costs associated with Log Analytics helps you make informed decisions:

**Data Ingestion**: The primary cost driver. With PerGB2018 pricing, you pay per gigabyte of data ingested. The first 5 GB per month is free.

**Data Retention**: The first 31 days of retention is included. Extended retention beyond 31 days incurs additional charges.

**Daily Quota**: In development environments, consider setting a daily quota to prevent unexpected costs if something starts logging excessively.

Typical costs for a small dev environment might be $5-20 per month, while production environments vary widely based on logging volume.

## Integration Points

This Log Analytics workspace will integrate with:

**Data Lake Storage**: Diagnostic logs for storage operations, authentication events, and access patterns

**Azure Databricks**: Cluster logs, job execution logs, and notebook activity

**Data Factory**: Pipeline runs, activity execution, and trigger events

**Azure Monitor**: Aggregated metrics and alerts across all services

Each of these integrations happens through diagnostic settings, which we'll configure when creating those respective modules.

## Common Queries

Once your workspace is collecting data, you can query it using Kusto Query Language (KQL). Here are some useful starter queries:

**View all logs from the last hour**:
```kql
AzureDiagnostics
| where TimeGenerated > ago(1h)
| order by TimeGenerated desc
```

**Count events by resource**:
```kql
AzureDiagnostics
| summarize count() by Resource
```

**Find errors in the last 24 hours**:
```kql
AzureDiagnostics
| where TimeGenerated > ago(24h)
| where Level == "Error"
| project TimeGenerated, Resource, OperationName, ResultDescription
```

These queries run in the Azure Portal under the Log Analytics workspace's "Logs" section.

## What's Next

With the Log Analytics module complete, the next steps are:

1. Create the Data Lake module for storage
2. Create the Databricks module for compute
3. Create the Data Factory module for orchestration
4. After all modules are complete, initialize and apply the dev environment configuration
5. Verify the Log Analytics workspace was created successfully
6. Configure diagnostic settings on other resources to send logs to this workspace

The Log Analytics workspace is now ready to receive logs. As we create the other modules, we'll configure them to send their diagnostic data here.

## Command Reference

Here's a quick reference of commands used in this step:

```bash
# Verify module files exist
ls terraform/modules/log-analytics/

# Navigate to module directory
cd terraform/modules/log-analytics

# Format Terraform files
terraform fmt

# Initialize module (download providers)
terraform init

# Validate module syntax
terraform validate

# View module structure (if tree is installed)
tree .

# Return to project root
cd ../../..
```

## Files Created in This Step

```
terraform/modules/log-analytics/
├── variables.tf  - Input variable declarations
├── main.tf      - Log Analytics workspace and solutions
├── outputs.tf   - Output value declarations
└── README.md    - Module documentation
```

## Key Takeaways

- Log Analytics provides centralized monitoring for your entire infrastructure
- The module creates a workspace plus four monitoring solutions for enhanced capabilities
- Variable validation catches configuration errors before resources are created
- Sensitive outputs like shared keys are marked to prevent accidental exposure
- The workspace will serve as the destination for diagnostic logs from all other services
- Retention and daily quota settings provide cost control mechanisms
- Solutions are free add-ons that provide pre-built dashboards and queries
- The module follows Terraform best practices with clear separation of variables, resources, and outputs
- Documentation in README.md helps team members understand and use the module
- The workspace must be created before other resources so they can send diagnostics to it
