"""
List all Databricks clusters
"""
import requests

host = 'https://adb-3370863217573312.12.azuredatabricks.net'
token = 'YOUR_DATABRICKS_TOKEN_HERE'

headers = {'Authorization': f'Bearer {token}'}

response = requests.get(
    f'{host}/api/2.0/clusters/list',
    headers=headers
)

print("=" * 80)
print("DATABRICKS CLUSTERS")
print("=" * 80)

if response.status_code == 200:
    data = response.json()
    clusters = data.get('clusters', [])

    if clusters:
        print(f"\nTotal clusters: {len(clusters)}\n")

        for cluster in clusters:
            cluster_id = cluster['cluster_id']
            cluster_name = cluster['cluster_name']
            state = cluster['state']

            print(f"Cluster: {cluster_name}")
            print(f"  ID: {cluster_id}")
            print(f"  State: {state}")
            print()
    else:
        print("\nNo clusters found")
        print("\nYou can create tables using job clusters (recommended)")
        print("or run notebooks manually in Databricks UI")
else:
    print(f"[ERROR] Failed to list clusters")
    print(f"Status: {response.status_code}")
    print(f"Response: {response.text}")

print("=" * 80)
