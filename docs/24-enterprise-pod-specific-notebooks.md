# Enterprise-Ready Pod-Specific Notebook Architecture

**Document Version**: 1.0
**Last Updated**: January 16, 2025
**Purpose**: Multi-pod notebook governance and ownership model

---

## Business Context

In a multi-pod data platform, each pod has **dedicated data engineering teams** (typically 2 engineers per pod) who are responsible for writing and maintaining their own transformation logic. This requires clear:

1. **Ownership**: Each pod team owns their notebooks
2. **Isolation**: Changes in one pod don't affect others
3. **Customization**: Each pod can implement business-specific logic
4. **Governance**: Clear structure for code management and version control
5. **Scalability**: Easy to add new pods without central bottlenecks

---

## Architecture Overview

### Databricks Workspace Structure

```
/Shared/
├─ shared_notebooks/                    (Shared utilities only)
│   └─ check_bronze_completeness        (Common to all pods)
│
├─ podA/                                (podA team owns this)
│   ├─ bronze_to_silver                 (NEW - Universal for all domains)
│   ├─ silver_to_gold                   (NEW - Universal for all domains)
│   ├─ 01_bronze_to_silver_hr           (OLD - Can be deprecated)
│   ├─ 02_bronze_to_silver_payroll      (OLD - Can be deprecated)
│   └─ 03_silver_to_gold_analytics      (OLD - Can be deprecated)
│
├─ podB/                                (podB team owns this)
│   ├─ bronze_to_silver                 (NEW - Universal for all domains)
│   ├─ silver_to_gold                   (NEW - Universal for all domains)
│   ├─ 01_bronze_to_silver_hr           (OLD - Can be deprecated)
│   ├─ 02_bronze_to_silver_payroll      (OLD - Can be deprecated)
│   └─ 03_silver_to_gold_analytics      (OLD - Can be deprecated)
│
└─ podC/                                (podC team owns this)
    ├─ bronze_to_silver                 (NEW - Universal for all domains)
    ├─ silver_to_gold                   (NEW - Universal for all domains)
    ├─ 01_bronze_to_silver_hr           (OLD - Can be deprecated)
    ├─ 02_bronze_to_silver_payroll      (OLD - Can be deprecated)
    └─ 03_silver_to_gold_analytics      (OLD - Can be deprecated)
```

### What Changed

**OLD Architecture** (Domain-Specific Notebooks):
- Separate notebook per domain: `01_bronze_to_silver_hr`, `02_bronze_to_silver_payroll`
- Each domain has its own notebook with hardcoded logic
- Adding new domain requires creating new notebook
- Harder to maintain consistency

**NEW Architecture** (Pod-Specific Universal Notebooks):
- Single `bronze_to_silver` notebook per pod that accepts `domain` as parameter
- Single `silver_to_gold` notebook per pod that accepts `domain` as parameter
- Domain-agnostic with conditional logic for domain-specific rules
- Each pod team customizes their notebooks based on their business requirements

---

## Key Principles

### 1. Pod Ownership

**Each pod folder is owned by that pod's team:**

- **podA Team**: Owns `/Shared/podA/` and all notebooks inside
- **podB Team**: Owns `/Shared/podB/` and all notebooks inside
- **podC Team**: Owns `/Shared/podC/` and all notebooks inside

**Responsibilities**:
- Write transformation logic for their companies/domains
- Customize data quality rules
- Define business-specific metrics
- Test and validate their notebooks
- Manage code versions (via Git integration)

### 2. Customization Per Pod

Each pod can implement **different transformation logic** based on their business requirements.

**Example - podA Finance HR vs podB Sales Customers**:

```python
# /Shared/podA/bronze_to_silver
if domain == "hr" and company == "finance":
    # podA-specific HR rules
    df_cleansed = df_bronze \
        .filter(col("employee_id").isNotNull()) \
        .withColumn("email", lower(col("email"))) \
        .withColumn("department", upper(col("department")))

# /Shared/podB/bronze_to_silver
if domain == "customers" and company == "sales":
    # podB-specific customer rules
    df_cleansed = df_bronze \
        .filter(col("customer_id").isNotNull()) \
        .withColumn("email_validated", validate_email_udf(col("email")))
```

### 3. Isolation and Independence

**Changes in one pod do NOT affect other pods:**

- podA team updates their `bronze_to_silver` notebook → Only podA pipelines affected
- podB team adds new domain logic → Only podB pipelines affected
- No cross-pod dependencies or conflicts

