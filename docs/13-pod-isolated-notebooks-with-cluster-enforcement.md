# Step 17: Pod-Isolated Notebooks with Cluster Enforcement

## What We're Building

In Step 16, we created shared notebooks in `/Shared/Payroll_ETL/` that all pods could use. But you asked a great question: **Can we make it so each pod has their own scripts isolated, just like the storage structure, and enforce them to use their own pod compute?**

The answer is **yes**, and that's exactly what we've built in this step.

## The Problem with Shared Notebooks

**Previous Structure** (Step 16):
```
/Shared/Payroll_ETL/
├── 01_bronze_to_silver_hr  (parameterized with pod_id widget)
├── 02_bronze_to_silver_payroll
└── 03_silver_to_gold_analytics
```

**Issues**:
- All pods share the same notebooks
- Users have to manually change the `pod_id` widget
- No enforcement - podA notebook could accidentally run on podB-interactive cluster
- Pod teams can see and modify each other's notebooks
- Harder to manage permissions per pod

## The Solution: Pod-Isolated Folders

**New Structure**:
```
/Shared/
├── podA/
│   ├── 01_bronze_to_silver_hr         (hardcoded for podA, requires podA-interactive)
│   ├── 02_bronze_to_silver_payroll    (hardcoded for podA, requires podA-interactive)
│   └── 03_silver_to_gold_analytics    (hardcoded for podA, requires podA-interactive)
│
├── podB/
│   ├── 01_bronze_to_silver_hr         (hardcoded for podB, requires podB-interactive)
│   ├── 02_bronze_to_silver_payroll    (hardcoded for podB, requires podB-interactive)
│   └── 03_silver_to_gold_analytics    (hardcoded for podB, requires podB-interactive)
│
└── podC/
    ├── 01_bronze_to_silver_hr         (hardcoded for podC, requires podC-interactive)
    ├── 02_bronze_to_silver_payroll    (hardcoded for podC, requires podC-interactive)
    └── 03_silver_to_gold_analytics    (hardcoded for podC, requires podC-interactive)
```

**Benefits**:
- **Complete Isolation**: Each pod has its own folder and notebooks
- **Cluster Enforcement**: Notebooks validate they're running on the correct cluster before processing
- **No Configuration Needed**: Pod ID is hardcoded (no widgets to change)
- **Permission Control**: Can grant podA team access to `/Shared/podA/` only
- **Consistent with Storage**: Mirrors the folder structure in blob storage and data lake

## How Cluster Enforcement Works

Every notebook starts with a Python validation cell that checks the cluster name:

```python
# Get the current cluster name
cluster_name = spark.conf.get("spark.databricks.clusterUsageTags.clusterName", "UNKNOWN")

# Define what cluster THIS notebook requires
REQUIRED_CLUSTER = "podA-interactive"
POD_ID = "podA"

# Enforce the requirement
if cluster_name != REQUIRED_CLUSTER:
    raise ValueError(f"""
    ╔══════════════════════════════════════════════════════════════╗
    ║  CLUSTER VALIDATION FAILED                                   ║
    ╠══════════════════════════════════════════════════════════════╣
    ║  This notebook is for Pod A and MUST run on:                 ║
    ║  Cluster: podA-interactive                                   ║
    ║                                                              ║
    ║  Currently running on: {cluster_name}                        ║
    ║                                                              ║
    ║  ACTION REQUIRED:                                            ║
    ║  1. Detach this notebook                                     ║
    ║  2. Attach to: podA-interactive                              ║
    ║  3. Re-run all cells                                         ║
    ╚══════════════════════════════════════════════════════════════╝
    """)
else:
    print("[DONE] CLUSTER VALIDATION PASSED")
    print(f"[DONE] Running on correct cluster: {REQUIRED_CLUSTER}")
```

