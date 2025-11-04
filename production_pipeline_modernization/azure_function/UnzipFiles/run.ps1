using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request - UnzipFiles"

# Initialize response
$statusCode = [HttpStatusCode]::OK
$body = @{}

try {
    # Get environment variables
    $storageConnectionString = $env:DATA_STORAGE_CONNECTION_STRING

    if (-not $storageConnectionString) {
        throw "Storage connection string not configured"
    }

    Write-Host "Environment variables loaded successfully"

    # Get parameters from query string or body
    $zipBlob = $Request.Query.zipBlob
    if (-not $zipBlob) {
        $zipBlob = $Request.Body.zipBlob
    }

    $sourceContainer = $Request.Query.sourceContainer
    if (-not $sourceContainer) {
        $sourceContainer = $Request.Body.sourceContainer
    }
    if (-not $sourceContainer) {
        $sourceContainer = "landingtest"  # Default
    }

    $targetContainer = $Request.Query.targetContainer
    if (-not $targetContainer) {
        $targetContainer = $Request.Body.targetContainer
    }
    if (-not $targetContainer) {
        $targetContainer = "staging"  # Default
    }

    if (-not $zipBlob) {
        throw "zipBlob parameter is required"
    }

    Write-Host "Processing ZIP file: $zipBlob"
    Write-Host "Source container: $sourceContainer"
    Write-Host "Target container: $targetContainer"

    # Create temp directory for processing
    $tempDir = Join-Path $env:TEMP "unzip_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-Host "Created temp directory: $tempDir"

    try {
        # Extract storage account name from connection string
        if ($storageConnectionString -match 'AccountName=([^;]+)') {
            $storageAccountName = $Matches[1]
        } else {
            throw "Could not extract storage account name from connection string"
        }

        # Parse account key from connection string
        if ($storageConnectionString -match 'AccountKey=([^;]+)') {
            $accountKey = $Matches[1]
            Write-Host "Account key extracted successfully"
        } else {
            throw "Could not extract account key from connection string"
        }

        # Helper function to download blob using REST API
        function Download-Blob {
            param(
                [string]$StorageAccount,
                [string]$Container,
                [string]$BlobName,
                [string]$AccountKey,
                [string]$DestinationPath
            )

            $url = "https://$StorageAccount.blob.core.windows.net/$Container/$BlobName"
            $date = [DateTime]::UtcNow.ToString("R")
            $stringToSign = "GET`n`n`n`n`n`n`n`n`n`n`n`nx-ms-blob-type:BlockBlob`nx-ms-date:$date`nx-ms-version:2021-08-06`n/$StorageAccount/$Container/$BlobName"

            $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
            $hmacsha.Key = [Convert]::FromBase64String($AccountKey)
            $signature = [Convert]::ToBase64String($hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign)))

            $headers = @{
                "x-ms-date" = $date
                "x-ms-version" = "2021-08-06"
                "Authorization" = "SharedKey $StorageAccount`:$signature"
                "x-ms-blob-type" = "BlockBlob"
            }

            Invoke-WebRequest -Uri $url -Method GET -Headers $headers -OutFile $DestinationPath
        }

        # Helper function to upload blob using REST API
        function Upload-Blob {
            param(
                [string]$StorageAccount,
                [string]$Container,
                [string]$BlobName,
                [string]$AccountKey,
                [string]$FilePath
            )

            $url = "https://$StorageAccount.blob.core.windows.net/$Container/$BlobName"
            $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
            $contentLength = $fileBytes.Length

            $date = [DateTime]::UtcNow.ToString("R")
            $stringToSign = "PUT`n`n`n$contentLength`n`napplication/octet-stream`n`n`n`n`n`n`nx-ms-blob-type:BlockBlob`nx-ms-date:$date`nx-ms-version:2021-08-06`n/$StorageAccount/$Container/$BlobName"

            $hmacsha = New-Object System.Security.Cryptography.HMACSHA256
            $hmacsha.Key = [Convert]::FromBase64String($AccountKey)
            $signature = [Convert]::ToBase64String($hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($stringToSign)))

            $headers = @{
                "x-ms-date" = $date
                "x-ms-version" = "2021-08-06"
                "x-ms-blob-type" = "BlockBlob"
                "Authorization" = "SharedKey $StorageAccount`:$signature"
                "Content-Type" = "application/octet-stream"
                "Content-Length" = $contentLength
            }

            Invoke-RestMethod -Uri $url -Method PUT -Headers $headers -Body $fileBytes
        }

        # Step 1: Download ZIP file from source container
        $zipFilePath = Join-Path $tempDir $zipBlob
        Write-Host "Downloading ZIP file to: $zipFilePath"

        Download-Blob -StorageAccount $storageAccountName `
            -Container $sourceContainer `
            -BlobName $zipBlob `
            -AccountKey $accountKey `
            -DestinationPath $zipFilePath

        Write-Host "ZIP file downloaded successfully (Size: $((Get-Item $zipFilePath).Length) bytes)"

        # Step 2: Extract ZIP file
        $extractDir = Join-Path $tempDir "extracted"
        New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
        Write-Host "Extracting ZIP to: $extractDir"

        Expand-Archive -Path $zipFilePath -DestinationPath $extractDir -Force

        $extractedFiles = Get-ChildItem -Path $extractDir -Recurse -File
        Write-Host "Extracted $($extractedFiles.Count) files"

        # Step 3: Upload all extracted files to target container preserving folder structure
        $uploadedCount = 0
        $uploadedFiles = @()

        foreach ($file in $extractedFiles) {
            # Get relative path from extract dir
            $relativePath = $file.FullName.Substring($extractDir.Length).TrimStart('\', '/')
            # Convert backslashes to forward slashes for blob storage
            $blobPath = $relativePath -replace '\\', '/'

            Write-Host "Uploading: $blobPath"

            Upload-Blob -StorageAccount $storageAccountName `
                -Container $targetContainer `
                -BlobName $blobPath `
                -AccountKey $accountKey `
                -FilePath $file.FullName

            $uploadedCount++
            $uploadedFiles += $blobPath
        }

        Write-Host "Successfully uploaded $uploadedCount files to $targetContainer container"

        # Build success response
        $body = @{
            status = "success"
            message = "ZIP file extracted and uploaded successfully"
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            zipFile = $zipBlob
            sourceContainer = $sourceContainer
            targetContainer = $targetContainer
            filesExtracted = $extractedFiles.Count
            filesUploaded = $uploadedCount
            uploadedFiles = $uploadedFiles
        }

    } finally {
        # Cleanup temp files
        if (Test-Path $tempDir) {
            Write-Host "Cleaning up temp directory: $tempDir"
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Cleanup completed"
        }
    }

    Write-Host "Unzip process completed for: $zipBlob"

} catch {
    Write-Host "ERROR: $_"
    Write-Host "Stack Trace: $($_.ScriptStackTrace)"

    $statusCode = [HttpStatusCode]::InternalServerError
    $body = @{
        status = "error"
        message = $_.Exception.Message
        stackTrace = $_.ScriptStackTrace
        timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
    StatusCode = $statusCode
    Body = ($body | ConvertTo-Json -Depth 10)
    Headers = @{
        "Content-Type" = "application/json"
    }
})
