# Quick Setup - One command installation
# Usage: irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/ywai/setup/quick-setup.ps1 | iex
#    or: & ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/ywai/setup/quick-setup.ps1))) -All
#    or: powershell -ExecutionPolicy Bypass -File quick-setup.ps1 [OPTIONS]

$ErrorActionPreference = "Stop"

$YWAI_REPO   = if ($env:YWAI_REPO)   { $env:YWAI_REPO }   else { "Yoizen/dev-ai-workflow" }
$YWAI_RAW    = "https://raw.githubusercontent.com/$YWAI_REPO"
$YWAI_API    = "https://api.github.com/repos/$YWAI_REPO"
$YWAI_CHANNEL = if ($env:YWAI_CHANNEL) { $env:YWAI_CHANNEL } else { "stable" }
$YWAI_VERSION = if ($env:YWAI_VERSION) { $env:YWAI_VERSION } else { "" }

Write-Host "[>] GA + SDD Orchestrator Quick Setup" -ForegroundColor Cyan
Write-Host ""

# Resolve which ref (tag or branch) to download setup.ps1 from
function Resolve-QuickRef {
    if ($YWAI_VERSION -and $YWAI_VERSION -ne "stable" -and $YWAI_VERSION -ne "latest") {
        return $YWAI_VERSION
    }
    $channel = if ($YWAI_VERSION) { $YWAI_VERSION } else { $YWAI_CHANNEL }
    try {
        if ($channel -eq "latest") {
            $rel = Invoke-RestMethod -Uri "$YWAI_API/releases/latest" -ErrorAction Stop -TimeoutSec 5
            if ($rel.tag_name) { return $rel.tag_name }
        } else {
            $rels = Invoke-RestMethod -Uri "$YWAI_API/releases" -ErrorAction Stop -TimeoutSec 5
            $stable = $rels | Where-Object { -not $_.prerelease } | Select-Object -First 1
            if ($stable) { return $stable.tag_name }
        }
    } catch {}
    $fallback = if ($env:YWAI_FALLBACK_BRANCH) { $env:YWAI_FALLBACK_BRANCH } `
                elseif ($env:DEV_AI_WORKFLOW_REF) { $env:DEV_AI_WORKFLOW_REF } `
                else { "main" }
    return $fallback
}

$ref = Resolve-QuickRef
$SETUP_URL = "$YWAI_RAW/$ref/ywai/setup/setup.ps1"

Write-Host "Using ref: $ref" -ForegroundColor Gray
Write-Host "Downloading setup script..." -ForegroundColor Gray
$setupScript = $null
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
