# Update All Repositories
# Updates GA installation and optionally repository configs

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
$GaRoot = Split-Path -Parent $ScriptDir
$GaInstallPath = Join-Path $env:USERPROFILE ".local\share\yoizen\dev-ai-workflow"

function Write-SuccessMsg { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-ErrorLog { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }
function Write-WarnMsg { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-InfoMsg { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Step { param($msg) Write-Host "`n[>] $msg" -ForegroundColor Green }

function Show-Help {
    Write-Host @"
Usage: update-all.ps1 [OPTIONS] [repository1] [repository2] ...

Options:
  -DryRun              Show what would be done without making changes
  -Force               Force update even with uncommitted changes
  -UpdateToolsOnly     Only update GA tools (not repository configs)
  -UpdateConfigsOnly   Only update repository configs (not tools)
  -Help                Show this help message

Examples:
  # Update GA tools only
  .\update-all.ps1

  # Update specific repositories
  .\update-all.ps1 C:\Projects\repo1 C:\Projects\repo2

  # Dry run first
  .\update-all.ps1 -DryRun C:\Projects\repo1

  # Force update configs
  .\update-all.ps1 -Force C:\Projects\repo1
"@
}

# Get version from package.json
function Get-PackageVersion {
    param([string]$PackagePath)
    
    if (Test-Path $PackagePath) {
        try {
            $pkg = Get-Content $PackagePath -Raw | ConvertFrom-Json
            return $pkg.version
        } catch {}
    }
    return $null
}

# Check if GA updates are available
function Test-GaUpdatesAvailable {
    param([string]$GaPath)
    
    if (-not (Test-Path (Join-Path $GaPath ".git"))) {
        return $false
    }
    
    try {
        Push-Location $GaPath
        
        # Fetch latest from origin quietly
        git fetch origin -q 2>$null
        
        # Check if we're behind origin
        $behind = git rev-list HEAD..origin/main --count 2>$null
        if (-not $behind) {
            $behind = git rev-list HEAD..origin/master --count 2>$null
        }
        
        Pop-Location
        
        if ($behind -and [int]$behind -gt 0) {
            return $true
        }
    } catch {
        if ($PWD.Path -ne $GaPath) { Pop-Location }
    }
    
    return $false
}

# Prompt user for update
function Request-Update {
    param([string]$GaPath)
    
    $currentVersion = Get-PackageVersion (Join-Path $GaPath "package.json")
    
    Write-Host ""
    Write-InfoMsg "GA update available!"
    if ($currentVersion) {
        Write-Host "  Current version: $currentVersion" -ForegroundColor Gray
    }
    Write-Host ""
    
    $response = Read-Host "  Update GA now? [Y/n]"
    
    if ($response -match "^[nN]") {
        Write-InfoMsg "Skipping GA update"
        return $false
    }
    return $true
}

if ($Help) {
    Show-Help
    exit 0
}

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  GA Bulk Update" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-WarnMsg "DRY RUN MODE - No changes will be made"
    Write-Host ""
}

# Stats
$Total = 0
$Success = 0
$Failed = 0
$Skipped = 0

# Update tools globally
if (-not $UpdateConfigsOnly) {
    Write-Step "Checking for GA updates..."
    
    if (-not (Test-Path $GaInstallPath)) {
        Write-WarnMsg "GA not installed at $GaInstallPath"
    } else {
        if (Test-GaUpdatesAvailable $GaInstallPath) {
            $shouldUpdate = $Force -or (Request-Update $GaInstallPath)
            
            if ($shouldUpdate) {
                Write-InfoMsg "Updating GA..."
                
                if (-not $DryRun) {
                    try {
                        Push-Location $GaInstallPath
                        
                        # Check for uncommitted changes
                        $status = git status --porcelain 2>&1
                        if ($status -and -not $Force) {
                            Write-WarnMsg "GA has uncommitted changes (use -Force to update anyway)"
                            Pop-Location
                        } else {
                            # Pull latest changes
                            $pullResult = git pull --ff-only origin main 2>&1
                            if ($LASTEXITCODE -ne 0) {
                                $pullResult = git pull --ff-only origin master 2>&1
                            }
                            
                            if ($LASTEXITCODE -eq 0) {
                                # Reinstall
                                & (Join-Path $GaInstallPath "install.ps1") 2>&1 | Out-Null
                                
                                $newVersion = Get-PackageVersion (Join-Path $GaInstallPath "package.json")
                                Write-SuccessMsg "GA updated to version $newVersion"
                            } else {
                                Write-WarnMsg "Could not fast-forward, manual update may be needed"
                            }
                            
                            Pop-Location
                        }
                    } catch {
                        Write-ErrorLog "Error updating GA: $_"
                        if ($PWD.Path -ne $GaInstallPath) { Pop-Location }
                    }
                } else {
                    Write-InfoMsg "[DRY RUN] Would update GA"
                }
            }
        } else {
            $currentVersion = Get-PackageVersion (Join-Path $GaInstallPath "package.json")
            Write-SuccessMsg "GA is up to date ($currentVersion)"
        }
    }
    
    Write-Host ""
}

# Update each repository
if (-not $UpdateToolsOnly) {
    if ($Repositories.Count -eq 0) {
        Write-WarnMsg "No repositories specified"
        Write-Host ""
        Write-Host "Usage examples:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  # Update specific repositories" -ForegroundColor White
        Write-Host "  .\update-all.ps1 C:\Projects\repo1 C:\Projects\repo2" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  # Dry run first" -ForegroundColor White
        Write-Host "  .\update-all.ps1 -DryRun C:\Projects\repo1" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  # Force update configs" -ForegroundColor White
        Write-Host "  .\update-all.ps1 -Force C:\Projects\repo1" -ForegroundColor Cyan
        Write-Host ""
        exit 0
    }
    
    Write-Step "Updating repositories..."
    
    foreach ($repo in $Repositories) {
        $Total++
        
        Write-Host ""
        Write-Host "--------------------------------------------------" -ForegroundColor Gray
        Write-InfoMsg "Processing: $repo"
        
        if (-not (Test-Path $repo)) {
            Write-ErrorLog "Repository not found: $repo"
            $Failed++
            continue
        }
        
        if (-not (Test-Path (Join-Path $repo ".git"))) {
            Write-WarnMsg "Not a git repository: $repo"
            $Skipped++
            continue
        }
        
        if (-not (Test-Path (Join-Path $repo ".ga"))) {
            Write-WarnMsg "GA not configured (no .ga file)"
            $Skipped++
            continue
        }
        
        if (-not $DryRun) {
            $bootstrapScript = Join-Path $ScriptDir "bootstrap.ps1"
            
            $flags = @("-SkipSDD", "-SkipGA", "-SkipVSCode", "-Target", $repo)
            if ($Force) { $flags += "-Force" }
            
            try {
                & $bootstrapScript @flags 2>&1 | Out-Null
                Write-SuccessMsg "Updated successfully"
                $Success++
            } catch {
                Write-ErrorLog "Failed to update: $_"
                $Failed++
            }
        } else {
            Write-InfoMsg "[DRY RUN] Would update repository"
            $Success++
        }
    }
}

# Summary
Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Summary" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Total repositories: $Total" -ForegroundColor White
Write-Host "  Successfully updated: $Success" -ForegroundColor Green
Write-Host "  Failed: $Failed" -ForegroundColor Red
Write-Host "  Skipped: $Skipped" -ForegroundColor Yellow
Write-Host ""

if ($Failed -gt 0) {
    Write-WarnMsg "Some repositories failed to update"
    Write-Host "  Review the output above for details"
    Write-Host ""
    exit 1
}

if ($Total -gt 0) {
    Write-SuccessMsg "All repositories updated!"
}

Write-Host ""
