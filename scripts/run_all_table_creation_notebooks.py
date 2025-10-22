"""
Run all table creation notebooks in Databricks to create Delta tables
Creates 9 enterprise tables in gold/config/ location
"""
import requests
import time
import json

# Databricks configuration
host = 'https://adb-3370863217573312.12.azuredatabricks.net'
token = 'YOUR_DATABRICKS_TOKEN_HERE'

headers = {'Authorization': f'Bearer {token}'}

# Table creation notebooks in execution order
notebooks = [
    {
        'path': '/Shared/config/create_company_config_table',
        'table': 'company_config',
        'description': 'Company configuration registry (10 companies)'
    },
    {
        'path': '/Shared/config/create_pipeline_execution_log_table',
        'table': 'pipeline_execution_log',
        'description': 'Pipeline execution tracking'
    },
    {
        'path': '/Shared/config/create_data_lineage_table',
        'table': 'data_lineage',
        'description': 'Data lineage from source to gold'
    },
    {
        'path': '/Shared/config/create_data_quality_log_table',
        'table': 'data_quality_log',
        'description': 'Data quality check results'
    },
    {
        'path': '/Shared/config/create_sla_monitoring_table',
        'table': 'sla_monitoring',
        'description': 'SLA compliance tracking'
    },
    {
        'path': '/Shared/config/create_cost_tracking_table',
        'table': 'cost_tracking',
        'description': 'Cost attribution and chargeback'
    },
    {
        'path': '/Shared/config/create_alert_and_policy_tables',
        'table': 'alert_rules, retry_policy, archive_log',
        'description': 'Alert rules, retry policy, and archive log (3 tables)'
    }
]

print("=" * 80)
print("CREATING ENTERPRISE DELTA TABLES IN DATABRICKS")
print("=" * 80)
print(f"Host: {host}")
print(f"Total notebooks to run: {len(notebooks)}")
print("=" * 80)

results = []

for i, notebook in enumerate(notebooks, 1):
    notebook_path = notebook['path']
    table_name = notebook['table']
    description = notebook['description']

    print(f"\n[{i}/{len(notebooks)}] Running: {notebook_path}")
    print(f"         Creates: {table_name}")
    print(f"         Purpose: {description}")

    try:
        # Submit notebook job with ephemeral cluster
        job_config = {
            "run_name": f"Create_{table_name}_table",
            "notebook_task": {
                "notebook_path": notebook_path,
                "base_parameters": {}
            },
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
                    "purpose": "table_creation",
                    "owner": "ihetuemmanuel@gmail.com"
                }
            },
            "timeout_seconds": 3600
        }

        # Submit job
        response = requests.post(
            f'{host}/api/2.1/jobs/runs/submit',
            headers=headers,
            json=job_config
        )

        if response.status_code != 200:
            print(f"         [ERROR] Failed to submit job")
            print(f"         Status: {response.status_code}")
            print(f"         Response: {response.text}")
            results.append({
                'notebook': notebook_path,
                'status': 'SUBMIT_FAILED',
                'error': response.text
            })
            continue

        run_id = response.json()['run_id']
        print(f"         Job submitted: run_id={run_id}")
        print(f"         Waiting for completion...")

        # Poll for completion
        max_wait_seconds = 600  # 10 minutes
        poll_interval = 10  # 10 seconds
        elapsed = 0

        while elapsed < max_wait_seconds:
            # Get run status
            status_response = requests.get(
                f'{host}/api/2.1/jobs/runs/get',
                headers=headers,
                params={'run_id': run_id}
            )

            if status_response.status_code != 200:
                print(f"         [ERROR] Failed to get job status")
                break

            run_data = status_response.json()
            life_cycle_state = run_data.get('state', {}).get('life_cycle_state')
            result_state = run_data.get('state', {}).get('result_state')

            if life_cycle_state in ['TERMINATED', 'SKIPPED', 'INTERNAL_ERROR']:
                if result_state == 'SUCCESS':
                    print(f"         [OK] Completed successfully!")
                    results.append({
                        'notebook': notebook_path,
                        'table': table_name,
                        'status': 'SUCCESS'
                    })
                else:
                    print(f"         [ERROR] Job failed with state: {result_state}")
                    state_message = run_data.get('state', {}).get('state_message', 'No error message')
                    print(f"         Error: {state_message}")
                    results.append({
                        'notebook': notebook_path,
                        'status': 'FAILED',
                        'error': state_message
                    })
                break

            # Still running
            print(f"         Status: {life_cycle_state} (waited {elapsed}s)")
            time.sleep(poll_interval)
            elapsed += poll_interval

        if elapsed >= max_wait_seconds:
            print(f"         [ERROR] Job timed out after {max_wait_seconds}s")
            results.append({
                'notebook': notebook_path,
                'status': 'TIMEOUT'
            })

    except Exception as e:
        print(f"         [ERROR] Exception: {str(e)}")
        results.append({
            'notebook': notebook_path,
            'status': 'EXCEPTION',
            'error': str(e)
        })

# Print summary
print("\n" + "=" * 80)
print("TABLE CREATION SUMMARY")
print("=" * 80)

success_count = sum(1 for r in results if r.get('status') == 'SUCCESS')
failed_count = len(results) - success_count

for result in results:
    status = result.get('status')
    notebook = result.get('notebook', 'Unknown')
    table = result.get('table', 'Unknown')

    if status == 'SUCCESS':
        print(f"[OK]     {table:40} | {notebook}")
    else:
        print(f"[ERROR]  {table:40} | {status}")

print("=" * 80)
print(f"SUCCESS: {success_count}/{len(notebooks)} tables created")
print(f"FAILED:  {failed_count}/{len(notebooks)}")
print("=" * 80)

if success_count == len(notebooks):
    print("\n[SUCCESS] ALL TABLES CREATED SUCCESSFULLY!")
    print("\nTables created in gold/config/:")
    print("  1. company_config               - 10 companies across 3 pods")
    print("  2. pipeline_execution_log       - Execution tracking")
    print("  3. data_lineage                 - Source to gold lineage")
    print("  4. data_quality_log             - Quality check results")
    print("  5. sla_monitoring               - SLA compliance")
    print("  6. cost_tracking                - Cost attribution")
    print("  7. alert_rules                  - Alert configuration")
    print("  8. retry_policy                 - Retry configuration")
    print("  9. archive_log                  - Archive tracking")
    print("\nNext steps:")
    print("1. Verify tables in Databricks Data Explorer")
    print("2. Test get_company_config notebook")
    print("3. Build ADF pipeline")
else:
    print(f"\n[WARNING] {failed_count} tables failed to create. Check errors above.")
    print("Note: Some failures may be due to tables already existing.")
    print("You can verify table status in Databricks Data Explorer.")

print("\n" + "=" * 80)
