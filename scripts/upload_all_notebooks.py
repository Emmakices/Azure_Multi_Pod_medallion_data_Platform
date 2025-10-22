"""
Upload ALL notebooks to Databricks workspace
- Config notebooks (table creation + helpers)
- Shared notebooks (completeness check)
- Pod-specific notebooks (podA, podB, podC)
"""
import requests
import base64
import os

# Databricks configuration
host = 'https://adb-3370863217573312.12.azuredatabricks.net'
token = 'YOUR_DATABRICKS_TOKEN_HERE'

headers = {'Authorization': f'Bearer {token}'}

# All notebooks to upload
notebooks = [
    # === CONFIG NOTEBOOKS ===
    {
        'local': 'databricks_notebooks/config/01_create_company_config_table.py',
        'remote': '/Shared/config/create_company_config_table',
        'category': 'CONFIG'
    },
    {
        'local': 'databricks_notebooks/config/02_create_pipeline_execution_log_table.py',
        'remote': '/Shared/config/create_pipeline_execution_log_table',
        'category': 'CONFIG'
    },
    {
        'local': 'databricks_notebooks/config/03_create_data_lineage_table.py',
        'remote': '/Shared/config/create_data_lineage_table',
        'category': 'CONFIG'
    },
    {
        'local': 'databricks_notebooks/config/04_create_data_quality_log_table.py',
        'remote': '/Shared/config/create_data_quality_log_table',
        'category': 'CONFIG'
    },
    {
        'local': 'databricks_notebooks/config/05_create_sla_monitoring_table.py',
        'remote': '/Shared/config/create_sla_monitoring_table',
        'category': 'CONFIG'
    },
    {
        'local': 'databricks_notebooks/config/06_create_cost_tracking_table.py',
        'remote': '/Shared/config/create_cost_tracking_table',
        'category': 'CONFIG'
    },
    {
        'local': 'databricks_notebooks/config/07_create_alert_and_policy_tables.py',
        'remote': '/Shared/config/create_alert_and_policy_tables',
        'category': 'CONFIG'
    },

    # === HELPER NOTEBOOKS ===
    {
        'local': 'databricks_notebooks/config/get_company_config.py',
        'remote': '/Shared/config/get_company_config',
        'category': 'HELPER'
    },
    {
        'local': 'databricks_notebooks/config/log_execution_start.py',
        'remote': '/Shared/config/log_execution_start',
        'category': 'HELPER'
    },
    {
        'local': 'databricks_notebooks/config/log_execution_end.py',
        'remote': '/Shared/config/log_execution_end',
        'category': 'HELPER'
    },
    {
        'local': 'databricks_notebooks/config/log_execution_error.py',
        'remote': '/Shared/config/log_execution_error',
        'category': 'HELPER'
    },
    {
        'local': 'databricks_notebooks/config/log_data_lineage.py',
        'remote': '/Shared/config/log_data_lineage',
        'category': 'HELPER'
    },

    # === SHARED NOTEBOOKS ===
    {
        'local': 'databricks_notebooks/shared_notebooks/check_bronze_completeness.py',
        'remote': '/Shared/shared_notebooks/check_bronze_completeness',
        'category': 'SHARED'
    },

    # === POD A NOTEBOOKS ===
    {
        'local': 'databricks_notebooks/podA/notebooks/bronze_to_silver.py',
        'remote': '/Shared/podA/bronze_to_silver',
        'category': 'POD_A'
    },
    {
        'local': 'databricks_notebooks/podA/notebooks/silver_to_gold.py',
        'remote': '/Shared/podA/silver_to_gold',
        'category': 'POD_A'
    },

    # === POD B NOTEBOOKS ===
    {
        'local': 'databricks_notebooks/podB/notebooks/bronze_to_silver.py',
        'remote': '/Shared/podB/bronze_to_silver',
        'category': 'POD_B'
    },
    {
        'local': 'databricks_notebooks/podB/notebooks/silver_to_gold.py',
        'remote': '/Shared/podB/silver_to_gold',
        'category': 'POD_B'
    },

    # === POD C NOTEBOOKS ===
    {
        'local': 'databricks_notebooks/podC/notebooks/bronze_to_silver.py',
        'remote': '/Shared/podC/bronze_to_silver',
        'category': 'POD_C'
    },
    {
        'local': 'databricks_notebooks/podC/notebooks/silver_to_gold.py',
        'remote': '/Shared/podC/silver_to_gold',
        'category': 'POD_C'
    }
]

