"""
Upload all logging and monitoring notebooks to Databricks
"""
import requests
import base64
import os

# Databricks configuration
host = 'https://adb-3370863217573312.12.azuredatabricks.net'
token = 'YOUR_DATABRICKS_TOKEN_HERE'

headers = {'Authorization': f'Bearer {token}'}

# Notebooks to upload
notebooks = [
    {
        'local': 'databricks_notebooks/config/02_create_pipeline_execution_log_table.py',
        'remote': '/Shared/config/create_pipeline_execution_log_table'
    },
    {
        'local': 'databricks_notebooks/config/log_execution_start.py',
        'remote': '/Shared/config/log_execution_start'
    },
    {
        'local': 'databricks_notebooks/config/log_execution_end.py',
        'remote': '/Shared/config/log_execution_end'
    },
    {
        'local': 'databricks_notebooks/config/log_execution_error.py',
        'remote': '/Shared/config/log_execution_error'
    },
    {
        'local': 'databricks_notebooks/config/03_create_data_lineage_table.py',
        'remote': '/Shared/config/create_data_lineage_table'
    },
    {
        'local': 'databricks_notebooks/config/log_data_lineage.py',
        'remote': '/Shared/config/log_data_lineage'
    },
    {
        'local': 'databricks_notebooks/config/04_create_data_quality_log_table.py',
        'remote': '/Shared/config/create_data_quality_log_table'
    },
    {
        'local': 'databricks_notebooks/config/05_create_sla_monitoring_table.py',
        'remote': '/Shared/config/create_sla_monitoring_table'
    },
    {
        'local': 'databricks_notebooks/config/06_create_cost_tracking_table.py',
        'remote': '/Shared/config/create_cost_tracking_table'
    },
    {
        'local': 'databricks_notebooks/config/07_create_alert_and_policy_tables.py',
        'remote': '/Shared/config/create_alert_and_policy_tables'
    }
]

print("=" * 80)
print("UPLOADING LOGGING AND MONITORING NOTEBOOKS TO DATABRICKS")
print("=" * 80)

success_count = 0
error_count = 0

for notebook in notebooks:
    local_path = notebook['local']
    remote_path = notebook['remote']

    print(f"\n[UPLOADING] {local_path}")
    print(f"         -> {remote_path}")

    # Read local file
    try:
        with open(local_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Encode content
        content_bytes = content.encode('utf-8')
        content_b64 = base64.b64encode(content_bytes).decode('utf-8')

        # Upload to Databricks
        data = {
            'path': remote_path,
            'content': content_b64,
            'language': 'PYTHON',
            'overwrite': True,
            'format': 'SOURCE'
        }

        response = requests.post(
            f'{host}/api/2.0/workspace/import',
            headers=headers,
            json=data
        )

        if response.status_code == 200:
            print(f"[OK] Uploaded successfully")
            success_count += 1
        else:
            print(f"[ERROR] Failed to upload")
            print(f"  Status: {response.status_code}")
            print(f"  Response: {response.text}")
            error_count += 1

    except FileNotFoundError:
        print(f"[ERROR] Local file not found: {local_path}")
        error_count += 1
    except Exception as e:
        print(f"[ERROR] {str(e)}")
        error_count += 1

print("\n" + "=" * 80)
print("UPLOAD SUMMARY")
print("=" * 80)
print(f"Total notebooks: {len(notebooks)}")
print(f"Successfully uploaded: {success_count}")
print(f"Errors: {error_count}")
print("=" * 80)

if success_count == len(notebooks):
    print("\n[OK] All logging notebooks uploaded successfully!")
    print("\nNext step: Run table creation notebooks to create Delta tables")
else:
    print("\n[WARNING] Some notebooks failed to upload. Check errors above.")
