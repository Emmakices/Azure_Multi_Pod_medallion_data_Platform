#!/bin/bash
# Move all department resources to company resources in Terraform state

# Get all company keys
declare -a companies=("podA-finance" "podA-operations" "podA-marketing" "podA-it" "podB-finance" "podB-operations" "podB-sales" "podC-finance" "podC-hr_central" "podC-compliance")

# Move bronze, silver, gold company folders
for company in "${companies[@]}"; do
  echo "Moving $company..."
  terraform state mv "module.data_lake.azurerm_storage_data_lake_gen2_path.bronze_department[\"$company\"]" "module.data_lake.azurerm_storage_data_lake_gen2_path.bronze_company[\"$company\"]" 2>&1 | grep -i "success\|error"
  terraform state mv "module.data_lake.azurerm_storage_data_lake_gen2_path.silver_department[\"$company\"]" "module.data_lake.azurerm_storage_data_lake_gen2_path.silver_company[\"$company\"]" 2>&1 | grep -i "success\|error"
  terraform state mv "module.data_lake.azurerm_storage_data_lake_gen2_path.gold_department[\"$company\"]" "module.data_lake.azurerm_storage_data_lake_gen2_path.gold_company[\"$company\"]" 2>&1 | grep -i "success\|error"
done

# Move blob storage department folders to company folders
for company in "${companies[@]}"; do
  terraform state mv "module.source_blob_storage.azurerm_storage_blob.hr_department_folders[\"$company\"]" "module.source_blob_storage.azurerm_storage_blob.company_folders[\"$company\"]" 2>&1 | grep -i "success\|error" || true
  terraform state mv "module.source_blob_storage.azurerm_storage_blob.payroll_department_folders[\"$company\"]" "module.source_blob_storage.azurerm_storage_blob.company_folders[\"$company\"]" 2>&1 | grep -i "success\|error" || true
  terraform state mv "module.source_blob_storage.azurerm_storage_blob.finance_department_folders[\"$company\"]" "module.source_blob_storage.azurerm_storage_blob.company_folders[\"$company\"]" 2>&1 | grep -i "success\|error" || true
done

echo "✅ State migration complete"
