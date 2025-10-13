# Step 3: Git Ignore and Terraform Backend Configuration

## Overview

In this step, we establish two critical components for a production-ready Terraform setup. First, we create a `.gitignore` file to prevent sensitive data from being committed to version control. Second, we configure a remote backend to store Terraform's state file securely in Azure Storage.

## Understanding Terraform State

Before diving into the configuration, it's important to understand what Terraform state is and why it matters.

When Terraform manages your infrastructure, it maintains a detailed inventory of all resources it has created in a state file. This file maps your configuration code to real-world Azure resources. The state file contains:

- Resource IDs and attributes
- Dependency relationships between resources
- Metadata about your infrastructure
- Sometimes sensitive data like connection strings or passwords

By default, Terraform stores this state locally in a file named `terraform.tfstate`. However, this approach has several problems:

**Security risks**: The state file can contain sensitive information in plain text
**Collaboration issues**: Team members working on the same infrastructure need access to the same state
**No locking mechanism**: Multiple people running Terraform simultaneously can corrupt the state
**No backup**: If you lose the local state file, Terraform loses track of your infrastructure

The solution is to use a remote backend that stores state in a shared, secure location with built-in locking and versioning.

## Part 1: Creating the .gitignore File

The `.gitignore` file tells Git which files and directories to exclude from version control. For Terraform projects, this is crucial because many generated files contain secrets or are too large to commit.

### Creating the File

Create a file named `.gitignore` in your `terraform/` directory with the following content:

```
# Local .terraform directories
**/.terraform/*

# .tfstate files
*.tfstate
*.tfstate.*

# Crash log files
crash.log
crash.*.log

# Exclude all .tfvars files, which are likely to contain sensitive data
*.tfvars
*.tfvars.json

# Ignore override files as they are usually used to override resources locally
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Ignore CLI configuration files
.terraformrc
terraform.rc

# Ignore Mac .DS_Store files
.DS_Store

# Ignore plan files
*tfplan*

# Ignore any .pem or .key files
*.pem
*.key
```

### Understanding Each Section

**`.terraform/` directories**: When you run `terraform init`, Terraform downloads provider plugins and modules into a `.terraform` directory. These files are large and can be regenerated, so there's no need to commit them.

**State files (`*.tfstate`)**: These contain your infrastructure's current state, including potentially sensitive data. Never commit state files to Git. They should only exist in your remote backend.

**Crash logs**: If Terraform encounters an error and crashes, it creates log files for debugging. These are temporary and specific to your machine.

**Variable files (`*.tfvars`)**: These files contain actual values for your variables, often including secrets like passwords, API keys, and connection strings. While you might commit a `terraform.tfvars.example` template, the actual `.tfvars` files should never be in version control.

**Override files**: These allow you to override specific resources locally for testing without modifying the main configuration. They're personal to each developer and shouldn't be shared.

**Plan files**: When you run `terraform plan -out=planfile`, Terraform saves the execution plan. These can contain sensitive data and should be treated as temporary.

**Certificate and key files**: Any `.pem` or `.key` files are credentials and must never be committed.

### What Should Be Committed

You should commit:
- All `.tf` files (main.tf, variables.tf, outputs.tf, etc.)
- Module definitions
- Documentation and README files
- Example variable files (like `terraform.tfvars.example`)

## Part 2: Configuring the Remote Backend

Now we'll configure Terraform to store its state in Azure Storage instead of locally.

### Why Azure Storage for State

Azure Storage provides several advantages as a Terraform backend:

**State locking**: Prevents multiple team members from running Terraform simultaneously and corrupting the state
**Encryption**: State is encrypted at rest
**Versioning**: You can enable blob versioning to maintain history of state changes
**Access control**: Use Azure RBAC to control who can read and modify state
**Availability**: Azure Storage offers high durability and availability

### Creating the Backend Configuration

