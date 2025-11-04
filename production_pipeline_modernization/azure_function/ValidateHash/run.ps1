using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Initialize response
$statusCode = [HttpStatusCode]::OK
$body = @{}

try {
    # Get environment variables
    $storageConnectionString = $env:DATA_STORAGE_CONNECTION_STRING
    $testContainer = $env:TEST_CONTAINER_NAME
    $archiveContainer = $env:ARCHIVE_CONTAINER_NAME
    $validationTempContainer = $env:VALIDATION_TEMP_CONTAINER_NAME

    Write-Host "Environment variables loaded successfully"

    # Parse request body
    $eventGridEvent = $Request.Body

    # Check if this is an Event Grid validation request
    if ($eventGridEvent -and $eventGridEvent[0].eventType -eq 'Microsoft.EventGrid.SubscriptionValidationEvent') {
        Write-Host "Event Grid subscription validation request received"
        $validationCode = $eventGridEvent[0].data.validationCode
        $body = @{ validationResponse = $validationCode }
        $statusCode = [HttpStatusCode]::OK
    }
    # Check if this is a blob created event
    elseif ($eventGridEvent -and $eventGridEvent[0].eventType -eq 'Microsoft.Storage.BlobCreated') {
        Write-Host "Blob created event received"

        $blobUrl = $eventGridEvent[0].data.url
        $blobName = $eventGridEvent[0].data.url -replace '.*/', ''

        Write-Host "Processing ZIP file: $blobName"
        Write-Host "Blob URL: $blobUrl"

        # ===================================================================
        # FULL VALIDATION LOGIC IMPLEMENTATION
        # ===================================================================

        # Create temp directory for processing
        $tempDir = Join-Path $env:TEMP "hash_validation_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
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

            # Step 1: Download ZIP file from test container
            $zipFilePath = Join-Path $tempDir $blobName
            Write-Host "Downloading ZIP file to: $zipFilePath"

            Download-Blob -StorageAccount $storageAccountName `
                -Container $testContainer `
                -BlobName $blobName `
                -AccountKey $accountKey `
                -DestinationPath $zipFilePath

            Write-Host "ZIP file downloaded successfully (Size: $((Get-Item $zipFilePath).Length) bytes)"

            # Step 2: Extract ZIP file first
            $extractDir = Join-Path $tempDir "extracted"
            New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
            Write-Host "Extracting ZIP to: $extractDir"

            Expand-Archive -Path $zipFilePath -DestinationPath $extractDir -Force

            $extractedFiles = Get-ChildItem -Path $extractDir -Recurse -File
            Write-Host "Extracted $($extractedFiles.Count) files"

            # Step 3: Look for hash file inside extracted folder first
            $hashFileInZip = Get-ChildItem -Path $extractDir -Filter "*.hash" -File | Select-Object -First 1

            if ($hashFileInZip) {
                # Hash file found inside ZIP
                $hashFilePath = $hashFileInZip.FullName
                Write-Host "✅ Hash file found inside ZIP: $($hashFileInZip.Name)"
            } else {
                # Hash file not in ZIP, download from blob storage (legacy behavior)
                Write-Host "Hash file not found inside ZIP, downloading from blob storage..."
                $hashFileName = $blobName -replace '\.zip$', '.hash'
                $hashFilePath = Join-Path $tempDir $hashFileName

                Download-Blob -StorageAccount $storageAccountName `
                    -Container $testContainer `
                    -BlobName $hashFileName `
                    -AccountKey $accountKey `
                    -DestinationPath $hashFilePath

                Write-Host "Hash file downloaded from blob storage (Size: $((Get-Item $hashFilePath).Length) bytes)"
            }

            # Step 4: Run hash.ps1 validation
            $hashScriptPath = Join-Path $PSScriptRoot "hash.ps1"
            $validationOutputFile = Join-Path $tempDir "validation_results.txt"

            Write-Host "Running hash validation script..."
            Write-Host "Hash script: $hashScriptPath"
            Write-Host "Hash file: $hashFilePath"
            Write-Host "Extract dir: $extractDir"

            # Run validation directly in current PowerShell session
            Write-Host "Running validation script..."
            try {
                & $hashScriptPath -Mode Validate -HashFile $hashFilePath -RootPath $extractDir -OutputFile $validationOutputFile -Silent
                $exitCode = $LASTEXITCODE
                Write-Host "Validation script exit code: $exitCode"
            }
            catch {
                Write-Host "Error running validation script: $_"
                $exitCode = 1
            }

            # Read validation output
            $validationOutput = ""
            if (Test-Path $validationOutputFile) {
                $validationOutput = Get-Content $validationOutputFile -Raw
                Write-Host "Validation output:`n$validationOutput"
            }

            # Step 5: Parse results
            $validationResult = @{
                exitCode = $exitCode
                timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                zipFile = $blobName
                hashFile = $hashFileName
                filesExtracted = $extractedFiles.Count
            }

            # Extract summary from validation output
            if ($validationOutput -match 'SUMMARY: OK=(\d+) FAIL=(\d+) MISSING=(\d+) EXTRA=(\d+)') {
                $validationResult.okCount = [int]$Matches[1]
                $validationResult.failCount = [int]$Matches[2]
                $validationResult.missingCount = [int]$Matches[3]
                $validationResult.extraCount = [int]$Matches[4]
            }

            # Determine overall status based on exit code
            # Exit code 0 = Success
            # Exit code 3 = Validation issues (FAIL/MISSING/EXTRA files)
            # Exit code 2 = File/folder not found
            # Exit code 1 = Usage/parameter error

            if ($exitCode -eq 0) {
                $validationResult.status = "PASS"
                $validationResult.message = "All files validated successfully"

                # Step 6: Trigger ADF Pipeline on successful validation
                Write-Host "Validation PASSED - Triggering ADF pipeline"

                try {
                    # Get ADF configuration from environment
                    $adfResourceGroup = $env:ADF_RESOURCE_GROUP
                    $adfFactoryName = $env:ADF_FACTORY_NAME
                    $adfPipelineName = $env:ADF_PIPELINE_NAME
                    $subscriptionId = $env:AZURE_SUBSCRIPTION_ID

                    if (-not $adfResourceGroup -or -not $adfFactoryName -or -not $adfPipelineName) {
                        Write-Host "WARNING: ADF configuration not found in environment variables. Using defaults."
                        $adfResourceGroup = "rg-platform-dev"
                        $adfFactoryName = "adf-dev-platform"
                        $adfPipelineName = "pl_HRPayroll_ExcelLoad"
                        $subscriptionId = "e97fa8c6-457d-495f-aa82-0d87e72f5842"
                    }

                    # Build ADF REST API URL
                    $adfUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$adfResourceGroup/providers/Microsoft.DataFactory/factories/$adfFactoryName/pipelines/$adfPipelineName/createRun?api-version=2018-06-01"

                    # Get access token using managed identity
                    $tokenResponse = Invoke-RestMethod -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://management.azure.com/" -Headers @{Metadata="true"} -Method GET
                    $accessToken = $tokenResponse.access_token

                    # Prepare pipeline parameters
                    $pipelineParams = @{
                        zipFileName = $blobName
                    } | ConvertTo-Json

                    # Trigger ADF pipeline
                    $headers = @{
                        "Authorization" = "Bearer $accessToken"
                        "Content-Type" = "application/json"
                    }

                    Write-Host "Triggering ADF pipeline: $adfPipelineName with file: $blobName"
                    $adfResponse = Invoke-RestMethod -Uri $adfUrl -Method POST -Headers $headers -Body $pipelineParams

                    $validationResult.adfPipelineTriggered = $true
                    $validationResult.adfRunId = $adfResponse.runId
                    Write-Host "ADF Pipeline triggered successfully. Run ID: $($adfResponse.runId)"

                } catch {
                    Write-Host "ERROR triggering ADF pipeline: $_"
                    $validationResult.adfPipelineTriggered = $false
                    $validationResult.adfError = $_.Exception.Message
                }

            } elseif ($exitCode -eq 3) {
                $validationResult.status = "FAIL"
                $validationResult.message = "Validation failed: Hash mismatch or file discrepancies found"
                Write-Host "Validation FAILED - Hash mismatches detected" -ForegroundColor Yellow

            } elseif ($exitCode -eq 2) {
                $validationResult.status = "ERROR"
                $validationResult.message = "Validation error: Required files or folders not found"
                Write-Host "Validation ERROR - Files not found" -ForegroundColor Red

            } else {
                $validationResult.status = "ERROR"
                $validationResult.message = "Validation error: Unexpected exit code $exitCode"
                Write-Host "Validation ERROR - Unexpected exit code" -ForegroundColor Red
            }

            $validationResult.validationDetails = $validationOutput

            # Build response
            $body = $validationResult

            Write-Host "Validation completed with status: $($validationResult.status)"

        } finally {
            # Step 7: Cleanup temp files
            if (Test-Path $tempDir) {
                Write-Host "Cleaning up temp directory: $tempDir"
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "Cleanup completed"
            }
        }

        Write-Host "Validation process completed for: $blobName"
    }
    # Handle manual/test invocations
    else {
        Write-Host "Manual test invocation"
        $body = @{
            status = "success"
            message = "Hash validation function is running"
            timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            environment = @{
                storageConfigured = ($null -ne $storageConnectionString)
                dflinkContainer = $testContainer
                archiveContainer = $archiveContainer
                validationTempContainer = $validationTempContainer
            }
        }
    }

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
