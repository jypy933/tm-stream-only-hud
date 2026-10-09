# Builds dist\StreamOnlyHUD.op (a zip with info.toml at the root), ready to upload to openplanet.dev.
# Usage: right-click > Run with PowerShell, or:  powershell -ExecutionPolicy Bypass -File pack.ps1
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$root = $PSScriptRoot
$dist = Join-Path $root "dist"
$out  = Join-Path $dist "StreamOnlyHUD.op"
New-Item -ItemType Directory -Force $dist | Out-Null
if (Test-Path $out) { Remove-Item $out }

$files = @("info.toml", "overlay.html") + (Get-ChildItem (Join-Path $root "src") -Filter *.as | ForEach-Object { "src/" + $_.Name })

$zip = [System.IO.Compression.ZipFile]::Open($out, "Create")
try {
    foreach ($f in $files) {
        # Forward slashes inside the archive: Openplanet expects zip-style paths.
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $root $f), $f) | Out-Null
    }
} finally {
    $zip.Dispose()
}
Write-Host "Built $out ($($files.Count) files)"