print("=" * 80)
print("UPLOADING ALL NOTEBOOKS TO DATABRICKS")
print("=" * 80)
print(f"Host: {host}")
print(f"Total notebooks: {len(notebooks)}")
print("=" * 80)

results = {
    'CONFIG': {'success': 0, 'errors': 0},
    'HELPER': {'success': 0, 'errors': 0},
    'SHARED': {'success': 0, 'errors': 0},
    'POD_A': {'success': 0, 'errors': 0},
    'POD_B': {'success': 0, 'errors': 0},
    'POD_C': {'success': 0, 'errors': 0}
}

for notebook in notebooks:
    local_path = notebook['local']
    remote_path = notebook['remote']
    category = notebook['category']

    print(f"\n[{category}] {os.path.basename(local_path)}")
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
            print(f"         [OK] Uploaded successfully")
            results[category]['success'] += 1
        else:
            print(f"         [ERROR] Failed to upload")
            print(f"           Status: {response.status_code}")
            print(f"           Response: {response.text}")
            results[category]['errors'] += 1

    except FileNotFoundError:
        print(f"         [ERROR] Local file not found: {local_path}")
        results[category]['errors'] += 1
    except Exception as e:
        print(f"         [ERROR] Error: {str(e)}")
        results[category]['errors'] += 1

# Print summary
print("\n" + "=" * 80)
print("UPLOAD SUMMARY BY CATEGORY")
print("=" * 80)

total_success = 0
total_errors = 0

for category, counts in results.items():
    success = counts['success']
    errors = counts['errors']
    total = success + errors
    total_success += success
    total_errors += errors

    status = "[OK]" if errors == 0 else "[ERROR]"
    print(f"{status:8} {category:12} | Success: {success}/{total} | Errors: {errors}")

print("=" * 80)
print(f"OVERALL: {total_success}/{len(notebooks)} notebooks uploaded successfully")
print("=" * 80)

if total_success == len(notebooks):
    print("\n[SUCCESS] ALL NOTEBOOKS UPLOADED SUCCESSFULLY!")
    print("\nNext steps:")
    print("1. Run table creation notebooks (01-07) to create Delta tables")
    print("2. Verify tables created in gold/config/")
    print("3. Test get_company_config helper notebook")
    print("4. Build ADF pipeline")
else:
    print(f"\n[WARNING] {total_errors} notebooks failed to upload. Check errors above.")

# Print folder structure created
print("\n" + "=" * 80)
print("DATABRICKS WORKSPACE STRUCTURE CREATED")
print("=" * 80)
print("""
/Shared/
├── config/                          (7 table creation + 5 helper notebooks)
│   ├── create_company_config_table
│   ├── create_pipeline_execution_log_table
│   ├── create_data_lineage_table
│   ├── create_data_quality_log_table
│   ├── create_sla_monitoring_table
│   ├── create_cost_tracking_table
│   ├── create_alert_and_policy_tables
│   ├── get_company_config
│   ├── log_execution_start
│   ├── log_execution_end
│   ├── log_execution_error
│   └── log_data_lineage
├── shared_notebooks/                (1 shared utility)
│   └── check_bronze_completeness
├── podA/                            (2 transformation notebooks)
│   ├── bronze_to_silver
│   └── silver_to_gold
├── podB/                            (2 transformation notebooks)
│   ├── bronze_to_silver
│   └── silver_to_gold
└── podC/                            (2 transformation notebooks)
    ├── bronze_to_silver
    └── silver_to_gold

Total: 21 notebooks
""")
print("=" * 80)
