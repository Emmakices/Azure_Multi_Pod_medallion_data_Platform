# Azure Multi-Pod Medallion Data Platform

Enterprise-grade data platform built on Azure implementing medallion architecture with multi-pod isolation for company-level data processing.

## Architecture Overview

This project implements a scalable data lakehouse architecture using:

- **Azure Data Lake Storage Gen2** - Medallion architecture (Bronze/Silver/Gold layers)
- **Azure Databricks** - Spark-based data processing with job clusters
- **Azure Data Factory** - Pipeline orchestration with parallel processing
- **Azure Blob Storage** - Landing zone for raw data ingestion
- **Terraform** - Infrastructure as Code for consistent deployment

### Key Features

- **Multi-Pod Architecture**: Complete isolation between business units (pods)
- **Company-Level Processing**: Parallel processing per company using ForEach loops
- **Cost Optimization**: Ephemeral job clusters with 85-96% cost savings vs always-on clusters
- **Medallion Pattern**: Bronze (raw) → Silver (cleansed) → Gold (analytics-ready)
- **Configuration-Driven**: Delta table-based configuration for dynamic pipeline behavior
- **Scalable Design**: Add companies without code changes

## Project Structure

```
.
├── terraform/                  # Infrastructure as Code
│   ├── environments/
│   │   └── dev/               # Development environment
│   └── modules/               # Reusable Terraform modules
│       ├── data-lake/
│       ├── databricks/
│       ├── data-factory/
│       └── source-blob-storage/
├── docs/                      # Comprehensive documentation
├── scripts/                   # Automation scripts
└── databricks_notebooks/      # Databricks notebooks
```

## Prerequisites

- Azure subscription with appropriate permissions
- Azure CLI installed and configured
- Terraform >= 1.0
- Python >= 3.8 (for automation scripts)

## Getting Started

### 1. Authentication Setup

```bash
az login
az account set --subscription "your-subscription-id"
```

### 2. Infrastructure Deployment

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### 3. Configure Azure Data Factory

Follow the comprehensive guide in `docs/14-adf-pipeline-orchestration-company-level.md`

## Documentation

Detailed documentation is available in the `/docs` directory:

1. Azure Authentication
2. Terraform Directory Setup
3. Backend Configuration
4. Terraform Provider Setup
5. Log Analytics Module
6. Deployment Summary
7. Source Blob Storage Module
8. Data Lake Gen2 Module
9. Data Factory Module
10. Databricks Module
11. Databricks Cluster Implementation
12. Databricks Notebooks and ETL
13. Pod-Isolated Notebooks
14. ADF Pipeline Orchestration
15. Company Configuration Table
16. Databricks Notebook Upload Guide

## Architecture Patterns

### Pod Organization

```
landing/{pod}/{company}/        # Raw data ingestion
bronze/{pod}/{company}/{domain}/ # Initial parquet conversion
silver/{pod}/{company}/{domain}/ # Cleansed Delta tables
gold/{pod}/{company}/           # Analytics-ready aggregations
```

### Pipeline Flow

```
Landing Blob → [ADF Copy] → Bronze Layer
    ↓
[Databricks Job Cluster - Per Company]
    ↓
Silver Layer (Cleansed)
    ↓
[Databricks Job Cluster - Per Company]
    ↓
Gold Layer (Analytics)
```

## Cost Optimization

- Ephemeral job clusters created on-demand per company
- Auto-termination after 10 minutes of inactivity
- Company-level cost attribution via tags
- Parallel processing reduces overall runtime

## Security

- Managed Identity authentication for Azure resources
- No hard-coded credentials in code
- Azure Key Vault integration for secrets
- Network isolation via private endpoints (production)

## Contributing

This is an enterprise data platform project. Follow the established patterns when making changes:

1. Update Terraform modules for infrastructure changes
2. Update documentation for any architecture changes
3. Test in development environment before production
4. Follow naming conventions for resources

## License

Internal use only - Company proprietary

## Support

For questions or issues, refer to the comprehensive documentation in `/docs` or contact the data platform team.