Create a file named `backend.tf` in your `terraform/environments/dev/` directory with the following content:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-delta-lake-tfstate-dev"
    storage_account_name = "stdeltalaketfstatedev"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}
```

### Understanding the Configuration

Let's break down each parameter:

**resource_group_name**: The Azure resource group that contains your state storage account. We use `rg-delta-lake-tfstate-dev` to clearly indicate this resource group is specifically for Terraform state in the dev environment.

**storage_account_name**: The Azure Storage account where state will be stored. Storage account names must be globally unique, lowercase, and contain only letters and numbers. We use `stdeltalaketfstatedev` following the naming convention: `st` (storage), `deltalake` (project), `tfstate` (purpose), `dev` (environment).

**container_name**: The blob container within the storage account. We use `tfstate` as a standard name. Think of this as a folder within your storage account.

**key**: The name of the state file blob. We use `dev.terraform.tfstate` to clearly identify this as the development environment's state. If you later add staging or production environments, they would use `staging.terraform.tfstate` and `prod.terraform.tfstate` respectively.

### Backend Storage Naming Conventions

Notice the naming patterns we're following:

**Resource Group**: `rg-{project}-{purpose}-{environment}`
- `rg` = resource group prefix
- `delta-lake` = project name
- `tfstate` = indicates this holds Terraform state
- `dev` = environment

**Storage Account**: `st{project}{purpose}{environment}`
- `st` = storage account prefix
- `deltalake` = project name (no hyphens allowed)
- `tfstate` = purpose
- `dev` = environment
- No hyphens or special characters (storage account naming requirement)

These conventions make it immediately clear what each resource is for and which environment it belongs to.

## Creating the Backend Infrastructure

Before Terraform can use this backend, the Azure resources must exist. You have two options:

### Option 1: Create Backend Resources Manually (Recommended for First Time)

This approach uses Azure CLI to create the backend resources before running Terraform:

```bash
# Set variables for reusability
RESOURCE_GROUP_NAME="rg-delta-lake-tfstate-dev"
STORAGE_ACCOUNT_NAME="stdeltalaketfstatedev"
CONTAINER_NAME="tfstate"
LOCATION="eastus"

# Create resource group
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

# Create storage account
az storage account create \
  --resource-group $RESOURCE_GROUP_NAME \
  --name $STORAGE_ACCOUNT_NAME \
  --sku Standard_LRS \
  --encryption-services blob \
  --location $LOCATION

# Create blob container
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME
```

Let's understand each command:

**Setting variables**: We define variables to avoid repetition and make the commands easier to modify. In bash, you set variables without `$` and reference them with `$`.

**Creating the resource group**:
- `--name`: The resource group name matching your backend.tf configuration
- `--location`: The Azure region where resources will be created (choose one close to you or your users)

**Creating the storage account**:
- `--sku Standard_LRS`: Uses locally redundant storage (cheapest option, fine for state files)
- `--encryption-services blob`: Ensures blob encryption at rest
- Other options available: Standard_GRS (geo-redundant), Standard_ZRS (zone-redundant)

**Creating the container**:
- This creates the blob container where the actual state file will be stored
- No authentication flags needed because you're already authenticated via `az login`

### Option 2: Bootstrap with Local State First

Alternatively, you can create a separate Terraform configuration to provision the backend resources, running with local state initially:

```hcl
# In a separate directory: terraform/bootstrap/main.tf
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-delta-lake-tfstate-dev"
  location = "eastus"
}

resource "azurerm_storage_account" "tfstate" {
  name                     = "stdeltalaketfstatedev"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}
```

This approach is more infrastructure-as-code compliant but creates a chicken-and-egg situation where you have one Terraform project with local state managing the backend for your other projects.

## Verifying the Setup

After creating the backend resources, verify they exist:

```bash
# Check resource group
az group show --name rg-delta-lake-tfstate-dev

# Check storage account
az storage account show --name stdeltalaketfstatedev --resource-group rg-delta-lake-tfstate-dev

