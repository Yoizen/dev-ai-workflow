# Quick Setup - One command installation
# Usage: irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1 | iex
#    or: & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1))) -All
#    or: powershell -ExecutionPolicy Bypass -File quick-setup.ps1 [OPTIONS]

$ErrorActionPreference = "Stop"

$REPO_URL = "https://github.com/Yoizen/dev-ai-workflow.git"
$INSTALL_DIR = Join-Path $env:TEMP "ga-bootstrap-$(Get-Random)"

Write-Host "[>] GA + SDD Orchestrator Quick Setup" -ForegroundColor Cyan
Write-Host ""

function Cleanup {
    if (Test-Path $INSTALL_DIR) {
        Start-Sleep -Milliseconds 500
        Get-ChildItem $INSTALL_DIR -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.IsReadOnly = $false }
        Remove-Item $INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
    }
}

try {
    Write-Host "Downloading bootstrap scripts..." -ForegroundColor Gray
    git clone --quiet --depth 1 $REPO_URL $INSTALL_DIR 2>&1 | Out-Null

    if (-not (Test-Path "$INSTALL_DIR\auto\bootstrap.ps1")) {
        Write-Host "[X] Failed to download bootstrap script" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "[OK] Downloaded" -ForegroundColor Green
    Write-Host ""

    Write-Host "Running setup..." -ForegroundColor Gray
    & "$INSTALL_DIR\auto\bootstrap.ps1" @args

    Write-Host ""
    Write-Host "[OK] Quick setup complete!" -ForegroundColor Green
}
catch {
    Write-Host "[X] Setup failed: $_" -ForegroundColor Red
    exit 1
}
finally {
    Cleanup
}
