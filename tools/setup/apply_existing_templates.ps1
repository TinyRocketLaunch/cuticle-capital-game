param(
    [string]$TpzPath = "$env:TEMP\Godot_v4.6-stable_export_templates.tpz",
    [string]$VersionFolder = "4.6.stable",
    [string]$TemplatesRoot = "$env:APPDATA\Godot\export_templates"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $TpzPath)) {
    throw "Template archive not found at $TpzPath"
}

$tempZip = [System.IO.Path]::ChangeExtension($TpzPath, ".zip")
$extractDir = Join-Path $env:TEMP ("godot_templates_extract_" + (Get-Random))
$targetDir = Join-Path $TemplatesRoot $VersionFolder

Copy-Item $TpzPath $tempZip -Force
New-Item -ItemType Directory -Force -Path $extractDir | Out-Null
Expand-Archive -Path $tempZip -DestinationPath $extractDir -Force

New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
Copy-Item -Path (Join-Path $extractDir "*") -Destination $targetDir -Recurse -Force

Write-Host "Installed templates into $targetDir"
Get-ChildItem -Path $targetDir -File | Select-Object Name,Length | Format-Table -AutoSize
