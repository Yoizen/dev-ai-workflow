#requires -version 5.1
# Global Agents Extension — Windows
# Instala agents en todas las rutas de Copilot/Claude/Agents en Windows
param(
    [string]$TargetDir = "."
)

$ErrorActionPreference = 'Stop'

$projectType = $env:YWAI_PROJECT_TYPE
if (-not $projectType) { $projectType = 'generic' }

$extDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Join-Path $extDir '..\..\..'
$agentsSource = Join-Path $extDir 'templates'

Write-Host "Configuring global agents for project type: $projectType" -ForegroundColor Cyan

$homeDir = $env:USERPROFILE

if (-not (Test-Path $agentsSource)) {
    Write-Host "Agent templates not found: $agentsSource" -ForegroundColor Red
    exit 1
}

$agentLocations = @{
    "OpenCode" = Join-Path $homeDir ".config\opencode\agents"
    "Copilot"  = Join-Path $homeDir ".copilot\agents"
    "Claude"   = Join-Path $homeDir ".claude\agents"
    "Agents"   = Join-Path $homeDir ".agents\agents"
}

$copiedTotal = 0

foreach ($platformName in $agentLocations.Keys) {
    $destDir = $agentLocations[$platformName]
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null

    Get-ChildItem -Path $destDir -Filter '*.md' -ErrorAction SilentlyContinue | Remove-Item -Force - ErrorAction SilentlyContinue

    Get-ChildItem -Path $agentsSource -Filter '*.md' | ForEach-Object {
        $dest = Join-Path $destDir $_.Name
        Copy-Item -Force $_.FullName $dest
        $copiedTotal++
        Write-Host "  [$platformName] Installed agent: $($_.Name)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Global agents configured ($copiedTotal templates copied)" -ForegroundColor Green
Write-Host ""
Write-Host "Locations:" -ForegroundColor White
foreach ($platformName in $agentLocations.Keys) {
    Write-Host "  $platformName : $($agentLocations[$platformName])" -ForegroundColor Gray
}
