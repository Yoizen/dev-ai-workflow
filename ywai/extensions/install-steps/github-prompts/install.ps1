#requires -version 5.1
# GitHub Prompts Extension — Windows
param(
    [string]$TargetDir = "."
)

$ErrorActionPreference = 'Stop'

$extDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceDir = Join-Path $extDir 'prompts'
$targetPromptsDir = Join-Path $TargetDir '.github\prompts'

if (-not (Test-Path $sourceDir)) {
    Write-Host "Prompts source not found: $sourceDir"
    exit 1
}

New-Item -ItemType Directory -Force -Path $targetPromptsDir | Out-Null

$copied = 0
Get-ChildItem -Path $sourceDir -Filter '*.md' | ForEach-Object {
    $dest = Join-Path $targetPromptsDir $_.Name
    if (-not (Test-Path $dest)) {
        Copy-Item -Force $_.FullName $dest
        $copied++
    }
}

Write-Host "Installed $copied GitHub prompt file(s) into .github\prompts"
