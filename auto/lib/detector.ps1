# GA Component Detector - Windows PowerShell
# Detects installed components, versions, and available updates

$ErrorActionPreference = "SilentlyContinue"

$GA_REPO = "Yoizen/dev-ai-workflow"
$GA_API_URL = "https://api.github.com/repos/$GA_REPO"

function Get-LatestGaVersion {
    try {
        $release = Invoke-RestMethod -Uri "$GA_API_URL/releases/latest" -ErrorAction Stop
        $version = $release.tag_name -replace '^v', ''
        return $version
    } catch {
        try {
            $tags = Invoke-RestMethod -Uri "$GA_API_URL/tags" -ErrorAction Stop
            if ($tags.Count -gt 0) {
                $version = $tags[0].name -replace '^v', ''
                return $version
            }
        } catch {}
        return "unknown"
    }
}

function Get-InstalledGaVersion {
    try {
        $version = & ga version 2>$null
        if ($version -match '(\d+\.\d+\.\d+)') {
            return $Matches[1]
        }
    } catch {}
    return $null
}

function Detect-Ga {
    $installed = Get-InstalledGaVersion
    
    if (-not $installed) {
        $latest = Get-LatestGaVersion
        return "NOT_INSTALLED|-|$latest"
    }
    
    $latest = Get-LatestGaVersion
    
    if ($installed -eq $latest -or $latest -eq "unknown") {
        $status = "UP_TO_DATE"
    } else {
        $installedVer = [Version]($installed -replace 'x', '999')
        $latestVer = [Version]($latest -replace 'x', '999')
        
        if ($installedVer -lt $latestVer) {
            $status = "OUTDATED"
        } else {
            $status = "UP_TO_DATE"
        }
    }
    
    return "$status|$installed|$latest"
}

function Detect-SDD {
    param([string]$TargetDir = ".")
    
    $skillsDir = Join-Path $TargetDir "skills"
    $count = 0
    
    if (Test-Path $skillsDir) {
        $sddSkills = Get-ChildItem -Path $skillsDir -Directory -Filter "sdd-*" -ErrorAction SilentlyContinue
        $count = ($sddSkills | Measure-Object).Count
    }
    
    if ($count -eq 0) {
        return "NOT_INSTALLED|0|9"
    } elseif ($count -ge 9) {
        return "INSTALLED|$count|9"
    } else {
        return "PARTIAL|$count|9"
    }
}

function Detect-VscodeExtensions {
    $extensions = @("github.copilot", "github.copilot-chat")
    $installed = 0
    $total = $extensions.Count
    $missing = @()
    
    try {
        $installedList = & code --list-extensions 2>$null
        if (-not $installedList) {
            return "NOT_AVAILABLE|0|$total|VS Code CLI not found"
        }
        
        foreach ($ext in $extensions) {
            if ($installedList -contains $ext) {
                $installed++
            } else {
                $missing += $ext
            }
        }
    } catch {
        return "NOT_AVAILABLE|0|$total|VS Code CLI not found"
    }
    
    if ($installed -eq 0) {
        $status = "NOT_INSTALLED"
    } elseif ($installed -eq $total) {
        $status = "INSTALLED"
    } else {
        $status = "PARTIAL"
    }
    
    $missingStr = $missing -join " "
    return "$status|$installed|$total|$missingStr"
}

function Detect-Prerequisites {
    $gitVersion = "not_found"
    $nodeVersion = "not_found"
    $npmVersion = "not_found"
    $vscodeStatus = "not_found"
    
    try {
        $gitOut = git --version 2>$null
        if ($gitOut -match '(\d+\.\d+\.\d+)') {
            $gitVersion = $Matches[1]
        }
    } catch {}
    
    try {
        $nodeOut = node --version 2>$null
        if ($nodeOut -match '(\d+\.\d+\.\d+)') {
            $nodeVersion = $Matches[1]
        }
    } catch {}
    
    try {
        $npmOut = npm --version 2>$null
        if ($npmOut) {
            $npmVersion = $npmOut.Trim()
        }
    } catch {}
    
    try {
        $null = Get-Command code -ErrorAction Stop
        $vscodeStatus = "available"
    } catch {
        $vscodeStatus = "not_found"
    }
    
    return "$gitVersion|$nodeVersion|$npmVersion|$vscodeStatus"
}

function Detect-AllComponents {
    $ga = Detect-Ga
    $sdd = Detect-SDD
    $vscode = Detect-VscodeExtensions
    $prereq = Detect-Prerequisites
    
    return @"
GA:$ga
SDD:$sdd
VSCODE:$vscode
PREREQ:$prereq
"@
}

function Format-ComponentStatus {
    param(
        [string]$Component,
        [string]$Status,
        [string]$Current,
        [string]$Latest
    )
    
    switch ($Status) {
        "NOT_INSTALLED" {
            return "[$Component] Not installed - Latest: $Latest"
        }
        { $_ -in "INSTALLED", "UP_TO_DATE" } {
            return "[$Component] Installed: $Current [OK]"
        }
        "OUTDATED" {
            return "[$Component] Installed: $Current [OK]"
        }
        "PARTIAL" {
            return "[$Component] Partially installed - $Current of $Latest components"
        }
        "NOT_AVAILABLE" {
            return "[$Component] $Latest"
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $command = $args[0]
    if (-not $command) { $command = "all" }
    
    switch ($command) {
        "ga" { Detect-Ga }
        "sdd" { Detect-SDD }
        "vscode" { Detect-VscodeExtensions }
        "prereq" { Detect-Prerequisites }
        "prerequisites" { Detect-Prerequisites }
        "all" { Detect-AllComponents }
        default {
            Write-Host "Usage: .\detector.ps1 {ga|sdd|vscode|prereq|all}"
            exit 1
        }
    }
}
