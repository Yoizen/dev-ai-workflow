#requires -version 5.1
# Biome Baseline Extension — Windows
param(
    [string]$TargetDir = "."
)

$ErrorActionPreference = 'Stop'

$BiomeConfig = Join-Path $TargetDir 'biome.json'
$PackageJson = Join-Path $TargetDir 'package.json'

if (Test-Path $BiomeConfig) {
    Write-Host "biome.json already exists, skipping"
    exit 0
}

# Read template from extension directory
$extDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$template = Join-Path $extDir 'biome.json'

if (-not (Test-Path $template)) {
    Write-Error "biome.json template not found at $template"
    exit 1
}

Copy-Item -Force $template $BiomeConfig
Write-Host "Created biome.json baseline"

# Add to package.json if it exists
if ((Test-Path $PackageJson) -and (Get-Command npm -ErrorAction SilentlyContinue)) {
    try {
        npm install --save-dev @biomejs/biome 2>$null | Out-Null
        Write-Host "Installed @biomejs/biome"
    } catch {
        Write-Host "Warning: failed to install @biomejs/biome" -ForegroundColor Yellow
    }
}
