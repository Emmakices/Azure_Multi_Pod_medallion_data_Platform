# Step 1: Azure CLI Authentication

## Overview

This guide walks you through the process of authenticating your local development environment with Azure. Authentication is the first critical step before you can provision any Azure resources for your Delta Lake project.

## Prerequisites

Before you begin, make sure you have:
- An active Azure account with a valid subscription
- Azure CLI installed on your machine

## Verifying Azure CLI Installation

First, check that Azure CLI is properly installed on your system:

```bash
az --version
```

This command displays the installed version of Azure CLI along with its dependencies. In our case, we verified that Azure CLI version 2.71.0 was installed and ready to use.

## Understanding Azure Authentication

Azure CLI supports multiple authentication methods. For development purposes, the most common approaches are:

1. **Interactive Browser Login** - Opens your default browser for authentication
2. **Device Code Flow** - Provides a code you enter on a separate device or browser
3. **Service Principal** - Uses application credentials (typically for automation)

For this project, we used the device code flow because it's more reliable when working in environments where browser pop-ups might be blocked or when you need more control over the authentication process.

## Authentication Process

### Step 1: Initiate Device Code Login

Run the following command to start the authentication flow:

```bash
az login --use-device-code
```

This command generates output similar to:

```
To sign in, use a web browser to open the page https://microsoft.com/devicelogin
and enter the code BCLS4E66K to authenticate.
```

### Step 2: Complete Browser Authentication

1. Open your web browser and navigate to: https://microsoft.com/devicelogin
2. Enter the device code displayed in your terminal (in our example: BCLS4E66K)
3. Sign in with your Azure credentials when prompted
4. Accept the permissions request to allow Azure CLI to access your account

The device code is time-sensitive and typically expires after 15 minutes, so complete this step promptly.

### Step 3: Verify Authentication

After completing the browser authentication, verify that you're successfully logged in:

```bash
az account show
```

This command displays your current Azure subscription details in JSON format. A successful authentication will show:

```json
{
  "environmentName": "AzureCloud",
  "homeTenantId": "6c086ae8-f198-40e0-bfec-5a06bf6fcb41",
  "id": "e97fa8c6-457d-495f-aa82-0d87e72f5842",
  "isDefault": true,
  "name": "Azure subscription 1",
  "state": "Enabled",
  "tenantDefaultDomain": "ikechukwuemmanuelihetu82gma.onmicrosoft.com",
  "tenantDisplayName": "Default Directory",
  "tenantId": "6c086ae8-f198-40e0-bfec-5a06bf6fcb41",
  "user": {
    "name": "ikechukwuemmanuelihetu82@gmail.com",
    "type": "user"
  }
}
```

## Understanding the Authentication Response

Let's break down what each field means:

- **environmentName**: The Azure cloud environment you're connected to (AzureCloud is the public cloud)
- **id**: Your unique subscription ID - you'll use this frequently when provisioning resources
- **name**: The display name of your subscription
- **state**: Shows whether your subscription is active (Enabled) or suspended
- **tenantId**: Your Azure Active Directory tenant identifier
- **user.name**: The account you authenticated with

## Common Issues and Solutions

### No Subscriptions Found

If you see an error like "No subscriptions found", it means:
- Your Azure account exists but has no active subscription
- You need to create a free trial or paid subscription at https://azure.microsoft.com/free/

### Authentication Timeout

If the device code authentication times out:
- Request a new device code by running `az login --use-device-code` again
- Complete the browser authentication more quickly
- Check your internet connection

### Multiple Subscriptions

If you have multiple subscriptions and want to switch between them:

```bash
# List all subscriptions
az account list --output table

# Set a specific subscription as active
az account set --subscription "subscription-id-or-name"
```

## What's Next

Now that you're authenticated with Azure, you can begin provisioning resources for your Delta Lake project. The typical next steps include:

1. Creating a resource group to organize your Azure resources
2. Setting up Azure Storage Account for Delta Lake table storage
3. Configuring compute resources (Azure Databricks, VMs, or Azure Synapse)
4. Setting up networking and security configurations

Your authentication session will persist until you explicitly log out using `az logout` or until the authentication token expires (typically after several hours of inactivity).

## Command Reference

Here's a quick reference of all commands used in this step:

```bash
# Check Azure CLI version
az --version

# Login with device code
az login --use-device-code

# View current account details
az account show

# List all subscriptions
az account list --output table

# Switch subscription
az account set --subscription "subscription-id"

# Logout
az logout
```

## Key Takeaways

- Azure CLI authentication is required before provisioning any cloud resources
- Device code flow provides a reliable authentication method for development environments
- Your subscription ID and tenant ID are important identifiers you'll use throughout the project
- Authentication sessions are temporary and will eventually require re-authentication
- Always verify your authentication status before running resource provisioning commands
