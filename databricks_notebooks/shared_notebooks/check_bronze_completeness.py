# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze Completeness Check
# MAGIC Checks if ALL required domain files are present in Bronze before processing

# COMMAND ----------

# Configure storage access
storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")
spark.conf.set(
    "fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net",
    storage_key
)

# COMMAND ----------

# Get parameters
dbutils.widgets.text("pod_id", "podA", "Pod ID")
dbutils.widgets.text("company", "finance", "Company")
dbutils.widgets.text("required_domains", '["hr", "payroll"]', "Required Domains")
dbutils.widgets.text("storage_account", "stdldevshared77b5h3", "Storage Account")

pod_id = dbutils.widgets.get("pod_id")
company = dbutils.widgets.get("company")
required_domains_str = dbutils.widgets.get("required_domains")
storage_account = dbutils.widgets.get("storage_account")

# Parse domains
import json
required_domains = json.loads(required_domains_str)

print(f"Checking Bronze completeness for: {pod_id}/{company}")
print(f"Required domains: {required_domains}")

# COMMAND ----------

# Check which domains exist in Bronze
bronze_base = f"abfss://bronze@{storage_account}.dfs.core.windows.net/{pod_id}/{company}/"
print(f"Bronze path: {bronze_base}")

missing_domains = []
found_domains = []

for domain in required_domains:
    domain_path = f"{bronze_base}{domain}/"
    try:
        files = dbutils.fs.ls(domain_path)
        # Check if there are any CSV or Parquet files
        data_files = [f for f in files if f.name.endswith('.csv') or f.name.endswith('.parquet')]

        if len(data_files) > 0:
            found_domains.append(domain)
            print(f"[OK] Found {domain}: {len(data_files)} file(s)")
        else:
            missing_domains.append(domain)
            print(f"[X] Missing {domain}: No data files")
    except Exception as e:
        missing_domains.append(domain)
        print(f"[X] Missing {domain}: Path doesn't exist")

# COMMAND ----------

# Return result
if len(missing_domains) > 0:
    # INCOMPLETE - return empty array so ForEach doesn't run
    result = []
    status = "INCOMPLETE"
    message = f"Waiting for {missing_domains}. Found {found_domains}."
    print(f"[PAUSED] {message}")
else:
    # COMPLETE - return domains array so ForEach processes them
    result = required_domains
    status = "COMPLETE"
    message = f"All {len(required_domains)} domains present. Ready to process."
    print(f"[OK] {message}")

# Return as JSON
output = {
    "status": status,
    "domains_to_process": result,
    "missing_domains": missing_domains,
    "found_domains": found_domains,
    "message": message
}

print(f"\nReturning to ADF: {json.dumps(output)}")
dbutils.notebook.exit(json.dumps(output))
