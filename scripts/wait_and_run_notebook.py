"""
Wait for cluster to be ready and then run the notebook
"""

import requests
import time

# Configuration
DATABRICKS_HOST = "https://adb-3370863217573312.12.azuredatabricks.net"
DATABRICKS_TOKEN = "YOUR_DATABRICKS_TOKEN_HERE"
CLUSTER_ID = "1006-181152-aduxl4ad"  # podA-interactive
NOTEBOOK_PATH = "/Shared/config/01_create_company_config_table"

headers = {
    "Authorization": f"Bearer {DATABRICKS_TOKEN}",
    "Content-Type": "application/json"
}

def check_cluster_status():
    """Check if cluster is running"""
    url = f"{DATABRICKS_HOST}/api/2.0/clusters/get"
    response = requests.get(url, headers=headers, params={"cluster_id": CLUSTER_ID})

    if response.status_code == 200:
        state = response.json().get('state', 'UNKNOWN')
        return state
    else:
        print(f"[ERROR] Failed to get cluster status: {response.status_code}")
        return None

def run_notebook_on_cluster():
    """Run notebook on the interactive cluster"""
    print(f"\n[OK] Cluster is RUNNING")
    print(f"Submitting notebook run on cluster: {CLUSTER_ID}")

    url = f"{DATABRICKS_HOST}/api/2.1/jobs/runs/submit"

    run_config = {
        "run_name": "Company Config Table Creation - Interactive Cluster",
        "existing_cluster_id": CLUSTER_ID,
        "notebook_task": {
            "notebook_path": NOTEBOOK_PATH,
            "source": "WORKSPACE"
        },
        "timeout_seconds": 3600
    }

    response = requests.post(url, headers=headers, json=run_config)

    if response.status_code == 200:
        run_id = response.json().get('run_id')
        print(f"[OK] Notebook run submitted successfully")
        print(f"Run ID: {run_id}")
        return run_id
    else:
        print(f"[ERROR] Failed to submit run: {response.status_code}")
        print(response.text)
        return None

def monitor_run(run_id):
    """Monitor notebook execution"""
    print(f"\nMonitoring run {run_id}...")
    url = f"{DATABRICKS_HOST}/api/2.1/jobs/runs/get"

    statuses_seen = set()
    start_time = time.time()

    while True:
        response = requests.get(url, headers=headers, params={"run_id": run_id})

        if response.status_code != 200:
            print(f"[ERROR] Failed to get run status: {response.status_code}")
            break

        run_info = response.json()
        state = run_info.get('state', {})
        life_cycle_state = state.get('life_cycle_state')
        result_state = state.get('result_state')

        # Print new status updates
        status_key = f"{life_cycle_state}:{result_state}"
        if status_key not in statuses_seen:
            statuses_seen.add(status_key)
            elapsed = int(time.time() - start_time)
            print(f"[{elapsed}s] Status: {life_cycle_state}" + (f" - {result_state}" if result_state else ""))

        # Check if complete
        if life_cycle_state in ['TERMINATED', 'SKIPPED', 'INTERNAL_ERROR']:
            print(f"\n{'='*80}")
            if result_state == 'SUCCESS':
                print("[OK] NOTEBOOK COMPLETED SUCCESSFULLY!")
                print(f"{'='*80}")
                print("\nCompany configuration table created:")
                print("  - Table: company_config")
                print("  - Location: gold/config/companies")
                print("  - Companies: 10 (across 3 pods)")
                print("\nView results at:")
                print(f"  {run_info.get('run_page_url', 'N/A')}")
                return True
            else:
                print(f"[ERROR] NOTEBOOK FAILED")
                print(f"Result: {result_state}")
                print(f"Message: {state.get('state_message', 'No message')}")
                print(f"{'='*80}")
                print(f"\nView error details at:")
                print(f"  {run_info.get('run_page_url', 'N/A')}")
                return False

        time.sleep(10)

def main():
    """Main execution"""
    print("="*80)
    print("WAITING FOR CLUSTER AND RUNNING NOTEBOOK")
    print("="*80)
    print(f"Cluster: podA-interactive ({CLUSTER_ID})")
    print(f"Notebook: {NOTEBOOK_PATH}")
    print("="*80)

    # Wait for cluster to be ready
    print("\nChecking cluster status...")
    check_count = 0
    max_checks = 60  # 10 minutes max wait

    while check_count < max_checks:
        status = check_cluster_status()
        check_count += 1
        elapsed = check_count * 10

        if status == 'RUNNING':
            break
        elif status == 'PENDING':
            print(f"[{elapsed}s] Cluster is starting... (PENDING)")
        elif status == 'RESTARTING':
            print(f"[{elapsed}s] Cluster is restarting...")
        elif status in ['TERMINATING', 'TERMINATED']:
            print(f"[ERROR] Cluster is {status}. Please start the cluster first.")
            return False
        else:
            print(f"[{elapsed}s] Cluster status: {status}")

        time.sleep(10)

    if check_count >= max_checks:
        print("[ERROR] Timeout waiting for cluster to start (10 minutes)")
        return False

    # Run notebook
    run_id = run_notebook_on_cluster()
    if not run_id:
        return False

    # Monitor execution
    success = monitor_run(run_id)

    if success:
        print("\n" + "="*80)
        print("NEXT STEPS")
        print("="*80)
        print("1. Verify table in Databricks SQL:")
        print("   SELECT * FROM company_config")
        print("\n2. Proceed with ADF pipeline configuration")
        print("="*80)

    return success

if __name__ == "__main__":
    try:
        success = main()
        exit(0 if success else 1)
    except KeyboardInterrupt:
        print("\n\n[INFO] Interrupted by user")
        exit(1)
    except Exception as e:
        print(f"\n[ERROR] Unexpected error: {str(e)}")
        import traceback
        traceback.print_exc()
        exit(1)
