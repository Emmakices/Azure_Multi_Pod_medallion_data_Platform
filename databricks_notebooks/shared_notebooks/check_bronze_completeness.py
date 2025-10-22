# Databricks notebook source
# MAGIC %md
# MAGIC # Check Bronze Completeness
# MAGIC **Purpose**: Check if ALL required domain files are present in Bronze before processing
# MAGIC **Returns**: COMPLETE or INCOMPLETE status

# COMMAND ----------

# Configure storage access using Databricks Secrets
storage_key = dbutils.secrets.get(scope="storage-keys", key="datalake-key")
spark.conf.set(
    "fs.azure.account.key.stdldevshared77b5h3.dfs.core.windows.net",
    storage_key
)

# COMMAND ----------

# Get parameters from ADF
dbutils.widgets.text("pod_id", "podA", "Pod ID")
dbutils.widgets.text("company", "finance", "Company")
dbutils.widgets.text("required_domains", '["hr", "payroll"]', "Required Domains (JSON array)")
dbutils.widgets.text("storage_account", "stdldevshared77b5h3", "Storage Account")

pod_id = dbutils.widgets.get("pod_id")
company = dbutils.widgets.get("company")
required_domains_str = dbutils.widgets.get("required_domains")
storage_account = dbutils.widgets.get("storage_account")

# Parse domains
import json
required_domains = json.loads(required_domains_str)

print(f"Checking completeness for: {pod_id}/{company}")
print(f"Required domains: {required_domains}")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Check Bronze for All Required Domains

# COMMAND ----------

bronze_base = f"abfss://bronze@{storage_account}.dfs.core.windows.net/{pod_id}/{company}/"
print(f"Checking Bronze: {bronze_base}")

missing_domains = []
found_domains = []

for domain in required_domains:
    try:
        # List all files/folders in Bronze for this company
        items = dbutils.fs.ls(bronze_base)

        # Check if domain exists as:
        # 1. A folder (e.g., hr/)
        # 2. Files with domain prefix (e.g., hr_employees.csv)
        domain_present = False

        for item in items:
            item_name = item.name.lower()
            # Check for folder match (e.g., "hr/")
            if item_name == f"{domain}/" or item_name.startswith(f"{domain}/"):
                domain_present = True
                break
            # Check for file match (e.g., "hr_employees.csv")
            if item_name.startswith(f"{domain}_"):
                domain_present = True
                break

        if domain_present:
            found_domains.append(domain)
            print(f"[DONE] Found {domain} in Bronze")
        else:
            missing_domains.append(domain)
            print(f"[WARNING] Missing {domain} in Bronze")

    except Exception as e:
        missing_domains.append(domain)
        print(f"[ERROR] Missing {domain} in Bronze: {str(e)}")

print(f"\nSummary: {len(found_domains)}/{len(required_domains)} domains present")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Return Result

# COMMAND ----------

if len(missing_domains) > 0:
    # INCOMPLETE - return empty array so ForEach doesn't run
    domains_to_process = []
    result = {
        "status": "INCOMPLETE",
        "domains_to_process": domains_to_process,
        "missing_domains": missing_domains,
        "found_domains": found_domains,
        "message": f"Waiting for {len(missing_domains)} domain(s): {missing_domains}"
    }
    print(f"\n[PAUSED] INCOMPLETE: {result['message']}")
    print(f"[INFO] Files will WAIT in Bronze until all domains arrive")
else:
    # COMPLETE - return domains array so ForEach processes them
    domains_to_process = required_domains
    result = {
        "status": "COMPLETE",
        "domains_to_process": domains_to_process,
        "found_domains": found_domains,
        "missing_domains": [],
        "message": f"All {len(required_domains)} domains present. Ready to process."
    }
    print(f"\n[DONE] COMPLETE: {result['message']}")
    print(f"[INFO] Will process domains: {domains_to_process}")

# Return JSON result
print(f"\nReturning: {json.dumps(result, indent=2)}")
dbutils.notebook.exit(json.dumps(result))
