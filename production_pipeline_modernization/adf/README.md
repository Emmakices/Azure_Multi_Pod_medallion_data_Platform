# ADF Pipelines Folder

This folder will contain:

## Exported Pipelines
- `entry_hr_pipeline.json` - Current ENTRY HR pipeline
- `core_hr_pipeline.json` - Current CORE HR pipeline
- `validate_and_extract_pipeline.json` - NEW: Validation & extraction pipeline

## Linked Services
- `ls_blob_storage.json` - Blob storage linked service
- `ls_database.json` - Database linked service
- `ls_databricks.json` - Databricks linked service (if used)

## Datasets
- `ds_excel_files.json` - Excel file dataset
- `ds_database_tables.json` - Database table dataset

## Triggers
- `trg_event_grid.json` - Event Grid trigger configuration
- `trg_scheduled.json` - Scheduled trigger (if needed)

---

**How to Export from ADF Studio:**

1. Open ADF Studio
2. Go to pipeline
3. Click {} (Code button) in top right
4. Copy JSON
5. Save as file in this folder

**Status**: Awaiting export from user

**Next**: User to export ENTRY HR and CORE HR pipelines
