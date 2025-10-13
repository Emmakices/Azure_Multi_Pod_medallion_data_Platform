"""
Script to upload and run the company configuration notebook in Databricks
Uses Databricks REST API
"""

import requests
import base64
import json
import time
import os

# Databricks configuration
DATABRICKS_HOST = "https://adb-3370863217573312.12.azuredatabricks.net"
DATABRICKS_TOKEN = "YOUR_DATABRICKS_TOKEN_HERE"

# Notebook paths
LOCAL_NOTEBOOK_PATH = r"C:\Users\User\Desktop\Delta_lake_project\databricks_notebooks\config\01_create_company_config_table.py"
DATABRICKS_NOTEBOOK_PATH = "/Shared/config/01_create_company_config_table"

# Headers for API requests
headers = {
    "Authorization": f"Bearer {DATABRICKS_TOKEN}",
    "Content-Type": "application/json"
}

def create_directory(path):
    """Create directory in Databricks workspace"""
    print(f"Creating directory: {path}")
    url = f"{DATABRICKS_HOST}/api/2.0/workspace/mkdirs"
    data = {"path": path}
    response = requests.post(url, headers=headers, json=data)
    if response.status_code == 200:
        print(f"[OK] Directory created: {path}")
        return True
    elif response.status_code == 409:
        print(f"[INFO]  Directory already exists: {path}")
        return True
    else:
        print(f"[ERROR] Failed to create directory: {response.status_code}")
        print(response.text)
        return False