### 4. Shared Utilities Only

**`/Shared/shared_notebooks/` contains ONLY truly shared code:**

- `check_bronze_completeness`: Used by all pods to check file completeness
- Future: Common UDFs, utility functions, validation libraries

**What should NOT be in shared notebooks**:
- Transformation logic (pod-specific)
- Business rules (pod-specific)
- Domain-specific aggregations (pod-specific)

---

## ADF Pipeline Integration

### Dynamic Notebook Path Construction

**ADF pipeline calls pod-specific notebooks dynamically:**

```json
{
    "notebook_task": {
        "notebook_path": "@{concat('/Shared/', pipeline().parameters.pod_id, '/bronze_to_silver')}",
        "base_parameters": {
            "pod_id": "@{pipeline().parameters.pod_id}",
            "company": "@{item().company}",
            "domain": "@{item().domain}",
            "storage_account": "@{pipeline().parameters.storage_account}"
        }
    }
}
```

**How it works**:
- `pod_id = "podA"` → Calls `/Shared/podA/bronze_to_silver`
- `pod_id = "podB"` → Calls `/Shared/podB/bronze_to_silver`
- `pod_id = "podC"` → Calls `/Shared/podC/bronze_to_silver`

**Parameters passed**:
- `pod_id`: Which pod (podA, podB, podC)
- `company`: Which company within the pod (finance, operations, sales)
- `domain`: Which domain to process (hr, payroll, customers, compliance)
- `storage_account`: Azure storage account name

---

## Notebook Examples

### podA Bronze to Silver

**Path**: `/Shared/podA/bronze_to_silver`

**Key Features**:
- podA-specific data quality rules
- Custom HR validation for Finance company
- Custom Payroll validation for Finance company
- Extensible for future domains (Operations, Marketing, IT)

**Example Logic**:
```python
if domain == "hr":
    # podA HR-specific rules
    df_cleansed = df_bronze \
        .filter(col("employee_id").isNotNull()) \
        .withColumn("first_name", trim(col("first_name"))) \
        .withColumn("email", lower(col("email"))) \
        .withColumn("department", upper(col("department")))

elif domain == "payroll":
    # podA Payroll-specific rules
    df_cleansed = df_bronze \
        .filter(col("employee_id").isNotNull()) \
        .filter(col("base_salary") > 0)
```

### podA Silver to Gold

**Path**: `/Shared/podA/silver_to_gold`

**Key Features**:
- podA-specific business metrics and KPIs
- Finance HR: Department headcount, average salary, hire date analysis
- Finance Payroll: Compensation totals, bonus analysis
- Company-specific and domain-specific aggregations

**Example Logic**:
```python
if domain == "hr" and company == "finance":
    # podA Finance HR metrics
    df_gold = df_silver.groupBy("department").agg(
        count("*").alias("employee_count"),
        avg("salary").alias("avg_salary"),
        min("hire_date").alias("earliest_hire")
    )

elif domain == "payroll" and company == "finance":
    # podA Finance Payroll metrics
    df_gold = df_silver.groupBy("department").agg(
        sum("base_salary").alias("total_base_salary"),
        sum("bonus").alias("total_bonus")
    )
```

---

## Governance Model

### Team Structure

```
Pod Teams:
├─ podA Team (2 engineers)
│   ├─ Responsibility: Finance, Operations, Marketing, IT
│   └─ Owns: /Shared/podA/ notebooks
│
├─ podB Team (2 engineers)
│   ├─ Responsibility: Sales, Support, Product
│   └─ Owns: /Shared/podB/ notebooks
│
└─ podC Team (2 engineers)
    ├─ Responsibility: HR Central, Compliance
    └─ Owns: /Shared/podC/ notebooks
```

### Version Control Strategy

**Recommended Approach**: Databricks Repos (Git Integration)

```
Git Repository Structure:
├─ notebooks/
│   ├─ podA/
│   │   ├─ bronze_to_silver.py
│   │   └─ silver_to_gold.py
│   ├─ podB/
│   │   ├─ bronze_to_silver.py
│   │   └─ silver_to_gold.py
│   └─ podC/
│       ├─ bronze_to_silver.py
│       └─ silver_to_gold.py
└─ shared/
    └─ check_bronze_completeness.py
```

**Workflow**:
1. Each pod team has their own Git branch: `podA-dev`, `podB-dev`, `podC-dev`
2. Teams develop and test in their branches
3. Merge to `main` after testing
4. Databricks Repos syncs notebooks to workspace

