# Fix broken ADF datasets

$resourceGroup = "rg-platform-dev"
$factoryName = "adf-dev-platform"

# Fix ds_staging_binary
Write-Host "Fixing ds_staging_binary..."
az datafactory dataset create `
  --resource-group $resourceGroup `
  --factory-name $factoryName `
  --name ds_staging_binary `
  --properties '{
    "linkedServiceName": {
      "referenceName": "LS_BlobStorage",
      "type": "LinkedServiceReference"
    },
    "parameters": {
      "company": {
        "type": "string"
      },
      "fileName": {
        "type": "string"
      }
    },
    "type": "Binary",
    "typeProperties": {
      "location": {
        "type": "AzureBlobStorageLocation",
        "fileName": {
          "value": "@dataset().fileName",
          "type": "Expression"
        },
        "folderPath": {
          "value": "@dataset().company",
          "type": "Expression"
        },
        "container": "staging"
      }
    }
  }'

Write-Host ""
Write-Host "Fixing ds_processed_binary..."
az datafactory dataset create `
  --resource-group $resourceGroup `
  --factory-name $factoryName `
  --name ds_processed_binary `
  --properties '{
    "linkedServiceName": {
      "referenceName": "LS_BlobStorage",
      "type": "LinkedServiceReference"
    },
    "parameters": {
      "company": {
        "type": "string"
      },
      "department": {
        "type": "string"
      },
      "fileName": {
        "type": "string"
      }
    },
    "type": "Binary",
    "typeProperties": {
      "location": {
        "type": "AzureBlobStorageLocation",
        "fileName": {
          "value": "@dataset().fileName",
          "type": "Expression"
        },
        "folderPath": {
          "value": "@concat(dataset().company, '\''/'\'', dataset().department)",
          "type": "Expression"
        },
        "container": "processed-test"
      }
    }
  }'

Write-Host ""
Write-Host "Done! Verify in Azure Portal."
