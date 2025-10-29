# rename all files to lowercase
$files = Get-ChildItem -Path . -Filter '*.md' -Recurse | Where-Object { $_.Name -cmatch '[A-Z_]' }

foreach ($file in $files) {
    $newName = $file.Name.ToLower().Replace('_', '-')
    if ($file.Name -ne $newName) {
        $newPath = Join-Path $file.Directory $newName
        if (Test-Path $newPath) {
            Write-Host "Skipping $($file.Name) - target already exists"
        } else {
            Rename-Item -Path $file.FullName -NewName $newName -Force
            Write-Host "Renamed: $($file.Name) -> $newName"
        }
    }
}

Write-Host "Done renaming files to lowercase"
