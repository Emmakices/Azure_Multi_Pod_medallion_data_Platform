"""
Check what notebooks are in /Shared/shared_notebooks/ folder
"""
import requests

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

# Check shared_notebooks folder
shared_path = '/Shared/shared_notebooks'

print("=" * 60)
print(f"Contents of {shared_path}/")
print("=" * 60)

contents = list_workspace(shared_path)

if contents:
    for item in contents:
        item_name = item['path'].split('/')[-1]
        item_type = item['object_type']
        print(f"  - {item_name} ({item_type})")
else:
    print("  (No items found or folder does not exist)")

print("=" * 60)
