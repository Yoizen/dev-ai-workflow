# GGA Component Detector - Windows PowerShell
# Detects installed components, versions, and available updates

$ErrorActionPreference = "SilentlyContinue"

$GGA_REPO = "Yoizen/gga-copilot"
$GGA_API_URL = "https://api.github.com/repos/$GGA_REPO"

function Get-LatestGgaVersion {
    try {
        $release = Invoke-RestMethod -Uri "$GGA_API_URL/releases/latest" -ErrorAction Stop
        $version = $release.tag_name -replace '^v', ''
        return $version
    } catch {
        try {
            $tags = Invoke-RestMethod -Uri "$GGA_API_URL/tags" -ErrorAction Stop
            if ($tags.Count -gt 0) {
                $version = $tags[0].name -replace '^v', ''
                return $version
            }
        } catch {}
        return "unknown"
    }
}

function Get-InstalledGgaVersion {
    try {
        $version = & gga version 2>$null
        if ($version -match '(\d+\.\d+\.\d+)') {
            return $Matches[1]
        }
    } catch {}
    return $null
}

function Detect-Gga {
    $installed = Get-InstalledGgaVersion
    
    if (-not $installed) {
        $latest = Get-LatestGgaVersion
        return "NOT_INSTALLED|-|$latest"
    }
    
    $latest = Get-LatestGgaVersion
    
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

function Get-LatestOpenspecVersion {
    try {
        $result = npm view "@fission-ai/openspec" version 2>$null
        if ($result) {
            return $result.Trim()
        }
    } catch {}
    return "unknown"
}

function Get-InstalledOpenspecVersion {
    if (Test-Path "package.json") {
        try {
            $result = npm list "@fission-ai/openspec" --depth=0 2>$null
            if ($result -match '@(\d+\.\d+\.\d+)') {
                return $Matches[1]
            }
        } catch {}
    }
    return $null
}

function Detect-Openspec {
    $installed = Get-InstalledOpenspecVersion
    
    if (-not $installed) {
        $latest = Get-LatestOpenspecVersion
        return "NOT_INSTALLED|-|$latest"
    }
    
    $latest = Get-LatestOpenspecVersion
    
    if ($installed -eq $latest -or $latest -eq "unknown") {
        $status = "UP_TO_DATE"
    } else {
        try {
            $installedVer = [Version]$installed
            $latestVer = [Version]$latest
            
            if ($installedVer -lt $latestVer) {
                $status = "OUTDATED"
            } else {
                $status = "UP_TO_DATE"
            }
        } catch {
            $status = "UP_TO_DATE"
        }
    }
    
    return "$status|$installed|$latest"
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
    $gga = Detect-Gga
    $openspec = Detect-Openspec
    $vscode = Detect-VscodeExtensions
    $prereq = Detect-Prerequisites
    
    return @"
GGA:$gga
OPENSPEC:$openspec
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
        "gga" { Detect-Gga }
        "openspec" { Detect-Openspec }
        "vscode" { Detect-VscodeExtensions }
        "prereq" { Detect-Prerequisites }
        "prerequisites" { Detect-Prerequisites }
        "all" { Detect-AllComponents }
        default {
            Write-Host "Usage: .\detector.ps1 {gga|openspec|vscode|prereq|all}"
            exit 1
        }
    }
}