### Access Control

**Databricks Workspace Permissions**:

```
/Shared/podA/:
  - podA Team: CAN EDIT
  - podB Team: READ ONLY
  - podC Team: READ ONLY
  - Platform Team: CAN MANAGE

/Shared/podB/:
  - podB Team: CAN EDIT
  - podA Team: READ ONLY
  - podC Team: READ ONLY
  - Platform Team: CAN MANAGE

/Shared/podC/:
  - podC Team: CAN EDIT
  - podA Team: READ ONLY
  - podB Team: READ ONLY
  - Platform Team: CAN MANAGE

/Shared/shared_notebooks/:
  - Platform Team: CAN EDIT
  - All Pod Teams: READ ONLY
```

**Benefits**:
- Teams can only modify their own notebooks
- Cross-pod visibility for learning/collaboration
- Platform team manages shared utilities
- Prevents accidental changes to other pods

---

## Benefits of This Architecture

### 1. Clear Ownership
- Each pod team owns their transformation logic
- No ambiguity about who maintains what
- Easy accountability for data quality

### 2. Team Autonomy
- Teams work independently without blocking each other
- Can customize logic based on business requirements
- Fast iteration without central approval

### 3. Scalability
- Adding new pod = Create new folder with 2 notebooks
- No central bottleneck or shared code conflicts
- Each pod scales independently

### 4. Reduced Blast Radius
- Bug in podA notebook → Only podA affected
- Testing in podB → No impact on podA or podC
- Safe experimentation per pod

### 5. Business-Specific Customization
- Finance rules different from Sales rules
- HR metrics different from Compliance metrics
- Each pod optimizes for their use case

### 6. Easy Testing
- Test podA notebooks in isolation
- Mock data for specific pod/company/domain
- Clear test ownership per team

### 7. Professional Code Management
- Git integration per pod folder
- Code reviews within pod teams
- Version history per pod
- Branch protection rules

---

## Migration from Old to New

### Old Notebooks (Can be deprecated)

```
/Shared/podA/01_bronze_to_silver_hr
/Shared/podA/02_bronze_to_silver_payroll
/Shared/podA/03_silver_to_gold_analytics
```

**Issues**:
- Hardcoded domain logic
- Need new notebook for each new domain
- Difficult to maintain consistency
- Duplicate code across domains

### New Notebooks (Enterprise-ready)

```
/Shared/podA/bronze_to_silver  (accepts domain parameter)
/Shared/podA/silver_to_gold    (accepts domain parameter)
```

**Benefits**:
- Single notebook handles all domains
- Domain passed as parameter from ADF
- Conditional logic for domain-specific rules
- Easy to add new domains (just add new if/elif block)

### Migration Steps

1. **Test new notebooks** with sample data
2. **Update ADF pipeline** to call new notebooks with dynamic path
3. **Run parallel** (old and new) for validation period
4. **Compare outputs** to ensure consistency
5. **Deprecate old notebooks** after validation
6. **Clean up** old notebooks from workspace

---

## Cost and Performance

### Cluster Usage (Same as before)

**Finance Company (2 domains)**:
- Check completeness: 1 cluster (1 min)
- Domain "hr": 2 clusters (Bronze→Silver + Silver→Gold, parallel)
- Domain "payroll": 2 clusters (Bronze→Silver + Silver→Gold, parallel)
- **Total**: 5 clusters, 11 minutes runtime

### Cost Tracking

**Cluster Tags** (configured in ADF):
```json
{
    "pod": "podA",
    "company": "finance",
    "domain": "hr",
    "notebook": "bronze_to_silver",
    "owner": "podA_team"
}
```

**Benefits**:
- Track costs per pod
- Track costs per company
- Track costs per domain
- Track costs per notebook
- Easy to identify expensive operations

---

## Summary

**Enterprise-Ready Architecture Features**:
- Pod-specific notebooks with clear ownership
- Team autonomy and isolation
- Business-specific customization
- Scalable to any number of pods
- Version control and code management
- Access control and governance
- Cost tracking per pod/company/domain

**Next Steps**:
1. Each pod team reviews their notebooks
2. Customize transformation logic for their business requirements
3. Set up Git integration for version control
4. Configure workspace permissions
5. Update ADF pipeline to use dynamic notebook paths
6. Test with sample data
7. Deprecate old domain-specific notebooks

This architecture is production-ready and follows enterprise best practices for multi-tenant data platforms.
