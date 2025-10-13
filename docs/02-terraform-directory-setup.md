# Step 2: Terraform Directory Structure Setup

## Overview

This step establishes the foundational directory structure for managing your Delta Lake infrastructure as code using Terraform. A well-organized Terraform project separates concerns between reusable modules and environment-specific configurations, making your infrastructure easier to maintain and scale.

## Understanding the Directory Structure

Before creating the directories, it's important to understand why we organize Terraform projects this way:

### Modules vs Environments

**Modules** are reusable components that define specific pieces of infrastructure. Think of them as building blocks. Each module encapsulates the configuration for a particular Azure service or logical grouping of resources. You write a module once and can use it across multiple environments with different parameters.

**Environments** represent different deployment stages of your infrastructure, such as development, staging, and production. Each environment folder contains the specific configuration that calls your modules with environment-appropriate values.

This separation provides several benefits:
- Reusability: Write infrastructure code once, deploy it multiple times
- Consistency: The same module logic applies across all environments
- Maintainability: Updates to a module automatically propagate to all environments using it
- Environment isolation: Each environment has its own state and configuration

## The Directory Layout

For this Delta Lake project, we're setting up the following structure:

```
terraform/
├── environments/
│   └── dev/
└── modules/
    ├── data-lake/
    ├── data-factory/
    ├── databricks/
    └── log-analytics/
```

### Environments Directory

The `environments` folder contains subdirectories for each deployment environment. Currently, we're starting with a `dev` environment for development and testing purposes. As your project matures, you would typically add `staging` and `prod` directories following the same pattern.

Each environment directory will eventually contain:
- `main.tf`: The primary configuration file that calls your modules
- `variables.tf`: Environment-specific variable definitions
- `terraform.tfvars`: Actual values for your variables (often excluded from version control)
- `outputs.tf`: Values to display after Terraform applies changes
- `provider.tf`: Azure provider configuration with authentication details

### Modules Directory

The `modules` folder houses our reusable infrastructure components. Each subdirectory represents a distinct piece of the Delta Lake architecture:

**data-lake**: Contains the Terraform configuration for Azure Data Lake Storage Gen2. This module will define storage accounts, containers, access policies, and lifecycle management rules for your Delta Lake tables.

**data-factory**: Defines Azure Data Factory resources for orchestrating data pipelines. This includes linked services, datasets, pipelines, and triggers that move and transform data into your Delta Lake.

**databricks**: Configures Azure Databricks workspace and associated resources. Databricks will serve as your compute engine for reading, writing, and processing Delta Lake tables using Apache Spark.

**log-analytics**: Sets up Azure Log Analytics workspace for monitoring and diagnostics. This module will collect metrics and logs from all your other services, providing centralized observability for your Delta Lake platform.

## Creating the Directory Structure

Now let's create this structure using a single command. We'll use the `-p` flag which creates parent directories as needed and doesn't throw errors if directories already exist.

Run the following command from your project root directory:

```bash
mkdir -p terraform/environments/dev && mkdir -p terraform/modules/data-lake && mkdir -p terraform/modules/data-factory && mkdir -p terraform/modules/databricks && mkdir -p terraform/modules/log-analytics
```

This command does several things in sequence:
1. Creates the `terraform/environments/dev` directory path
2. Creates the `terraform/modules/data-lake` directory path
3. Creates the `terraform/modules/data-factory` directory path
4. Creates the `terraform/modules/databricks` directory path
5. Creates the `terraform/modules/log-analytics` directory path

The `&&` operator ensures that each directory creation completes successfully before moving to the next one.

## Verifying the Structure

After creating the directories, verify that everything was set up correctly:

```bash
ls -R terraform
```

The `-R` flag recursively lists all directories and their contents. You should see output similar to:

```
terraform:
environments
modules

terraform/environments:
dev

terraform/environments/dev:

terraform/modules:
databricks
data-factory
data-lake
log-analytics

terraform/modules/databricks:

terraform/modules/data-factory:

terraform/modules/data-lake:

terraform/modules/log-analytics:
```

Notice that all directories are currently empty. This is expected. We'll populate them with Terraform configuration files in subsequent steps.

## Alternative Commands for Windows

If you're working on Windows without a Unix-like shell, you can use these alternatives:

### Using Windows Command Prompt

```cmd
mkdir terraform\environments\dev
mkdir terraform\modules\data-lake
mkdir terraform\modules\data-factory
mkdir terraform\modules\databricks
mkdir terraform\modules\log-analytics
```

### Using PowerShell

```powershell
New-Item -ItemType Directory -Path terraform\environments\dev -Force
New-Item -ItemType Directory -Path terraform\modules\data-lake -Force
New-Item -ItemType Directory -Path terraform\modules\data-factory -Force
New-Item -ItemType Directory -Path terraform\modules\databricks -Force
New-Item -ItemType Directory -Path terraform\modules\log-analytics -Force
```

The `-Force` parameter in PowerShell creates parent directories automatically and doesn't error if the directory already exists.

## Best Practices for Terraform Project Structure

### Naming Conventions

Use lowercase with hyphens for directory names. This maintains consistency across operating systems and avoids issues with case-sensitive file systems.

### Version Control Considerations

When you later initialize Git for this project, you'll want to add certain Terraform files to `.gitignore`:
- `*.tfstate` and `*.tfstate.backup`: State files contain sensitive information
- `*.tfvars`: Variable files often contain secrets and credentials
- `.terraform/`: Local plugins and modules cache
- `*.lock.hcl`: Provider version locks (some teams commit this, others don't)

### Future Expansion

As your project grows, you might add additional directories:
- `terraform/environments/staging`: Staging environment configuration
- `terraform/environments/prod`: Production environment configuration
- `terraform/modules/networking`: Virtual network and security group configurations
- `terraform/modules/key-vault`: Azure Key Vault for secrets management
- `terraform/shared`: Shared resources used across all environments

## What Each Module Will Contain

In the next steps, we'll populate each module with these standard Terraform files:

**main.tf**: The primary resource definitions for the module
**variables.tf**: Input variables that make the module configurable
**outputs.tf**: Values that the module exposes to other configurations
**README.md**: Documentation explaining how to use the module

## What's Next

With the directory structure in place, the next steps involve:

1. Installing Terraform if not already available
2. Creating the provider configuration for Azure
3. Writing the Terraform modules for each component
4. Configuring the dev environment to use these modules
5. Initializing Terraform and validating the configuration

This structure provides a solid foundation for managing your entire Delta Lake infrastructure through code, enabling version control, peer review, and automated deployments.

## Command Reference

Here's a quick reference of commands used in this step:

```bash
# Create directory structure (Unix/Linux/Mac)
mkdir -p terraform/environments/dev && mkdir -p terraform/modules/data-lake && mkdir -p terraform/modules/data-factory && mkdir -p terraform/modules/databricks && mkdir -p terraform/modules/log-analytics

# Verify structure
ls -R terraform

# List only directories (Unix/Linux/Mac)
tree terraform

# Windows Command Prompt alternative
dir /S terraform

# Windows PowerShell alternative
Get-ChildItem -Recurse terraform
```

## Key Takeaways

- Terraform projects separate reusable modules from environment-specific configurations
- Modules represent logical infrastructure components that can be used across environments
- Environment directories contain the actual deployment configurations
- This structure promotes code reusability, consistency, and maintainability
- All directories are currently empty and will be populated in subsequent steps
- The same organizational pattern can scale from development to production environments