# List containers
az storage container list --account-name stdeltalaketfstatedev --output table
```

These commands confirm that:
1. The resource group exists and is in the correct location
2. The storage account is properly configured
3. The tfstate container has been created

## Security Considerations

### Access Control

By default, only users with appropriate Azure RBAC permissions can read or write the state file. For team environments, consider:

**Separate service principal for CI/CD**: Create a dedicated service principal for automated deployments with minimal required permissions.

**Role assignments**: Grant team members "Storage Blob Data Contributor" role on the storage account to read/write state.

**Network restrictions**: Consider enabling storage account firewall rules to restrict access to specific IP ranges or virtual networks.

### State File Encryption

The state file is encrypted at rest by Azure Storage by default. For additional security:

**Enable soft delete**: Protects against accidental deletion
```bash
az storage account blob-service-properties update \
  --account-name stdeltalaketfstatedev \
  --enable-delete-retention true \
  --delete-retention-days 7
```

**Enable versioning**: Maintains history of state changes
```bash
az storage account blob-service-properties update \
  --account-name stdeltalaketfstatedev \
  --enable-versioning true
```

## State Locking

Azure Storage automatically handles state locking using blob leases. When one user or process is modifying infrastructure, Terraform acquires a lease on the state blob. Other attempts to run Terraform will wait or fail until the lease is released.

If a process crashes while holding the lock, you may need to manually break the lease:

```bash
az storage blob lease break \
  --blob-name dev.terraform.tfstate \
  --container-name tfstate \
  --account-name stdeltalaketfstatedev
```

Only do this if you're certain no Terraform operations are actually running.

## What's Next

With the backend configured and .gitignore in place, you're ready to:

1. Initialize Terraform in your dev environment
2. Create provider configuration for Azure
3. Start building your infrastructure modules
4. Deploy your first resources

The backend configuration will be used when you run `terraform init` in the next steps. Terraform will automatically create the state file in Azure Storage the first time you apply changes.

## Command Reference

Here's a quick reference of all commands used in this step:

```bash
# Create backend infrastructure
RESOURCE_GROUP_NAME="rg-delta-lake-tfstate-dev"
STORAGE_ACCOUNT_NAME="stdeltalaketfstatedev"
CONTAINER_NAME="tfstate"
LOCATION="eastus"

az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

az storage account create \
  --resource-group $RESOURCE_GROUP_NAME \
  --name $STORAGE_ACCOUNT_NAME \
  --sku Standard_LRS \
  --encryption-services blob \
  --location $LOCATION

az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT_NAME

# Verify setup
az group show --name rg-delta-lake-tfstate-dev
az storage account show --name stdeltalaketfstatedev --resource-group rg-delta-lake-tfstate-dev
az storage container list --account-name stdeltalaketfstatedev --output table

# Enable security features
az storage account blob-service-properties update \
  --account-name stdeltalaketfstatedev \
  --enable-delete-retention true \
  --delete-retention-days 7

az storage account blob-service-properties update \
  --account-name stdeltalaketfstatedev \
  --enable-versioning true

# Break state lock (only if needed)
az storage blob lease break \
  --blob-name dev.terraform.tfstate \
  --container-name tfstate \
  --account-name stdeltalaketfstatedev
```

## Files Created in This Step

```
terraform/
├── .gitignore
└── environments/
    └── dev/
        └── backend.tf
```

## Key Takeaways

- The .gitignore file prevents sensitive Terraform files from being committed to version control
- Terraform state files contain sensitive data and should never be stored in Git
- Remote backends provide state locking, encryption, and team collaboration capabilities
- Azure Storage is an excellent choice for Terraform state with built-in locking via blob leases
- Backend infrastructure must exist before Terraform can use it for state storage
- Follow consistent naming conventions to keep your Azure resources organized
- Enable versioning and soft delete for additional protection of your state files
- State locking prevents multiple users from corrupting infrastructure during concurrent changes
