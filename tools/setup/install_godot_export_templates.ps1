param(
    [string]$VersionTag = "4.6-stable",
    [string]$TemplatesRoot = "$env:APPDATA\Godot\export_templates"
)

$ErrorActionPreference = "Stop"

$versionFolder = $VersionTag -replace "-", "."
$url = "https://github.com/godotengine/godot/releases/download/$VersionTag/Godot_v$VersionTag`_export_templates.tpz"
$targetDir = Join-Path $TemplatesRoot $versionFolder
$stamp = Get-Date -Format "yyyyMMddHHmmss"
$tempTpz = Join-Path $env:TEMP "Godot_v$VersionTag`_export_templates_$stamp.tpz"
$tempZip = Join-Path $env:TEMP "Godot_v$VersionTag`_export_templates_$stamp.zip"
$extractDir = Join-Path $env:TEMP "godot_templates_$versionFolder"

Write-Host "Downloading templates from $url"
Invoke-WebRequest -Uri $url -OutFile $tempTpz

if (Test-Path $extractDir) {
    Remove-Item -Recurse -Force $extractDir
}
New-Item -ItemType Directory -Force -Path $extractDir | Out-Null

Copy-Item $tempTpz $tempZip -Force
Expand-Archive -Path $tempZip -DestinationPath $extractDir -Force

New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
Copy-Item -Path (Join-Path $extractDir "*") -Destination $targetDir -Recurse -Force

# Godot on Windows can expect templates directly under the version folder.
$nestedTemplates = Join-Path $targetDir "templates"
if (Test-Path $nestedTemplates) {
    Copy-Item -Path (Join-Path $nestedTemplates "*") -Destination $targetDir -Recurse -Force
}

Write-Host "Installed export templates to: $targetDir"
