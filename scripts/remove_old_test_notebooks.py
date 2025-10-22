"""
Remove old test notebooks from Databricks workspace
Keep only bronze_to_silver and silver_to_gold for each pod
"""
import requests

# Databricks configuration
host = 'https://adb-3370863217573312.12.azuredatabricks.net'
token = 'YOUR_DATABRICKS_TOKEN_HERE'

headers = {'Authorization': f'Bearer {token}'}

def delete_notebook(path):
    """Delete a notebook"""
    response = requests.post(
        f'{host}/api/2.0/workspace/delete',
        headers=headers,
        json={'path': path, 'recursive': False}
    )
    return response.status_code == 200

# Old test notebooks to delete
old_notebooks = [
    '/Shared/podA/01_bronze_to_silver_hr',
    '/Shared/podA/02_bronze_to_silver_payroll',
    '/Shared/podA/03_silver_to_gold_analytics',
    '/Shared/podB/01_bronze_to_silver_hr',
    '/Shared/podB/02_bronze_to_silver_payroll',
    '/Shared/podB/03_silver_to_gold_analytics',
    '/Shared/podC/01_bronze_to_silver_hr',
    '/Shared/podC/02_bronze_to_silver_payroll',
    '/Shared/podC/03_silver_to_gold_analytics',
]

print("Removing old test notebooks...")
print("=" * 60)

for notebook_path in old_notebooks:
    print(f"\n[DELETING] {notebook_path}")
    if delete_notebook(notebook_path):
        print(f"[OK] Deleted successfully")
    else:
        print(f"[ERROR] Failed to delete")

print("\n" + "=" * 60)
print("Cleanup complete")
print("\nFinal structure:")
print("  /Shared/podA/bronze_to_silver")
print("  /Shared/podA/silver_to_gold")
print("  /Shared/podB/bronze_to_silver")
print("  /Shared/podB/silver_to_gold")
print("  /Shared/podC/bronze_to_silver")
print("  /Shared/podC/silver_to_gold")
