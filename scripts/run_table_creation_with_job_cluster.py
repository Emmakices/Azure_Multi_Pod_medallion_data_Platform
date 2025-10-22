"""
Run all table creation notebooks using job clusters (ephemeral)
"""
import requests
import time

host = 'https://adb-3370863217573312.12.azuredatabricks.net'
token = 'YOUR_DATABRICKS_TOKEN_HERE'

headers = {'Authorization': f'Bearer {token}'}

# Table creation notebooks
notebooks = [
    {
        'name': 'Pipeline Execution Log',
        'path': '/Shared/config/create_pipeline_execution_log_table',
        'table': 'pipeline_execution_log'
    },
    {
        'name': 'Data Lineage',
        'path': '/Shared/config/create_data_lineage_table',
        'table': 'data_lineage'
    },
    {
        'name': 'Data Quality Log',
        'path': '/Shared/config/create_data_quality_log_table',
        'table': 'data_quality_log'
    },
    {
        'name': 'SLA Monitoring',
        'path': '/Shared/config/create_sla_monitoring_table',
        'table': 'sla_monitoring'
    },
    {
        'name': 'Cost Tracking',
        'path': '/Shared/config/create_cost_tracking_table',
        'table': 'cost_tracking'
    },
    {
        'name': 'Alert Rules + Retry Policy + Archive Log',
        'path': '/Shared/config/create_alert_and_policy_tables',
        'table': 'alert_rules, retry_policy, archive_log'
    }
]

def submit_notebook_run(notebook_path, notebook_name):
    """Submit a notebook run with job cluster"""
    data = {
        "run_name": f"Create Table - {notebook_name}",
        "new_cluster": {
            "spark_version": "13.3.x-scala2.12",
            "node_type_id": "Standard_DS3_v2",
            "num_workers": 1,
            "spark_conf": {
                "spark.databricks.cluster.profile": "singleNode",
                "spark.master": "local[*]"
            },
            "custom_tags": {
                "ResourceClass": "SingleNode",
                "purpose": "table_creation"
            }
        },
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
        print(f"    [ERROR] Failed to submit run")
        print(f"    Status: {response.status_code}")
        print(f"    Response: {response.text}")
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

def wait_for_run(run_id, max_wait=900):
    """Wait for run to complete"""
    start_time = time.time()
    last_state = None

    while True:
        status_info = get_run_status(run_id)

        if status_info:
            state = status_info['state']['life_cycle_state']

            # Print state changes
            if state != last_state:
                elapsed = int(time.time() - start_time)
                print(f"    [{elapsed}s] State: {state}")
                last_state = state

            if state in ['TERMINATED', 'SKIPPED', 'INTERNAL_ERROR']:
                result_state = status_info['state'].get('result_state', 'UNKNOWN')

                elapsed = int(time.time() - start_time)

                if result_state == 'SUCCESS':
                    print(f"    [OK] Completed successfully in {elapsed}s")
                    return True
                else:
                    print(f"    [ERROR] Failed with state: {result_state}")
                    if 'state_message' in status_info['state']:
                        print(f"    Message: {status_info['state']['state_message']}")
                    return False

        if time.time() - start_time > max_wait:
            print(f"    [TIMEOUT] Exceeded {max_wait} seconds")
            return False

        time.sleep(10)

print("=" * 80)
print("CREATING DELTA TABLES WITH JOB CLUSTERS")
print("=" * 80)
print("\nThis will create ephemeral clusters for each notebook")
print("Clusters will auto-terminate after completion")
print()

success_count = 0
failed_count = 0
run_ids = []

for i, notebook in enumerate(notebooks, 1):
    print(f"\n[{i}/{len(notebooks)}] {notebook['name']}")
    print(f"  Notebook: {notebook['path']}")
    print(f"  Table(s): {notebook['table']}")

    # Submit run
    print(f"  Submitting job with new cluster...")
    run_id = submit_notebook_run(notebook['path'], notebook['name'])

    if run_id:
        print(f"    Run ID: {run_id}")
        run_ids.append(run_id)

        # Wait for completion
        if wait_for_run(run_id):
            success_count += 1
        else:
            failed_count += 1
    else:
        failed_count += 1

print("\n" + "=" * 80)
print("TABLE CREATION SUMMARY")
print("=" * 80)
print(f"Total notebooks: {len(notebooks)}")
print(f"Successfully created: {success_count}")
print(f"Failed: {failed_count}")
print(f"Run IDs: {run_ids}")
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
    print("\nAll logging infrastructure is ready!")
elif success_count > 0:
    print(f"\n[PARTIAL] {success_count} tables created, {failed_count} failed")
    print("Check errors above for details")
else:
    print("\n[ERROR] All table creations failed")
    print("You may need to run notebooks manually in Databricks UI")
