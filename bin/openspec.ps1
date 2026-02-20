#!/usr/bin/env pwsh
$ScriptDir = Split-Path $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path $ScriptDir -Parent
$OpenSpecExe = Join-Path $ProjectRoot "node_modules\.bin\openspec.cmd"

if (Test-Path $OpenSpecExe) {
    & $OpenSpecExe $args
} else {
    Write-Error "OpenSpec not found at $OpenSpecExe. Run auto/bootstrap.ps1 -UseOpenSpec to install."
    exit 1
}
