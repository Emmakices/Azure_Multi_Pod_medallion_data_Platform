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

            # Step 2: Download corresponding hash file
            $hashFileName = $blobName -replace '\.zip$', '.hash'
            $hashFilePath = Join-Path $tempDir $hashFileName
            Write-Host "Downloading hash file: $hashFileName"

            Download-Blob -StorageAccount $storageAccountName `
                -Container $testContainer `
                -BlobName $hashFileName `
                -AccountKey $accountKey `
                -DestinationPath $hashFilePath

            Write-Host "Hash file downloaded successfully (Size: $((Get-Item $hashFilePath).Length) bytes)"

            # Step 3: Extract ZIP file
            $extractDir = Join-Path $tempDir "extracted"
            New-Item -ItemType Directory -Path $extractDir -Force | Out-Null
            Write-Host "Extracting ZIP to: $extractDir"

            Expand-Archive -Path $zipFilePath -DestinationPath $extractDir -Force

            $extractedFiles = Get-ChildItem -Path $extractDir -Recurse -File
            Write-Host "Extracted $($extractedFiles.Count) files"

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

                # Step 6: Move to archive on success (optional)
                Write-Host "Validation PASSED - Files are valid"

                # TODO: Implement archiving logic
                # Copy-AzStorageBlob to archive container

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

            # ===================================================================
            # SEND EMAIL NOTIFICATION VIA LOGIC APP
            # ===================================================================
            $emailLogicAppUrl = $env:EMAIL_LOGIC_APP_URL
            $teamsWebhookUrl = $env:TEAMS_WEBHOOK_URL

            # Try Logic App email first, then Teams as fallback
            if ($emailLogicAppUrl) {
                try {
                    Write-Host "Sending email notification via Logic App..."

                    # Send validation results directly to Logic App
                    $emailBody = $validationResult | ConvertTo-Json -Depth 10

                    $emailResponse = Invoke-RestMethod -Uri $emailLogicAppUrl `
                                                       -Method Post `
                                                       -Body $emailBody `
                                                       -ContentType "application/json" `
                                                       -ErrorAction Stop

                    Write-Host "Email notification sent successfully via Logic App"

                } catch {
                    Write-Host "Failed to send email via Logic App: $_"
                    Write-Host "Logic App URL configured: $($null -ne $emailLogicAppUrl)"
                    # Don't fail the function if notification fails
                }
            } elseif ($teamsWebhookUrl) {
                try {
                    Write-Host "Sending Teams notification..."

                    # Set color and title based on status
                    if ($validationResult.status -eq "PASS") {
                        $themeColor = "28a745"  # Green
                        $title = "✅ Data Ready to Process"
                        $actionText = "**SAFE TO DOWNLOAD AND PROCESS**"
                    } else {
                        $themeColor = "dc3545"  # Red
                        $title = "❌ DO NOT PROCESS - Validation Failed"
                        $actionText = "**DO NOT DOWNLOAD OR PROCESS THIS FILE**"
                    }

                    # Build Teams message card
                    $teamsMessage = @{
                        "@type" = "MessageCard"
                        "@context" = "https://schema.org/extensions"
                        themeColor = $themeColor
                        title = $title
                        summary = "$($validationResult.zipFile) validation: $($validationResult.status)"
                        sections = @(
                            @{
                                activityTitle = "File: $($validationResult.zipFile)"
                                activitySubtitle = "Hash File: $($validationResult.hashFile)"
                                facts = @(
                                    @{ name = "Status"; value = $validationResult.status }
                                    @{ name = "Timestamp"; value = $validationResult.timestamp }
                                    @{ name = "Exit Code"; value = $validationResult.exitCode.ToString() }
                                    @{ name = "Files Extracted"; value = $validationResult.filesExtracted.ToString() }
                                    @{ name = "Files OK"; value = $validationResult.okCount.ToString() }
                                    @{ name = "Files Failed"; value = $validationResult.failCount.ToString() }
                                )
                                text = $actionText
                            },
                            @{
                                title = "Validation Details"
                                text = "``````$($validationResult.validationDetails)``````"
                            }
                        )
                    }

                    if ($validationResult.status -ne "PASS") {
                        # Add action steps for failed validation
                        $teamsMessage.sections += @{
                            title = "Action Required"
                            text = "1. Contact data provider (government)`n2. Report which files failed validation`n3. Request corrected data`n4. DO NOT process this file"
                        }
                    } else {
                        # Add next steps for passed validation
                        $teamsMessage.sections += @{
                            title = "Next Steps"
                            text = "1. Download ZIP from blob storage to F: drive`n2. Unzip the files`n3. Copy CSV files to correct folders`n4. Upload to blob storage in correct locations"
                        }
                    }

                    $teamsBody = $teamsMessage | ConvertTo-Json -Depth 10

                    # Send to Teams
                    $teamsResponse = Invoke-RestMethod -Uri $teamsWebhookUrl `
                                                       -Method Post `
                                                       -Body $teamsBody `
                                                       -ContentType "application/json" `
                                                       -ErrorAction Stop

                    Write-Host "Teams notification sent successfully"

                } catch {
                    Write-Host "Failed to send Teams notification: $_"
                    Write-Host "Teams webhook URL configured: $($null -ne $teamsWebhookUrl)"
                    # Don't fail the function if notification fails
                }
            } else {
                Write-Host "No notification method configured (Email Logic App or Teams webhook)"
            }

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
