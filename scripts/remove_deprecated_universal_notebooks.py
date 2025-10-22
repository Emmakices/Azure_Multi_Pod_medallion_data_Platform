"""
Remove deprecated universal notebooks from shared_notebooks folder
Keep only check_bronze_completeness
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

# Deprecated notebooks to delete
deprecated_notebooks = [
    '/Shared/shared_notebooks/bronze_to_silver_universal',
    '/Shared/shared_notebooks/silver_to_gold_universal',
]

print("Removing deprecated universal notebooks...")
print("=" * 60)

for notebook_path in deprecated_notebooks:
    print(f"\n[DELETING] {notebook_path}")
    if delete_notebook(notebook_path):
        print(f"[OK] Deleted successfully")
    else:
        print(f"[ERROR] Failed to delete")

print("\n" + "=" * 60)
print("Cleanup complete")
print("\nFinal shared_notebooks structure:")
print("  /Shared/shared_notebooks/check_bronze_completeness (ACTIVE)")
