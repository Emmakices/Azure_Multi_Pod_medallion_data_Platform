$files = Get-ChildItem -Path valid_files -File | Sort-Object Name
$hashes = @()
foreach ($file in $files) {
    $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA512).Hash.ToLower()
    $hashes += "$hash|$($file.Name)"
    Write-Host "$($file.Name): $hash"
}
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllLines("$PSScriptRoot\valid_data_2025-10-28_NEW.hash", $hashes, $utf8NoBom)
Write-Host "Hash file created: valid_data_2025-10-28_NEW.hash"
