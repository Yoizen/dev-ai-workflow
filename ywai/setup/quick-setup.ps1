# Quick Setup - One command installation
# Usage: irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/ywai/setup/quick-setup.ps1 | iex
#    or: & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/ywai/setup/quick-setup.ps1))) -All
#    or: powershell -ExecutionPolicy Bypass -File quick-setup.ps1 [OPTIONS]

$ErrorActionPreference = "Stop"

$SETUP_URL = "https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/ywai/setup/setup.ps1"

Write-Host "[>] GA + SDD Orchestrator Quick Setup" -ForegroundColor Cyan
Write-Host ""

Write-Host "Downloading setup script..." -ForegroundColor Gray
try {
    $setupScript = Join-Path $env:TEMP "setup-$(Get-Random).ps1"
    Invoke-WebRequest -Uri $SETUP_URL -OutFile $setupScript -UseBasicParsing
    
    Write-Host "[OK] Downloaded" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "Running setup..." -ForegroundColor Gray
    & $setupScript @args
    
    Write-Host ""
    Write-Host "[OK] Quick setup complete!" -ForegroundColor Green
}
catch {
    Write-Host "[X] Setup failed: $_" -ForegroundColor Red
    exit 1
}
finally {
    if ($setupScript -and (Test-Path $setupScript)) {
        Remove-Item $setupScript -Force -ErrorAction SilentlyContinue
    }
}
