# GA Bulk Update — updates GA and project configs across multiple repos
# Usage: .\update-all.ps1 [OPTIONS] [repo1 repo2 ...]

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$UpdateToolsOnly,
    [switch]$UpdateConfigsOnly,
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Repositories
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $PSCommandPath

# Source Library Modules
. "$ScriptDir\lib\ui.ps1"
. "$ScriptDir\lib\detector.ps1"
. "$ScriptDir\lib\installer.ps1"

# Banner
Write-Banner "GA Bulk Update"

if ($DryRun) {
    Write-Warning "DRY RUN MODE — no changes will be made"
    Write-Host ""
}

# ── Show Help ─────────────────────────────────────────────────────────────

if ($Help) {
    @"
Usage: .\update-all.ps1 [OPTIONS] [repo1 repo2 ...]

Options:
  -DryRun              Show what would be done without changes
  -Force               Force update configs even if they exist
  -UpdateToolsOnly     Only update tools (skip repo configs)
  -UpdateConfigsOnly   Only update repo configs (skip tools)
  -Help                Show this help message

Examples:
  .\update-all.ps1 C:\repo1 C:\repo2
  .\update-all.ps1 -DryRun C:\repo1
  .\update-all.ps1 -Force C:\repo1
"@
    exit 0
}

# ── Update GA Globally ─────────────────────────────────────────────────

if (-not $UpdateConfigsOnly) {
    Write-Step "Checking for GA updates..."

    $gaStatus = Detect-Ga
    $parts = $gaStatus -split '\|'
    $status = $parts[0]

    if ($status -eq "OUTDATED") {
        if ($Force) {
            $doUpdate = $true
        } else {
            $doUpdate = Ask-YesNo "GA update available. Update now?" -Default "y"
        }

        if ($doUpdate) {
            if (-not $DryRun) {
                Install-Ga -Action "update"
            } else {
                Write-Info "[DRY RUN] Would update GA"
            }
        }
    } else {
        Write-Success "GA is already up to date"
    }
    Write-Host ""
}

# ── Update Repositories ───────────────────────────────────────────────

if (-not $UpdateToolsOnly) {
    if ($Repositories.Count -eq 0) {
        Write-Warning "No repositories specified"
        Write-Host ""
        Write-Host "Examples:" -ForegroundColor Yellow
        Write-Host "  .\update-all.ps1 C:\repo1 C:\repo2" -ForegroundColor Cyan
        Write-Host "  .\update-all.ps1 -DryRun C:\repo1" -ForegroundColor Cyan
        Write-Host "  .\update-all.ps1 -Force C:\repo1" -ForegroundColor Cyan
        Write-Host ""
        exit 0
    }

    Write-Step "Updating repositories..."

    $total = 0
    $success = 0
    $failed = 0
    $skipped = 0
    $setupScript = Join-Path $ScriptDir "setup.ps1"

    foreach ($repo in $Repositories) {
        $total++
        Write-Host ""
        Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
        Write-Info "Processing: $repo"

        if (-not (Test-Path $repo)) {
            Write-Error "Directory not found: $repo"
            $failed++
            continue
        }

        $gitDir = Join-Path $repo ".git"
        if (-not (Test-Path $gitDir)) {
            Write-Warning "Not a git repository: $repo"
            $skipped++
            continue
        }

        $gaConfig = Join-Path $repo ".ga"
        if (-not (Test-Path $gaConfig)) {
            Write-Warning "GA not configured (no .ga file)"
            $skipped++
            continue
        }

        if ($DryRun) {
            Write-Info "[DRY RUN] Would update repository"
            $success++
            continue
        }

        $flags = @("-SkipSDD", "-SkipGA", "-SkipVSCode")
        if ($Force) { $flags += "-Force" }

        try {
            & $setupScript @flags $repo 2>$null | Out-Null
            Write-Success "Updated successfully"
            $success++
        } catch {
            Write-Error "Failed to update"
            $failed++
        }
    }

    # Summary
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "  Summary" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Total:    $total" -ForegroundColor White
    Write-Host "  Updated:  $success" -ForegroundColor Green
    Write-Host "  Failed:   $failed" -ForegroundColor Red
    Write-Host "  Skipped:  $skipped" -ForegroundColor Yellow
    Write-Host ""

    if ($failed -gt 0) {
        Write-Warning "Some repositories failed — review output above"
        exit 1
    }
    if ($total -gt 0) {
        Write-Success "All repositories updated!"
    }
    Write-Host ""
}