def upload_notebook(local_path, databricks_path):
    """Upload notebook to Databricks workspace"""
    print(f"\nUploading notebook from: {local_path}")
    print(f"To Databricks path: {databricks_path}")

    # Read notebook content
    with open(local_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Encode content to base64
    content_base64 = base64.b64encode(content.encode('utf-8')).decode('utf-8')

    # Import notebook
    url = f"{DATABRICKS_HOST}/api/2.0/workspace/import"
    data = {
        "path": databricks_path,
        "format": "SOURCE",
        "language": "PYTHON",
        "content": content_base64,
        "overwrite": True
    }

    response = requests.post(url, headers=headers, json=data)
    if response.status_code == 200:
        print(f"[OK] Notebook uploaded successfully")
        return True
    else:
        print(f"[ERROR] Failed to upload notebook: {response.status_code}")
        print(response.text)
        return False

def list_clusters():
    """List available clusters"""
    print("\nListing available clusters...")
    url = f"{DATABRICKS_HOST}/api/2.0/clusters/list"
    response = requests.get(url, headers=headers)

    if response.status_code == 200:
        clusters = response.json().get('clusters', [])
        if not clusters:
            print("[INFO]  No running clusters found")
            return None

        print(f"Found {len(clusters)} cluster(s):")
        for cluster in clusters:
            state = cluster.get('state', 'UNKNOWN')
            cluster_id = cluster.get('cluster_id')
            cluster_name = cluster.get('cluster_name', 'Unnamed')
            print(f"  - {cluster_name} ({cluster_id}): {state}")

            # Return first running or pending cluster
            if state in ['RUNNING', 'PENDING']:
                return cluster_id

        return None
    else:
        print(f"[ERROR] Failed to list clusters: {response.status_code}")
        print(response.text)
        return None

def create_job_cluster():
    """Get job cluster specification for one-time run"""
    return {
        "spark_version": "13.3.x-scala2.12",
        "node_type_id": "Standard_D4s_v3",
        "num_workers": 1,
        "spark_env_vars": {
            "PYSPARK_PYTHON": "/databricks/python3/bin/python3"
        }
    }

def run_notebook(notebook_path, cluster_id=None):
    """Run notebook using Databricks Jobs API"""
    print(f"\nPreparing to run notebook: {notebook_path}")

    url = f"{DATABRICKS_HOST}/api/2.1/jobs/runs/submit"

    # Build run configuration
    run_config = {
        "run_name": "Company Config Table Creation",
        "notebook_task": {
            "notebook_path": notebook_path,
            "source": "WORKSPACE"
        },
        "timeout_seconds": 3600
    }

    # Use existing cluster or create job cluster
    if cluster_id:
        print(f"Using existing cluster: {cluster_id}")
        run_config["existing_cluster_id"] = cluster_id
    else:
        print("Creating ephemeral job cluster for this run")
        run_config["new_cluster"] = create_job_cluster()

    # Submit run
    response = requests.post(url, headers=headers, json=run_config)

    if response.status_code == 200:
        run_id = response.json().get('run_id')
        print(f"[OK] Notebook run submitted successfully")
        print(f"Run ID: {run_id}")
        return run_id
    else:
        print(f"[ERROR] Failed to submit notebook run: {response.status_code}")
        print(response.text)
        return None

def monitor_run(run_id):
    """Monitor notebook run status"""
    print(f"\nMonitoring run {run_id}...")
    url = f"{DATABRICKS_HOST}/api/2.1/jobs/runs/get"

    statuses_seen = set()

    while True:
        response = requests.get(url, headers=headers, params={"run_id": run_id})

        if response.status_code != 200:
            print(f"[ERROR] Failed to get run status: {response.status_code}")
            break

        run_info = response.json()
        state = run_info.get('state', {})
        life_cycle_state = state.get('life_cycle_state')
        result_state = state.get('result_state')
        state_message = state.get('state_message', '')

        # Print new status updates
        status_key = f"{life_cycle_state}:{result_state}"
        if status_key not in statuses_seen:
            statuses_seen.add(status_key)
            print(f"Status: {life_cycle_state}" + (f" - {result_state}" if result_state else ""))
            if state_message:
                print(f"  Message: {state_message}")

        # Check if run is complete
        if life_cycle_state in ['TERMINATED', 'SKIPPED', 'INTERNAL_ERROR']:
            print(f"\n{'='*80}")
            if result_state == 'SUCCESS':
                print("[OK] NOTEBOOK RUN COMPLETED SUCCESSFULLY")
                print(f"{'='*80}")

                # Get run output URL
                run_page_url = run_info.get('run_page_url')
                if run_page_url:
                    print(f"\n📊 View detailed results at:")
                    print(f"   {run_page_url}")

                return True
            else:
                print(f"[ERROR] NOTEBOOK RUN FAILED")
                print(f"Result state: {result_state}")
                print(f"Message: {state_message}")
                print(f"{'='*80}")
                return False

        # Wait before checking again
        time.sleep(10)

def main():
    """Main execution flow"""
    print("="*80)
    print("DATABRICKS NOTEBOOK UPLOAD AND EXECUTION")
    print("="*80)
    print(f"Host: {DATABRICKS_HOST}")
    print(f"Notebook: {LOCAL_NOTEBOOK_PATH}")
    print(f"Target: {DATABRICKS_NOTEBOOK_PATH}")
    print("="*80)

    # Step 1: Create directory structure
    directory = "/Shared/config"
    if not create_directory(directory):
        print("Failed to create directory. Exiting.")
        return False

    # Step 2: Upload notebook
    if not upload_notebook(LOCAL_NOTEBOOK_PATH, DATABRICKS_NOTEBOOK_PATH):
        print("Failed to upload notebook. Exiting.")
        return False

    # Step 3: Check for running clusters
    cluster_id = list_clusters()

    if not cluster_id:
        print("\n[INFO]  No running clusters found. Will create ephemeral job cluster.")
        print("   (This is cost-effective as cluster terminates after completion)")

    # Step 4: Run notebook
    run_id = run_notebook(DATABRICKS_NOTEBOOK_PATH, cluster_id)

    if not run_id:
        print("Failed to submit notebook run. Exiting.")
        return False

    # Step 5: Monitor execution
    success = monitor_run(run_id)

    if success:
        print("\n" + "="*80)
        print("NEXT STEPS")
        print("="*80)
        print("1. Verify the table was created:")
        print("   - Open Databricks SQL Editor")
        print("   - Run: SELECT * FROM company_config")
        print("\n2. Check the Gold layer storage:")
        print("   - Path: gold/config/companies")
        print("\n3. Proceed with ADF pipeline configuration")
        print("="*80)

    return success

if __name__ == "__main__":
    try:
        success = main()
        exit(0 if success else 1)
    except Exception as e:
        print(f"\n[ERROR] Unexpected error: {str(e)}")
        import traceback
        traceback.print_exc()
        exit(1)
