"""
Run all table creation notebooks to create Delta tables
"""
import requests
import time
import json

host = 'https://adb-3370863217573312.12.azuredatabricks.net'
token = 'YOUR_DATABRICKS_TOKEN_HERE'

headers = {'Authorization': f'Bearer {token}'}

# Table creation notebooks to run
notebooks = [
    {
        'name': 'Pipeline Execution Log',
        'path': '/Shared/config/create_pipeline_execution_log_table',
        'table': 'gold/config/pipeline_execution_log'
    },
    {
        'name': 'Data Lineage',
        'path': '/Shared/config/create_data_lineage_table',
        'table': 'gold/config/data_lineage'
    },
    {
        'name': 'Data Quality Log',
        'path': '/Shared/config/create_data_quality_log_table',
        'table': 'gold/config/data_quality_log'
    },
    {
        'name': 'SLA Monitoring',
        'path': '/Shared/config/create_sla_monitoring_table',
        'table': 'gold/config/sla_monitoring'
    },
    {
        'name': 'Cost Tracking',
        'path': '/Shared/config/create_cost_tracking_table',
        'table': 'gold/config/cost_tracking'
    },
    {
        'name': 'Alert Rules, Retry Policy, Archive Log',
        'path': '/Shared/config/create_alert_and_policy_tables',
        'table': 'gold/config/alert_rules, retry_policy, archive_log'
    }
]

def submit_notebook_run(notebook_path):
    """Submit a notebook run"""
    data = {
        "run_name": f"Create Table - {notebook_path.split('/')[-1]}",
        "existing_cluster_id": "1101-165405-aj88qz9l",  # Your existing cluster
        "notebook_task": {
            "notebook_path": notebook_path,
            "base_parameters": {}
        },
        "timeout_seconds": 3600
    }

    response = requests.post(
        f'{host}/api/2.0/jobs/runs/submit',
        headers=headers,
        json=data
    )

    if response.status_code == 200:
        return response.json()['run_id']
    else:
        print(f"[ERROR] Failed to submit run")
        print(f"Status: {response.status_code}")
        print(f"Response: {response.text}")
        return None

def get_run_status(run_id):
    """Get status of a run"""
    response = requests.get(
        f'{host}/api/2.0/jobs/runs/get',
        headers=headers,
        params={'run_id': run_id}
    )

    if response.status_code == 200:
        return response.json()
    else:
        return None

def wait_for_run(run_id, notebook_name, max_wait=600):
    """Wait for run to complete"""
    print(f"  Waiting for completion...", end='', flush=True)

    start_time = time.time()
    while True:
        status_info = get_run_status(run_id)

        if status_info:
            state = status_info['state']['life_cycle_state']

            if state in ['TERMINATED', 'SKIPPED', 'INTERNAL_ERROR']:
                result_state = status_info['state'].get('result_state', 'UNKNOWN')

                elapsed = int(time.time() - start_time)
                print(f" ({elapsed}s)")

                if result_state == 'SUCCESS':
                    print(f"  [OK] Table created successfully!")
                    return True
                else:
                    print(f"  [ERROR] Run failed with state: {result_state}")
                    if 'state_message' in status_info['state']:
                        print(f"  Message: {status_info['state']['state_message']}")
                    return False

        if time.time() - start_time > max_wait:
            print(f"\n  [TIMEOUT] Run exceeded {max_wait} seconds")
            return False

        time.sleep(5)

print("=" * 80)
print("CREATING DELTA TABLES IN gold/config/")
print("=" * 80)

success_count = 0
failed_count = 0

for notebook in notebooks:
    print(f"\n{notebook['name']}")
    print(f"  Notebook: {notebook['path']}")
    print(f"  Table(s): {notebook['table']}")

    # Submit run
    print(f"  Submitting notebook run...", end='', flush=True)
    run_id = submit_notebook_run(notebook['path'])

    if run_id:
        print(f" Run ID: {run_id}")

        # Wait for completion
        if wait_for_run(run_id, notebook['name']):
            success_count += 1
        else:
            failed_count += 1
    else:
        print(f"  [ERROR] Failed to submit run")
        failed_count += 1

print("\n" + "=" * 80)
print("TABLE CREATION SUMMARY")
print("=" * 80)
print(f"Total notebooks: {len(notebooks)}")
print(f"Successfully created: {success_count}")
print(f"Failed: {failed_count}")
print("=" * 80)

if success_count == len(notebooks):
    print("\n[OK] All Delta tables created successfully!")
    print("\nTables created in gold/config/:")
    print("  - pipeline_execution_log")
    print("  - data_lineage")
    print("  - data_quality_log")
    print("  - sla_monitoring")
    print("  - cost_tracking")
    print("  - alert_rules")
    print("  - retry_policy")
    print("  - archive_log")
    print("\nNext: Integrate logging into ADF pipeline")
else:
    print("\n[WARNING] Some table creations failed. Check errors above.")
