#!/bin/bash
# Setup Databricks Secrets for Storage Authentication
# Run this after generating Databricks personal access token

echo "=========================================="
echo "Databricks Secrets Setup - Enterprise Way"
echo "=========================================="
echo ""

# Step 1: Verify Databricks CLI is installed
echo "Step 1: Checking Databricks CLI..."
if ! command -v databricks &> /dev/null; then
    echo "Installing Databricks CLI..."
    pip install databricks-cli
fi
echo "[OK] Databricks CLI ready"
echo ""

# Step 2: Instructions for token generation
echo "Step 2: Generate Personal Access Token"
echo "----------------------------------------"
echo "1. Open: https://adb-3370863217573312.12.azuredatabricks.net"
echo "2. Click your username (top-right) → Settings"
echo "3. Click 'Developer' → 'Access tokens' → 'Manage'"
echo "4. Click 'Generate new token'"
echo "5. Comment: 'databricks-cli-access'"
echo "6. Click 'Generate' and COPY the token"
echo ""
read -p "Press Enter after you've generated and copied the token..."
echo ""

# Step 3: Configure Databricks CLI
echo "Step 3: Configuring Databricks CLI"
echo "-----------------------------------"
echo "You'll be prompted for:"
echo "  Host: https://adb-3370863217573312.12.azuredatabricks.net"
echo "  Token: [paste your token]"
echo ""
databricks configure --token
echo ""

# Step 4: Test connection
echo "Step 4: Testing connection..."
if databricks workspace ls / &> /dev/null; then
    echo "[OK] Successfully connected to Databricks"
else
    echo "[ERROR] Connection failed. Check your token and try again."
    exit 1
fi
echo ""

# Step 5: Create secret scope
echo "Step 5: Creating secret scope 'storage-keys'..."
if databricks secrets create-scope --scope storage-keys 2>&1 | grep -q "already exists"; then
    echo "[INFO] Secret scope 'storage-keys' already exists"
else
    echo "[OK] Secret scope 'storage-keys' created"
fi
echo ""

# Step 6: Store storage account key
echo "Step 6: Storing storage account key..."
STORAGE_KEY="YOUR_STORAGE_ACCOUNT_KEY_HERE"

echo "$STORAGE_KEY" | databricks secrets put --scope storage-keys --key datalake-key --string-value "$STORAGE_KEY"
echo "[OK] Storage key stored in secret scope"
echo ""

# Step 7: Verify secret was created
echo "Step 7: Verifying secrets..."
echo "Secrets in 'storage-keys' scope:"
databricks secrets list --scope storage-keys
echo ""

echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Add this cell to the beginning of your notebooks:"
echo ""
echo "# COMMAND ----------"
echo "# Configure storage access using secrets"
echo "storage_key = dbutils.secrets.get(scope=\"storage-keys\", key=\"datalake-key\")"
echo ""
echo "spark.conf.set("
echo "    \"fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net\","
echo "    storage_key"
echo ")"
echo "print(\"Storage access configured securely\")"
echo ""
echo "2. Re-run your notebook"
echo ""
