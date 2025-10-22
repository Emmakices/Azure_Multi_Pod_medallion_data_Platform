# Setup Databricks Secrets - Quick Steps

## Step 1: Generate Databricks Token (2 minutes)

1. Open: https://adb-3370863217573312.12.azuredatabricks.net
2. Click your **username** (top-right) → **Settings**
3. Click **Developer** → **Access tokens** → **Manage**
4. Click **Generate new token**
5. Comment: `databricks-cli-access`
6. Lifetime: 90 days
7. Click **Generate**
8. **Copy the token** immediately (won't be shown again!)

## Step 2: Configure CLI (1 minute)

Open your terminal and run:

```bash
databricks configure --token
```

When prompted, enter:
- **Databricks Host**: `https://adb-3370863217573312.12.azuredatabricks.net`
- **Token**: [paste the token you copied]

## Step 3: Create Secret Scope

```bash
databricks secrets create-scope --scope storage-keys
```

## Step 4: Add Storage Key to Secrets

```bash
echo "YOUR_STORAGE_ACCOUNT_KEY_HERE" | databricks secrets put-secret --scope storage-keys --key datalake-key
```

## Step 5: Verify

```bash
databricks secrets list --scope storage-keys
```

Should show:
```
Key name: datalake-key
Last updated: [timestamp]
```

## Step 6: Update Your Notebook

Add this as **Cell 1** in your Databricks notebook:

```python
# COMMAND ----------
# Configure storage access using secrets (enterprise way)
storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")

spark.conf.set(
    "fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net",
    storage_key
)

print("Storage access configured securely via Databricks Secrets")
```

## Step 7: Run Your Notebook

Click **Run All** - should work now!

---

## If You Get Errors

**Error: "databricks command not found"**
```bash
pip install databricks-cli
```

**Error: "Invalid token"**
- Generate a new token (Step 1)
- Run `databricks configure --token` again

**Error: "Scope already exists"**
- That's okay! Skip to Step 4

**Error: "Secret not found" in notebook**
- Verify: `databricks secrets list --scope storage-keys`
- Make sure key name is exactly: `datalake-key`

---

## Why This is Better

COMPLETED: No hardcoded keys in code
COMPLETED: Keys are encrypted
COMPLETED: Can rotate keys without changing code
COMPLETED: Audit trail of secret access
COMPLETED: Enterprise security standard

## After This Works

You can use secrets in ALL your notebooks:
```python
storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")
```

Ready to proceed? Generate that token and run the commands!
