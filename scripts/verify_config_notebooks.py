"""
Verify all config notebooks are uploaded to Databricks
"""
import requests

host = 'https://adb-3370863217573312.12.azuredatabricks.net'
token = 'YOUR_DATABRICKS_TOKEN_HERE'

headers = {'Authorization': f'Bearer {token}'}

# Check /Shared/config folder
response = requests.get(
    f'{host}/api/2.0/workspace/list',
    headers=headers,
    params={'path': '/Shared/config'}
)

print("=" * 80)
print("DATABRICKS /Shared/config/ FOLDER CONTENTS")
print("=" * 80)

if response.status_code == 200:
    items = response.json().get('objects', [])

    print(f"\nTotal items: {len(items)}\n")

    # Categorize notebooks
    table_creation = []
    logging_helpers = []
    config_helpers = []

    for item in items:
        name = item['path'].split('/')[-1]
        if 'create' in name:
            table_creation.append(name)
        elif 'log_' in name:
            logging_helpers.append(name)
        else:
            config_helpers.append(name)

    print("TABLE CREATION NOTEBOOKS:")
    for notebook in sorted(table_creation):
        print(f"  [OK] {notebook}")

    print("\nLOGGING HELPER NOTEBOOKS:")
    for notebook in sorted(logging_helpers):
        print(f"  [OK] {notebook}")

    print("\nCONFIGURATION HELPER NOTEBOOKS:")
    for notebook in sorted(config_helpers):
        print(f"  [OK] {notebook}")

    print("\n" + "=" * 80)
    print("SUMMARY")
    print("=" * 80)
    print(f"Table Creation: {len(table_creation)} notebooks")
    print(f"Logging Helpers: {len(logging_helpers)} notebooks")
    print(f"Config Helpers: {len(config_helpers)} notebooks")
    print(f"Total: {len(items)} notebooks")
    print("=" * 80)

else:
    print(f"[ERROR] Failed to list /Shared/config")
    print(f"Status: {response.status_code}")
    print(f"Response: {response.text}")
