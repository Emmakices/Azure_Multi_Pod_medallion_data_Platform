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
