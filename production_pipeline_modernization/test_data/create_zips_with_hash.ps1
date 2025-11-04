# Create ZIPs with hash files included

# Create temp directories
$tempGood = 'temp_good_with_hash'
$tempBad = 'temp_bad_with_hash'
New-Item -ItemType Directory -Path $tempGood -Force | Out-Null
New-Item -ItemType Directory -Path $tempBad -Force | Out-Null

Write-Host "Creating good data ZIP with hash inside..."

# Extract good files
Expand-Archive -Path 'valid_data_2025-10-28.zip' -DestinationPath $tempGood -Force

# Copy hash file into extracted folder
Copy-Item 'valid_data_2025-10-28.hash' -Destination $tempGood

# Delete old ZIP if it exists
if (Test-Path 'valid_data_with_hash_2025-10-28.zip') {
    Remove-Item 'valid_data_with_hash_2025-10-28.zip' -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# Create new ZIP with hash inside
Compress-Archive -Path "$tempGood\*" -DestinationPath 'valid_data_with_hash_2025-10-28.zip' -Force

Write-Host "✅ Created: valid_data_with_hash_2025-10-28.zip"

Write-Host "Creating corrupted data ZIP with hash inside..."

# Extract corrupted files
Expand-Archive -Path 'corrupted_data_2025-10-28.zip' -DestinationPath $tempBad -Force

# Copy hash file into extracted folder
Copy-Item 'corrupted_data_2025-10-28.hash' -Destination $tempBad

# Delete old ZIP if it exists
if (Test-Path 'corrupted_data_with_hash_2025-10-28.zip') {
    Remove-Item 'corrupted_data_with_hash_2025-10-28.zip' -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# Create new ZIP with hash inside
Compress-Archive -Path "$tempBad\*" -DestinationPath 'corrupted_data_with_hash_2025-10-28.zip' -Force

Write-Host "✅ Created: corrupted_data_with_hash_2025-10-28.zip"

# Cleanup temp directories
Remove-Item -Path $tempGood -Recurse -Force
Remove-Item -Path $tempBad -Recurse -Force

Write-Host "✅ Cleanup complete"
Write-Host ""
Write-Host "Summary:"
Write-Host "  - valid_data_with_hash_2025-10-28.zip (contains: 3 CSV files + hash file)"
Write-Host "  - corrupted_data_with_hash_2025-10-28.zip (contains: 3 CSV files + hash file)"
