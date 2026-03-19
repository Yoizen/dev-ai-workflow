#requires -version 5.1
# Global Agents Extension — Windows
param(
    [string]$TargetDir = "."
)

$ErrorActionPreference = 'Stop'

$projectType = $env:YWAI_PROJECT_TYPE
if (-not $projectType) { $projectType = 'generic' }

$extDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Join-Path $extDir '..\..\..'
$skillsSetup = Join-Path $repoRoot 'skills\setup.sh'

# On Windows, run global agents setup via Go wizard's built-in logic
# The Go installer already handles agent file generation natively
Write-Host "Configuring global agents for project type: $projectType"

$home = $env:USERPROFILE
$agentsSource = Join-Path $extDir 'templates'

if (-not (Test-Path $agentsSource)) {
    Write-Host "Agent templates not found: $agentsSource"
    exit 1
}

# Copy agent templates to OpenCode config
$opencodeAgentsDir = Join-Path $home '.config\opencode'
New-Item -ItemType Directory -Force -Path $opencodeAgentsDir | Out-Null

$copied = 0
Get-ChildItem -Path $agentsSource -Filter '*.md' | ForEach-Object {
    $dest = Join-Path $opencodeAgentsDir $_.Name
    Copy-Item -Force $_.FullName $dest
    $copied++
}

# Copy to Copilot agents dir
$copilotAgentsDir = Join-Path $home '.copilot\agents'
New-Item -ItemType Directory -Force -Path $copilotAgentsDir | Out-Null
Get-ChildItem -Path $agentsSource -Filter '*.md' | ForEach-Object {
    $dest = Join-Path $copilotAgentsDir $_.Name
    Copy-Item -Force $_.FullName $dest
}

Write-Host "Global agents configured ($copied templates copied)"
