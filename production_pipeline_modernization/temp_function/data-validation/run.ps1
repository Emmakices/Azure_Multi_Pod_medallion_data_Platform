using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "Data Validation function processed a request."

# Get parameters from request
$dataBlob = $Request.Query.dataBlob
$hashBlob = $Request.Query.hashBlob
$storageAccount = $Request.Query.storageAccount
$container = $Request.Query.container

# Initialize response
$statusCode = [HttpStatusCode]::OK
$body = @{
    status = "success"
    message = "Data Validation function is running"
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
}

# Function to download blob using REST API
function Download-AzureBlob {
    param(
        [string]$StorageAccount,
        [string]$Container,
        [string]$BlobName,
        [string]$StorageKey,
        [string]$DestinationPath
    )

    $uri = "https://$StorageAccount.blob.core.windows.net/$Container/$BlobName"
    $date = [DateTime]::UtcNow.ToString("R", [System.Globalization.CultureInfo]::InvariantCulture)
    $stringToSign = "GET`n`n`n`n`n`n`n`n`n`n`n`nx-ms-date:$date`nx-ms-version:2021-08-06`n/$StorageAccount/$Container/$BlobName"

    $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
    $hmacsha.Key = [Convert]::FromBase64String($StorageKey)
    $signature = [Convert]::ToBase64String($hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign)))

    $headers = @{
        "x-ms-date" = $date
        "x-ms-version" = "2021-08-06"
        "Authorization" = "SharedKey $StorageAccount`:$signature"
    }

    Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -OutFile $DestinationPath
}

# If validation parameters provided, perform validation
if ($dataBlob -and $hashBlob -and $storageAccount -and $container) {
    try {
        Write-Host "Starting validation process..."
        Write-Host "Storage Account: $storageAccount"
        Write-Host "Container: $container"
        Write-Host "Data Blob: $dataBlob"
        Write-Host "Hash Blob: $hashBlob"

        # Create temp directory
        $tempDir = Join-Path $env:TEMP "validation_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        Write-Host "Created temp directory: $tempDir"

        # Get storage account key from environment variable
        $storageKey = $env:STORAGE_ACCOUNT_KEY
        if (-not $storageKey) {
            throw "Storage account key not found in environment variables"
        }

        # Download data blob
        $dataPath = Join-Path $tempDir $dataBlob
        Write-Host "Downloading $dataBlob..."
        Download-AzureBlob -StorageAccount $storageAccount -Container $container -BlobName $dataBlob -StorageKey $storageKey -DestinationPath $dataPath
        Write-Host "Downloaded data blob to: $dataPath"

        # Download hash blob
        $hashPath = Join-Path $tempDir $hashBlob
        Write-Host "Downloading $hashBlob..."
        Download-AzureBlob -StorageAccount $storageAccount -Container $container -BlobName $hashBlob -StorageKey $storageKey -DestinationPath $hashPath
        Write-Host "Downloaded hash blob to: $hashPath"

        # Extract zip file
        $extractPath = Join-Path $tempDir "extracted"
        Write-Host "Extracting $dataBlob..."
        Expand-Archive -Path $dataPath -DestinationPath $extractPath -Force
        Write-Host "Extracted to: $extractPath"

        # Auto-detect wrapper folder
        # If the extracted content has only one subfolder and no files, use that subfolder as root
        $items = Get-ChildItem -Path $extractPath
        if ($items.Count -eq 1 -and $items[0].PSIsContainer) {
            $actualRoot = $items[0].FullName
            Write-Host "Detected wrapper folder: $($items[0].Name). Using it as root for validation."
        } else {
            $actualRoot = $extractPath
            Write-Host "No wrapper folder detected. Using extract path as root."
        }

        # Run validation
        $hashScriptPath = Join-Path $PSScriptRoot "hash.ps1"
        $validationOutput = Join-Path $tempDir "validation_result.txt"
        Write-Host "Running validation script..."

        # Capture validation output
        $validationResult = & $hashScriptPath -Mode Validate -HashFile $hashPath -RootPath $actualRoot -OutputFile $validationOutput -Silent
        $exitCode = $LASTEXITCODE

        # Read validation results
        $validationContent = Get-Content $validationOutput -Raw

        Write-Host "Validation completed with exit code: $exitCode"
        Write-Host "Validation output:`n$validationContent"

        # Clean up temp directory
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue

        # Prepare response based on exit code
        if ($exitCode -eq 0) {
            $body = @{
                status = "success"
                message = "Validation passed - all files are valid"
                exitCode = $exitCode
                validationDetails = $validationContent
                timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }
        elseif ($exitCode -eq 3) {
            $body = @{
                status = "validation_failed"
                message = "Validation completed with issues"
                exitCode = $exitCode
                validationDetails = $validationContent
                timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
            $statusCode = [HttpStatusCode]::BadRequest
        }
        else {
            $body = @{
                status = "error"
                message = "Validation error occurred"
                exitCode = $exitCode
                validationDetails = $validationContent
                timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
            $statusCode = [HttpStatusCode]::InternalServerError
        }
    }
    catch {
        Write-Host "ERROR: $($_.Exception.Message)"
        $body = @{
            status = "error"
            message = "Validation failed with exception"
            error = $_.Exception.Message
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        }
        $statusCode = [HttpStatusCode]::InternalServerError
    }
}
else {
    $body.message = "Data Validation function is ready. Provide dataBlob, hashBlob, storageAccount, and container parameters to validate."
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $statusCode
    Body = ($body | ConvertTo-Json -Depth 10)
    Headers = @{
        "Content-Type" = "application/json"
    }
})
