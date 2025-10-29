$files = Get-ChildItem -Path test_extract -File | Sort-Object Name
$hashes = @()
foreach ($file in $files) {
    $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA512).Hash.ToLower()
    $hashes += "$hash|$($file.Name)"
    Write-Host "$($file.Name): $hash"
}
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines("$PSScriptRoot\valid_data_2025-10-28.hash", $hashes, $utf8NoBom)
Write-Host "Hash file generated without BOM from extracted files"