**What Happens**:
1. User opens `/Shared/podA/01_bronze_to_silver_hr`
2. They attach to a cluster (let's say they accidentally pick `podB-interactive`)
3. They click "Run All"
4. **First cell immediately fails** with a clear error message
5. User sees they need to attach to `podA-interactive`
6. They switch clusters and re-run successfully

**This prevents**:
- podA notebooks from running on podB clusters (cost tracking accuracy)
- podB data being processed by podA notebooks (data isolation)
- Accidental cross-pod data corruption

## Implementation Steps

### Step 1: Create Pod Folders in Workspace

We created separate folders for each pod:

```python
import requests

host = 'https://adb-3370863217573312.12.azuredatabricks.net'
token = '<your-databricks-token>'
headers = {'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'}

for pod in ['podA', 'podB', 'podC']:
    data = {'path': f'/Shared/{pod}'}
    response = requests.post(f'{host}/api/2.0/workspace/mkdirs', headers=headers, json=data)
    print(f'Created folder: /Shared/{pod}')
```

**Result**:
```
Created folder: /Shared/podA
Created folder: /Shared/podB
Created folder: /Shared/podC
```

### Step 2: Generate Pod-Specific Notebooks

We created a Python script (`create_pod_isolated_notebooks.py`) that:
1. Defines notebook templates with placeholder variables
2. For each pod (podA, podB, podC):
   - Replaces `{pod_id}` with actual pod name
   - Replaces `{storage_account}` with actual storage account
   - Adds cluster validation cell specific to that pod
   - Hardcodes all paths to that pod's data
3. Imports each generated notebook to Databricks workspace

**Key Differences Between Pod Notebooks**:

**podA/01_bronze_to_silver_hr.sql**:
```sql
-- Cluster validation
REQUIRED_CLUSTER = "podA-interactive"
POD_ID = "podA"

-- Hardcoded configuration
DECLARE pod STRING DEFAULT 'podA';
DECLARE bronze_path STRING DEFAULT 'abfss://bronze@.../.../podA/hr/HR_EMPLOYEES';
DECLARE silver_path STRING DEFAULT 'abfss://silver@.../.../podA/hr/employees';
```

**podB/01_bronze_to_silver_hr.sql**:
```sql
-- Cluster validation
REQUIRED_CLUSTER = "podB-interactive"
POD_ID = "podB"

-- Hardcoded configuration
DECLARE pod STRING DEFAULT 'podB';
DECLARE bronze_path STRING DEFAULT 'abfss://bronze@.../.../podB/hr/HR_EMPLOYEES';
DECLARE silver_path STRING DEFAULT 'abfss://silver@.../.../podB/hr/employees';
```

**Notice**:
- Different required cluster
- Different pod ID
- Different data paths
- Completely isolated

### Step 3: Run the Generation Script

```bash
cd /c/Users/User/Desktop/Delta_lake_project
python create_pod_isolated_notebooks.py
```

**Output**:
```
======================================================================
Creating Pod-Isolated Notebooks with Cluster Enforcement
======================================================================

[PODA] Creating and importing notebooks...
  SUCCESS - HR Cleansing: /Shared/podA/01_bronze_to_silver_hr
  SUCCESS - Payroll Cleansing: /Shared/podA/02_bronze_to_silver_payroll
  SUCCESS - Gold Analytics: /Shared/podA/03_silver_to_gold_analytics

[PODB] Creating and importing notebooks...
  SUCCESS - HR Cleansing: /Shared/podB/01_bronze_to_silver_hr
  SUCCESS - Payroll Cleansing: /Shared/podB/02_bronze_to_silver_payroll
  SUCCESS - Gold Analytics: /Shared/podB/03_silver_to_gold_analytics

[PODC] Creating and importing notebooks...
  SUCCESS - HR Cleansing: /Shared/podC/01_bronze_to_silver_hr
  SUCCESS - Payroll Cleansing: /Shared/podC/02_bronze_to_silver_payroll
  SUCCESS - Gold Analytics: /Shared/podC/03_silver_to_gold_analytics

======================================================================
Import Complete: 9 notebooks created
======================================================================
```

### Step 4: Verify in Databricks Workspace

Navigate to: `https://adb-3370863217573312.12.azuredatabricks.net`

Click **Workspace** → **Shared**

You should see:
```
📁 Shared/
  📁 podA/
    📄 01_bronze_to_silver_hr
    📄 02_bronze_to_silver_payroll
    📄 03_silver_to_gold_analytics
  📁 podB/
    📄 01_bronze_to_silver_hr
    📄 02_bronze_to_silver_payroll
    📄 03_silver_to_gold_analytics
  📁 podC/
    📄 01_bronze_to_silver_hr
    📄 02_bronze_to_silver_payroll
    📄 03_silver_to_gold_analytics
```

## How to Use Pod-Isolated Notebooks

### For Pod A Team:

1. Navigate to `/Shared/podA/`
2. Open `01_bronze_to_silver_hr`
3. Attach to cluster: **podA-interactive**
4. Click **Run All**
5. If you attached to the wrong cluster, the first cell will fail immediately
6. Switch to `podA-interactive` and re-run

### For Pod B Team:

1. Navigate to `/Shared/podB/`
2. Open `01_bronze_to_silver_hr`
3. Attach to cluster: **podB-interactive**
4. Click **Run All**
5. Notebook only processes podB data

**No widgets to configure, no parameters to change** - everything is hardcoded for that pod.

## Testing Cluster Enforcement

Let's test that the enforcement actually works:

### Test 1: Correct Cluster (Should Pass)

1. Open `/Shared/podA/01_bronze_to_silver_hr`
2. Attach to `podA-interactive`
3. Run first cell

**Expected Output**:
```
Current Cluster: podA-interactive
Required Cluster: podA-interactive
Pod ID: podA
[DONE] CLUSTER VALIDATION PASSED
[DONE] Running on correct cluster: podA-interactive
```

Notebook continues executing normally.

### Test 2: Wrong Cluster (Should Fail)

1. Open `/Shared/podA/01_bronze_to_silver_hr`
2. Attach to `podB-interactive` (wrong cluster!)
3. Run first cell

**Expected Output**:
```
╔══════════════════════════════════════════════════════════════╗
║  CLUSTER VALIDATION FAILED                                   ║
╠══════════════════════════════════════════════════════════════╣
║  This notebook is for Pod A and MUST run on:                 ║
║  Cluster: podA-interactive                                   ║
║                                                              ║
║  Currently running on: podB-interactive                      ║
║                                                              ║
║  ACTION REQUIRED:                                            ║
║  1. Detach this notebook                                     ║
║  2. Attach to: podA-interactive                              ║
║  3. Re-run all cells                                         ║
╚══════════════════════════════════════════════════════════════╝

ValueError: [error message above]
```

Notebook execution **stops immediately**. User must switch clusters.

## Data Isolation Verification

Each pod's notebooks only access their own data paths:

**podA notebooks**:
```
bronze/podA/hr/
bronze/podA/payroll/
silver/podA/hr/
silver/podA/payroll/
gold/podA/analytics/
```

**podB notebooks**:
```
bronze/podB/hr/
bronze/podB/payroll/
silver/podB/hr/
silver/podB/payroll/
gold/podB/analytics/
```

**podC notebooks**:
```
bronze/podC/hr/
bronze/podC/payroll/
silver/podC/hr/
silver/podC/payroll/
gold/podC/analytics/
```

There's **no way** for a podA notebook to accidentally read or write podB data because all paths are hardcoded.

## Permission Management (Optional)

You can now set Databricks workspace permissions per pod:

### Grant Pod A Team Access to Their Folder Only:

1. In Databricks, right-click `/Shared/podA/`
2. Click **Permissions**
3. Add the Pod A team group
4. Grant: **Can Run, Can Edit**
5. Do NOT grant access to `/Shared/podB/` or `/Shared/podC/`

**Result**: Pod A team can only see and run their own notebooks.

This is just like how you've isolated storage:
- `hr-landing/podA/` → only podA team can write here
- `silver/podA/` → only podA notebooks write here
- `/Shared/podA/` → only podA team can edit notebooks

## Comparison: Shared vs Isolated

| Feature | Shared Notebooks (Step 16) | Pod-Isolated (Step 17) |
|---------|----------------------------|------------------------|
| Folder Structure | `/Shared/Payroll_ETL/` (all pods) | `/Shared/podA/`, `/Shared/podB/`, `/Shared/podC/` |
| Pod ID | Widget parameter (manual) | Hardcoded per pod |
| Cluster | User picks any cluster | Enforced - must use pod cluster |
| Data Paths | Parameterized | Hardcoded per pod |
| Permissions | All pods see same notebooks | Can restrict access per pod |
| Configuration | Change widget before each run | No configuration needed |
| Isolation | Logical (parameter-based) | Physical (separate notebooks) |
| Risk of Error | Medium (wrong parameter) | Low (enforced validation) |
| Maintenance | 3 notebooks (less code) | 9 notebooks (more code) |

## When to Use Which Approach

**Use Shared Notebooks (Step 16) if**:
- You have a small team that manages all pods
- You want less code to maintain
- You trust users to set parameters correctly
- You want maximum flexibility

**Use Pod-Isolated Notebooks (Step 17) if**:
- You have separate teams per pod
- You need strict isolation and enforcement
- You want to grant different permissions per pod
- You want to prevent accidental cross-pod access
- You prioritize safety over code maintainability

## Adding a New Pod (podD)

When you add podD in the future, here's what you do:

### Step 1: Update the Script

Edit `create_pod_isolated_notebooks.py`:

```python
PODS = ['podA', 'podB', 'podC', 'podD']  # Add podD
```

### Step 2: Re-run the Script

```bash
python create_pod_isolated_notebooks.py
```

**Output**:
```
[PODD] Creating and importing notebooks...
  SUCCESS - HR Cleansing: /Shared/podD/01_bronze_to_silver_hr
  SUCCESS - Payroll Cleansing: /Shared/podD/02_bronze_to_silver_payroll
  SUCCESS - Gold Analytics: /Shared/podD/03_silver_to_gold_analytics
```

### Step 3: Create podD Cluster

In Databricks UI:
1. Create cluster pool: `podD-pool`
2. Create cluster: `podD-interactive`

### Step 4: Done

podD team can now run `/Shared/podD/` notebooks on `podD-interactive` cluster, processing only `podD` data.

## Script Breakdown: How It Works

The `create_pod_isolated_notebooks.py` script has three main functions:

### 1. `create_cluster_validation_cell(pod_id)`

Generates the Python validation cell that enforces cluster usage:

```python
def create_cluster_validation_cell(pod_id):
    return f"""-- MAGIC %python
-- MAGIC cluster_name = spark.conf.get("spark.databricks.clusterUsageTags.clusterName", "UNKNOWN")
-- MAGIC REQUIRED_CLUSTER = "{pod_id}-interactive"
-- MAGIC
-- MAGIC if cluster_name != REQUIRED_CLUSTER:
-- MAGIC     raise ValueError("Wrong cluster!")
-- MAGIC else:
-- MAGIC     print("[DONE] Cluster validation passed")
"""
```

### 2. `create_hr_notebook(pod_id, storage_account)`

Generates the HR cleansing notebook with:
- Pod-specific cluster validation
- Hardcoded pod ID
- Hardcoded data paths
- SQL transformation logic

### 3. `import_notebook_to_databricks(content, path)`

Takes generated notebook content and imports to Databricks:

```python
def import_notebook_to_databricks(notebook_content, workspace_path):
    # Base64 encode
    content_b64 = base64.b64encode(notebook_content.encode('utf-8')).decode('utf-8')

    # Import via REST API
    data = {
        'path': workspace_path,
        'content': content_b64,
        'language': 'SQL',
        'overwrite': True,
        'format': 'SOURCE'
    }

    response = requests.post(f'{DATABRICKS_HOST}/api/2.0/workspace/import',
                            headers=headers, json=data)
    return response
```

### Main Loop

```python
for pod in ['podA', 'podB', 'podC']:
    # Generate notebooks
    hr_notebook = create_hr_notebook(pod, STORAGE_ACCOUNT)
    payroll_notebook = create_payroll_notebook(pod, STORAGE_ACCOUNT)
    gold_notebook = create_gold_notebook(pod, STORAGE_ACCOUNT)

    # Import to workspace
    import_notebook_to_databricks(hr_notebook, f'/Shared/{pod}/01_bronze_to_silver_hr')
    import_notebook_to_databricks(payroll_notebook, f'/Shared/{pod}/02_bronze_to_silver_payroll')
    import_notebook_to_databricks(gold_notebook, f'/Shared/{pod}/03_silver_to_gold_analytics')
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    Databricks Workspace                         │
│                                                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │  /Shared/podA/ │  │  /Shared/podB/ │  │  /Shared/podC/ │   │
│  │                │  │                │  │                │   │
│  │  📄 01_hr      │  │  📄 01_hr      │  │  📄 01_hr      │   │
│  │  📄 02_payroll │  │  📄 02_payroll │  │  📄 02_payroll │   │
│  │  📄 03_gold    │  │  📄 03_gold    │  │  📄 03_gold    │   │
│  └────────┬───────┘  └────────┬───────┘  └────────┬───────┘   │
│           │                   │                    │            │
│           ↓                   ↓                    ↓            │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐   │
│  │ podA-          │  │ podB-          │  │ podC-          │   │
│  │ interactive    │  │ interactive    │  │ interactive    │   │
│  │ (enforced)     │  │ (enforced)     │  │ (enforced)     │   │
│  └────────┬───────┘  └────────┬───────┘  └────────┬───────┘   │
└───────────┼──────────────────┼─────────────────────┼──────────┘
            │                   │                     │
            ↓                   ↓                     ↓
┌───────────────────────────────────────────────────────────────┐
│                    Azure Data Lake Gen2                        │
│                                                                 │
│  bronze/podA/     silver/podA/     gold/podA/                  │
│  bronze/podB/     silver/podB/     gold/podB/                  │
│  bronze/podC/     silver/podC/     gold/podC/                  │
│                                                                 │
│  (Complete data isolation - hardcoded paths)                   │
└─────────────────────────────────────────────────────────────────┘
```

## Summary

We've successfully created a pod-isolated notebook architecture that mirrors your storage isolation:

**What We Built**:
- 9 notebooks (3 per pod) in isolated folders
- Cluster enforcement validates correct cluster before execution
- Hardcoded pod IDs and data paths (no configuration needed)
- Complete isolation between pods
- Permission-ready structure for team-based access control

**How It Works**:
- Each pod has its own folder: `/Shared/podA/`, `/Shared/podB/`, `/Shared/podC/`
- Each notebook validates cluster name before processing
- All paths are hardcoded to that pod's data
- Wrong cluster = immediate failure with clear error message

**Benefits**:
- Matches storage isolation pattern (bronze/podA/, silver/podA/, etc.)
- Prevents accidental cross-pod data access
- Enables per-pod permission management
- No user configuration required
- Safe by default

**Automation**:
- `create_pod_isolated_notebooks.py` generates and imports all notebooks
- Add new pod by updating PODS list and re-running script
- Fully reproducible and version-controlled

This gives you complete isolation at the notebook level, cluster level, and data level - all within the same shared Databricks workspace.
