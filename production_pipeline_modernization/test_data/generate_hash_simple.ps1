# Simple hash generator compatible with PowerShell 5.x
param(
    [string]$FolderPath,
    [string]$OutputFile
)

$folder = Resolve-Path $FolderPath
$results = @()
$results += "# Root: $((Split-Path $folder -Leaf))"

$files = Get-ChildItem -Path $folder -File -Recurse
foreach ($file in $files) {
    $relPath = $file.FullName.Substring($folder.Path.Length).TrimStart("\")
    $hash = (Get-FileHash -Path $file.FullName -Algorithm SHA512).Hash.ToLower()
    $results += "$hash|$relPath"
    Write-Host "HASHED: $relPath" -ForegroundColor Green
}

$results | Out-File -FilePath $OutputFile -Encoding utf8
Write-Host "`nHash file created: $OutputFile" -ForegroundColor Cyan
