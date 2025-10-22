"""
Cleanup duplicate Databricks notebooks
Removes /Shared/podX/notebooks/ folders if they exist
"""
import requests
import json

# Databricks configuration
host = 'https://adb-3370863217573312.12.azuredatabricks.net'
token = 'YOUR_DATABRICKS_TOKEN_HERE'

headers = {'Authorization': f'Bearer {token}'}

def list_workspace(path):
    """List workspace contents"""
    response = requests.get(
        f'{host}/api/2.0/workspace/list',
        headers=headers,
        params={'path': path}
    )
    if response.status_code == 200:
        return response.json().get('objects', [])
    return []

def delete_workspace(path):
    """Delete workspace folder/notebook"""
    response = requests.post(
        f'{host}/api/2.0/workspace/delete',
        headers=headers,
        json={'path': path, 'recursive': True}
    )
    return response.status_code == 200

# Check each pod for duplicate notebooks folder
pods = ['podA', 'podB', 'podC']

print("Checking for duplicate notebooks folders...")
print("=" * 60)

for pod in pods:
    pod_path = f'/Shared/{pod}'

    # List contents of pod folder
    contents = list_workspace(pod_path)

    print(f"\n{pod_path}/")
    for item in contents:
        item_name = item['path'].split('/')[-1]
        item_type = item['object_type']
        print(f"  - {item_name} ({item_type})")

    # Check if notebooks folder exists
    notebooks_folder = f'/Shared/{pod}/notebooks'
    notebooks_contents = list_workspace(notebooks_folder)

    if notebooks_contents:
        print(f"\n[FOUND DUPLICATE] {notebooks_folder}/")
        for item in notebooks_contents:
            item_name = item['path'].split('/')[-1]
            print(f"  - {item_name}")

        # Delete the duplicate notebooks folder
        print(f"\n[DELETING] {notebooks_folder}/")
        if delete_workspace(notebooks_folder):
            print(f"[OK] Deleted {notebooks_folder}")
        else:
            print(f"[ERROR] Failed to delete {notebooks_folder}")

print("\n" + "=" * 60)
print("Cleanup complete")
print("\nFinal structure should be:")
print("/Shared/podA/bronze_to_silver")
print("/Shared/podA/silver_to_gold")
print("/Shared/podB/bronze_to_silver")
print("/Shared/podB/silver_to_gold")
print("/Shared/podC/bronze_to_silver")
print("/Shared/podC/silver_to_gold")
