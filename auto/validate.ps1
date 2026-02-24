#!/usr/bin/env powershell
# ============================================================================
# Validation Script - Verifica que el setup fue exitoso
# ============================================================================

param(
    [Parameter(Position=0)]
    [string]$RepoPath = (Get-Location)
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  GA Setup Validation" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

$RepoPath = Resolve-Path $RepoPath
Write-Host "Validating: $RepoPath" -ForegroundColor White
Write-Host ""

$issues = @()
$warnings = @()
$success = @()

# Check commands
Write-Host "Checking installed tools..." -ForegroundColor Yellow

$commands = @("git", "node", "npm", "ga", "code")
foreach ($cmd in $commands) {
    try {
        $null = Get-Command $cmd -ErrorAction Stop
        if ($cmd -eq "code") {
            $success += "[OK] $cmd is available"
        } else {
            $version = & $cmd --version 2>$null | Select-Object -First 1
            $success += "[OK] $cmd is available ($version)"
        }
    } catch {
        if ($cmd -eq "code") {
            $warnings += "[WARN] $cmd not found (VS Code CLI)"
        } else {
            $issues += "[ERROR] $cmd is NOT installed"
        }
    }
}

Write-Host ""
Write-Host "Checking repository structure..." -ForegroundColor Yellow

# Check directories
$requiredDirs = @(
    ".specify/memory",
    "specs"
)

foreach ($dir in $requiredDirs) {
    $path = Join-Path $RepoPath $dir
    if (Test-Path $path) {
        $success += "[OK] $dir/ exists"
    } else {
        $issues += "[ERROR] $dir/ is missing"
    }
}

# Check files
$requiredFiles = @(
    "AGENTS.MD",
    "REVIEW.md",
    ".specify/memory/constitution.md",
    ".ga"
)

foreach ($file in $requiredFiles) {
    $path = Join-Path $RepoPath $file
    if (Test-Path $path) {
        $success += "[OK] $file exists"
    } else {
        if ($file -eq ".ga") {
            $warnings += "[WARN] $file is missing (run 'ga init')"
        } else {
            $issues += "[ERROR] $file is missing"
        }
    }
}

Write-Host ""
Write-Host "Checking GA configuration..." -ForegroundColor Yellow

$gaConfig = Join-Path $RepoPath ".ga"
if (Test-Path $gaConfig) {
    $content = Get-Content $gaConfig -Raw
    
    if ($content -match "PROVIDER=") {
        $success += "[OK] .ga has PROVIDER configured"
    } else {
        $warnings += "[WARN] .ga is missing PROVIDER"
    }
    
    if ($content -match "API_KEY=") {
        $success += "[OK] .ga has API_KEY configured"
    } else {
        $warnings += "[WARN] .ga is missing API_KEY"
    }
}

# Check VS Code extensions
Write-Host ""
Write-Host "Checking VS Code extensions..." -ForegroundColor Yellow

if (Get-Command code -ErrorAction SilentlyContinue) {
    $extensions = code --list-extensions 2>$null
    
    $requiredExts = @(
        "github.copilot",
        "ultracite.ultracite-vscode"
    )
    
    foreach ($ext in $requiredExts) {
        if ($extensions -contains $ext) {
            $success += "[OK] Extension $ext is installed"
        } else {
            $warnings += "[WARN] Extension $ext not found"
        }
    }
}

# Report
Write-Host ""
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  Results" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

if ($success.Count -gt 0) {
    Write-Host "Success ($($success.Count)):" -ForegroundColor Green
    $success | ForEach-Object { Write-Host "  $_" -ForegroundColor Green }
    Write-Host ""
}

if ($warnings.Count -gt 0) {
    Write-Host "Warnings ($($warnings.Count)):" -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    Write-Host ""
}

if ($issues.Count -gt 0) {
    Write-Host "Issues ($($issues.Count)):" -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host ""
    Write-Host "Run bootstrap script to fix issues:" -ForegroundColor Yellow
    Write-Host "  .\bootstrap.ps1 $RepoPath" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "[OK] All checks passed!" -ForegroundColor Green
Write-Host ""
Write-Host "Your repository is ready to use!" -ForegroundColor Cyan
Write-Host ""
