# Databricks Storage Authentication Setup

## Issue

Databricks clusters need authentication to access Azure Data Lake Storage Gen2.

Error:
```
Failure to initialize configuration for storage account stdldevshared77b5h3.dfs.core.windows.net
```

## Solution Options

### Option 1: Account Key in Cluster Configuration (Quick Setup)

**Best for**: Development and testing

1. Open Databricks workspace
2. Click **Compute** → Select your cluster
3. Click **Edit**
4. Click **Advanced Options** → **Spark** tab
5. Add this to **Spark Config**:

```
fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net YOUR_STORAGE_ACCOUNT_KEY_HERE
```

6. Click **Confirm** → Cluster will restart
7. Re-run your notebook

**Pros**: Simple, immediate
**Cons**: Key visible in cluster config

---

### Option 2: Databricks Secrets (Recommended for Production)

**Best for**: Production, enterprise security

**Step 1: Install Databricks CLI**

```bash
pip install databricks-cli
```

**Step 2: Configure Databricks CLI**

```bash
databricks configure --token
```

Enter:
- Host: https://adb-3370863217573312.12.azuredatabricks.net
- Token: (Generate from User Settings → Developer → Access Tokens)

**Step 3: Create Secret Scope**

```bash
databricks secrets create-scope --scope storage-keys
```

**Step 4: Add Storage Key to Scope**

```bash
databricks secrets put --scope storage-keys --key datalake-key
```

This opens an editor. Paste the storage key:
```
YOUR_STORAGE_ACCOUNT_KEY_HERE
```

Save and close.

**Step 5: Configure in Notebook**

Add this cell at the beginning of your notebooks:

```python
# COMMAND ----------
# Configure storage access using secrets
storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")

spark.conf.set(
    "fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net",
    storage_key
)

print("Storage access configured securely via secrets")
```

**Step 6: Verify**

```bash
databricks secrets list --scope storage-keys
```

Should show:
```
Key name: datalake-key
Last updated: [timestamp]
```

---

### Option 3: Service Principal (Enterprise Standard)

**Best for**: Production with fine-grained access control

**Step 1: Create Service Principal**

```bash
az ad sp create-for-rbac --name "databricks-storage-sp" --role "Storage Blob Data Contributor" --scopes /subscriptions/e97fa8c6-457d-495f-aa82-0d87e72f5842/resourceGroups/rg-platform-dev/providers/Microsoft.Storage/storageAccounts/stdldevshared77b5h3
```

Output:
```json
{
  "appId": "xxxx-xxxx-xxxx",
  "displayName": "databricks-storage-sp",
  "password": "xxxx-xxxx-xxxx",
  "tenant": "6c086ae8-f198-40e0-bfec-5a06bf6fcb41"
}
```

**Step 2: Store in Databricks Secrets**

```bash
databricks secrets put --scope storage-keys --key sp-client-id
# Paste appId

databricks secrets put --scope storage-keys --key sp-client-secret
# Paste password

databricks secrets put --scope storage-keys --key sp-tenant-id
# Paste tenant
```

**Step 3: Configure in Notebook**

```python
# COMMAND ----------
# Configure OAuth authentication
client_id = dbutils.secrets.get(scope="storage-keys", key="sp-client-id")
client_secret = dbutils.secrets.get(scope="storage-keys", key="sp-client-secret")
tenant_id = dbutils.secrets.get(scope="storage-keys", key="sp-tenant-id")

spark.conf.set(
    "fs.azure.account.auth.type.stdldevshared77b5h3.dfs.core.windows.net",
    "OAuth"
)
spark.conf.set(
    "fs.azure.account.oauth.provider.type.stdldevshared77b5h3.dfs.core.windows.net",
    "org.apache.hadoop.fs.azurebfs.oauth2.ClientCredsTokenProvider"
)
spark.conf.set(
    "fs.azure.account.oauth2.client.id.stdldevshared77b5h3.dfs.core.windows.net",
    client_id
)
spark.conf.set(
    "fs.azure.account.oauth2.client.secret.stdldevshared77b5h3.dfs.core.windows.net",
    client_secret
)
spark.conf.set(
    "fs.azure.account.oauth2.client.endpoint.stdldevshared77b5h3.dfs.core.windows.net",
    f"https://login.microsoftonline.com/{tenant_id}/oauth2/token"
)

print("OAuth authentication configured")
```

---

## Recommendation

**For now**: Use **Option 1** (Quick setup in cluster config)
**Before production**: Migrate to **Option 2** (Databricks Secrets)
**Enterprise production**: Use **Option 3** (Service Principal)

## Current Storage Key

```
Account: stdldevshared77b5h3
Key: YOUR_STORAGE_ACCOUNT_KEY_HERE
```

**Security Note**: This key will be rotated before production deployment.

## Test Authentication

After configuring, test with:

```python
# Test access
df = spark.range(5)
test_path = "abfss://gold@stdldevshared77b5h3.dfs.core.windows.net/test"
df.write.format("delta").mode("overwrite").save(test_path)
print("Storage authentication working!")
```

## Troubleshooting

**Error: "Invalid account key"**
- Regenerate key: `az storage account keys list --account-name stdldevshared77b5h3 --resource-group rg-platform-dev`

**Error: "Permission denied"**
- Check firewall: Storage account → Networking → Allow Databricks IP ranges

**Error: "Secret not found"**
- Verify scope: `databricks secrets list-scopes`
- Verify key: `databricks secrets list --scope storage-keys`
