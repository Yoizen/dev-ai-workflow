# GGA + OpenSpec Bootstrap - Automated Setup Script
# Simple interactive installer with full parameter support for automation
# Usage: .\bootstrap.ps1 [OPTIONS] [target-directory]

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$TargetPath = "",
    
    [switch]$All,
    [switch]$InstallGGA,
    [switch]$InstallOpenSpec,
    [switch]$InstallVSCode,
    [switch]$SkipGGA,
    [switch]$SkipOpenSpec,
    [switch]$SkipVSCode,
    
    [ValidateSet('opencode', 'claude', 'gemini', 'ollama')]
    [string]$Provider = "",
    
    [string]$Target = "",
    
    [switch]$UpdateAll,
    [switch]$Force,
    [switch]$Silent,
    [switch]$DryRun,
    [switch]$Help,
    [switch]$Hooks,
    [switch]$Biome
)

$ErrorActionPreference = "Stop"

# Script Directory Detection
$ScriptDir = Split-Path -Parent $PSCommandPath
$BootstrapDir = $ScriptDir

# Source Library Modules
. "$BootstrapDir\lib\env-detect.ps1"
. "$BootstrapDir\lib\detector.ps1"
. "$BootstrapDir\lib\installer.ps1"

# Configuration
$GGA_REPO = "https://github.com/Yoizen/gga-copilot.git"
$GGA_DIR = Join-Path $env:USERPROFILE ".local\share\yoizen\gga-copilot"

# Prerequisites Check Function
function Get-Prerequisites {
    $result = @{
        GitVersion = "NOT_FOUND"
        NodeVersion = "NOT_FOUND"
        NpmVersion = "NOT_FOUND"
        VSCodeAvailable = $false
    }
    
    try {
        $gitOut = git --version 2>$null
        if ($gitOut -match '(\d+\.\d+\.\d+)') {
            $result.GitVersion = $Matches[1]
        }
    } catch {}
    
    try {
        $nodeOut = node --version 2>$null
        if ($nodeOut -match 'v?(\d+\.\d+\.\d+)') {
            $result.NodeVersion = $Matches[1]
        }
    } catch {}
    
    try {
        $npmOut = npm --version 2>$null
        if ($npmOut) {
            $result.NpmVersion = $npmOut.Trim()
        }
    } catch {}
    
    try {
        $null = Get-Command code -ErrorAction Stop
        $result.VSCodeAvailable = $true
    } catch {
        $result.VSCodeAvailable = $false
    }
    
    return $result
}

$VSCODE_EXTENSIONS = @(
    "github.copilot",
    "github.copilot-chat"
)

# Colors
$RED = "Red"
$GREEN = "Green"
$YELLOW = "Yellow"
$CYAN = "Cyan"
$WHITE = "White"

# Helper Functions
function Write-Banner {
    if ($Silent) { return }
    Write-Host ""
    Write-Host "========================================" -ForegroundColor $CYAN
    Write-Host "  GGA + OpenSpec Bootstrap" -ForegroundColor $CYAN
    Write-Host "========================================" -ForegroundColor $CYAN
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    if ($Silent) { return }
    Write-Host ""
    Write-Host "[>] $Message" -ForegroundColor $GREEN
}

function Write-SuccessMsg {
    param([string]$Message)
    if ($Silent) { return }
    Write-Host "  [OK] $Message" -ForegroundColor $GREEN
}

function Write-InfoMsg {
    param([string]$Message)
    if ($Silent) { return }
    Write-Host "  [i] $Message" -ForegroundColor $CYAN
}

function Write-WarningMsg {
    param([string]$Message)
    Write-Host "  [!] $Message" -ForegroundColor $YELLOW
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "  [X] $Message" -ForegroundColor $RED
}

function Ask-YesNo {
    param(
        [string]$Prompt,
        [string]$Default = "y"
    )
    
    if ($Default -eq "y") {
        $suffix = "[Y/n]"
    } else {
        $suffix = "[y/N]"
    }
    
    $reply = Read-Host "$Prompt $suffix"
    if ([string]::IsNullOrWhiteSpace($reply)) {
        $reply = $Default
    }
    
    return $reply -match "^[Yy]$"
}

function Show-Help {
    @"
GGA + OpenSpec Bootstrap - Automated Setup

USAGE:
    bootstrap.ps1 [OPTIONS] [target-directory]

INSTALLATION OPTIONS:
    -All                     Install everything (non-interactive mode)
    -InstallGGA             Install only GGA
    -InstallOpenSpec        Install only OpenSpec
    -InstallVSCode          Install only VS Code extensions
    -Hooks                  Install OpenCode command hooks plugin
    -Biome                  Install optional Biome baseline (minimal rules)

SKIP OPTIONS:
    -SkipGGA                Skip GGA installation
    -SkipOpenSpec           Skip OpenSpec installation
    -SkipVSCode             Skip VS Code extensions

CONFIGURATION:
    -Provider <name>        Set AI provider (opencode/claude/gemini/ollama)
    -Target <path>          Target directory (default: current directory)

ADVANCED:
    -UpdateAll              Update all installed components
    -Force                  Force reinstall/overwrite
    -Silent                 Minimal output
    -DryRun                 Show what would be done without executing

HELP:
    -Help                   Show this help message

EXAMPLES:
    # Interactive mode (simple Y/n prompts)
    .\bootstrap.ps1

    # Install everything automatically
    .\bootstrap.ps1 -All

    # Install only GGA and OpenSpec, skip VS Code
    .\bootstrap.ps1 -InstallGGA -InstallOpenSpec

    # Install with specific provider
    .\bootstrap.ps1 -All -Provider claude

    # Update all components in a specific directory
    .\bootstrap.ps1 -UpdateAll -Target C:\path\to\project

    # Dry run to see what would happen
    .\bootstrap.ps1 -All -DryRun

PROVIDERS:
    opencode                OpenCode AI Coding Agent (default)
    claude                  Anthropic Claude
    gemini                  Google Gemini
    ollama                  Ollama (local models)

For more information, visit:
    https://github.com/Yoizen/gga-copilot
"@
}

# Automated Installation (Non-Interactive)
function Invoke-AutomatedInstallation {
    Write-Banner
    
    if ($DryRun) {
        Write-WarningMsg "DRY RUN MODE - No changes will be made"
        Write-Host ""
    }
    
    $script:TargetPath = if ($Target) { $Target } elseif ($TargetPath) { $TargetPath } else { $PWD }
    
    if (-not (Test-Path $script:TargetPath)) {
        Write-ErrorMsg "Directory not found: $script:TargetPath"
        exit 1
    }
    
    $script:TargetPath = (Resolve-Path $script:TargetPath).Path
    Write-InfoMsg "Target directory: $script:TargetPath"
    
    if (-not (Test-Path (Join-Path $script:TargetPath ".git")) -and -not $DryRun) {
        Write-InfoMsg "Initializing git repository..."
        Push-Location $script:TargetPath
        git init 2>&1 | Out-Null
        Pop-Location
        Write-SuccessMsg "Git repository initialized"
    }
    
    Write-Step "Checking prerequisites..."
    $prereqStatus = Get-Prerequisites
    
    $gitVersion = $prereqStatus.GitVersion
    $nodeVersion = $prereqStatus.NodeVersion
    $npmVersion = $prereqStatus.NpmVersion
    $vscodeStatus = $prereqStatus.VSCodeAvailable
    
    if ($gitVersion -eq "NOT_FOUND" -or $nodeVersion -eq "NOT_FOUND" -or $npmVersion -eq "NOT_FOUND") {
        Write-ErrorMsg "Missing prerequisites. Please install Git, Node.js, and npm."
        exit 1
    }
    
    Write-SuccessMsg "Git $gitVersion"
    Write-SuccessMsg "Node.js $nodeVersion"
    Write-SuccessMsg "npm $npmVersion"
    
    if ($vscodeStatus) {
        Write-SuccessMsg "VS Code CLI available"
    } else {
        Write-WarningMsg "VS Code CLI not found (extensions will be skipped)"
        $script:SkipVSCode = $true
    }
    
    if ($UpdateAll) {
        Write-Step "Updating all components..."
        if (-not $DryRun) {
            Update-AllComponents -TargetDir $script:TargetPath
        } else {
            Write-InfoMsg "[DRY RUN] Would update all components"
        }
        return
    }
    
    if (-not $SkipGGA -and $InstallGGA) {
        Write-Step "Installing GGA..."
        if (-not $DryRun) {
            Install-GGA -Action "install"
        } else {
            Write-InfoMsg "[DRY RUN] Would install GGA to $GGA_DIR"
        }
    }
    
    if (-not $SkipOpenSpec -and $InstallOpenSpec) {
        Write-Step "Installing OpenSpec..."
        if (-not $DryRun) {
            Install-OpenSpec -Action "install" -TargetDir $script:TargetPath
        } else {
            Write-InfoMsg "[DRY RUN] Would install OpenSpec in $script:TargetPath"
        }
    }
    
    if (-not $SkipVSCode -and $InstallVSCode -and $vscodeStatus) {
        Write-Step "Installing VS Code extensions..."
        if (-not $DryRun) {
            Install-VSCodeExtensions -Action "install"
        } else {
            Write-InfoMsg "[DRY RUN] Would install VS Code extensions: $($VSCODE_EXTENSIONS -join ', ')"
        }
    }
    
    if ($InstallGGA -or $InstallOpenSpec -or $Hooks -or $Biome) {
        Write-Step "Configuring project..."
        if (-not $DryRun) {
            Set-ProjectConfiguration -Provider $Provider -TargetDir $script:TargetPath -SkipGGA:$SkipGGA -InstallBiome:$Biome
        } else {
            Write-InfoMsg "[DRY RUN] Would configure project in $script:TargetPath"
            if ($Provider) {
                Write-InfoMsg "[DRY RUN] Would set provider to: $Provider"
            }
            if ($Biome) {
                Write-InfoMsg "[DRY RUN] Would apply optional Biome baseline"
            }
        }
    }
    
    if ($Hooks) {
        Write-Step "Installing OpenCode command hooks..."
        if (-not $DryRun) {
            Install-Hooks -Action "install" -TargetDir $script:TargetPath
        } else {
            Write-InfoMsg "[DRY RUN] Would install OpenCode command hooks"
        }
    }
    
    if (-not $DryRun) {
        Show-NextSteps -RepoPath $script:TargetPath
    } else {
        Write-WarningMsg "DRY RUN completed - no changes made"
    }
}

# Interactive Installation (Simple Y/n prompts)
function Invoke-InteractiveInstallation {
    Write-Banner
    
    Write-Host "This will install GGA + OpenSpec in your project." -ForegroundColor $WHITE
    Write-Host ""
    
    Write-Step "Checking prerequisites..."
    $prereqStatus = Get-Prerequisites
    
    $gitVersion = $prereqStatus.GitVersion
    $nodeVersion = $prereqStatus.NodeVersion
    $npmVersion = $prereqStatus.NpmVersion
    $vscodeAvailable = $prereqStatus.VSCodeAvailable
    
    if ($gitVersion -eq "NOT_FOUND" -or $nodeVersion -eq "NOT_FOUND" -or $npmVersion -eq "NOT_FOUND") {
        Write-ErrorMsg "Missing prerequisites. Please install Git, Node.js, and npm."
        exit 1
    }
    
    Write-SuccessMsg "Git $gitVersion"
    Write-SuccessMsg "Node.js $nodeVersion"
    Write-SuccessMsg "npm $npmVersion"
    if ($vscodeAvailable) {
        Write-SuccessMsg "VS Code CLI available"
    } else {
        Write-WarningMsg "VS Code CLI not found"
    }
    Write-Host ""
    
    # Target directory
    if ([string]::IsNullOrWhiteSpace($script:TargetPath)) {
        $defaultPath = $PWD.Path
        $inputPath = Read-Host "Target directory [$defaultPath]"
        if ([string]::IsNullOrWhiteSpace($inputPath)) {
            $script:TargetPath = $defaultPath
        } else {
            $script:TargetPath = $inputPath
        }
    }
    
    if (-not (Test-Path $script:TargetPath)) {
        Write-ErrorMsg "Directory not found: $script:TargetPath"
        exit 1
    }
    
    $script:TargetPath = (Resolve-Path $script:TargetPath).Path
    Write-Host ""
    
    # Simple Y/n questions
    $script:InstallGGA = Ask-YesNo -Prompt "Install GGA (AI code review)?" -Default "y"
    $script:InstallOpenSpec = Ask-YesNo -Prompt "Install OpenSpec (spec-first dev)?" -Default "y"
    $script:InstallVSCode = $false
    if ($vscodeAvailable) {
        $script:InstallVSCode = Ask-YesNo -Prompt "Install VS Code extensions?" -Default "y"
    }
    $script:Biome = Ask-YesNo -Prompt "Install optional Biome baseline (minimal lint/format rules)?" -Default "n"
    
    Write-Host ""
    
    # Summary
    Write-Host "Will install:" -ForegroundColor $WHITE
    if ($script:InstallGGA) { Write-Host "  - GGA" }
    if ($script:InstallOpenSpec) { Write-Host "  - OpenSpec" }
    if ($script:InstallVSCode) { Write-Host "  - VS Code Extensions" }
    if ($script:Biome) { Write-Host "  - Biome Baseline (optional)" }
    Write-Host "  -> Target: $script:TargetPath"
    Write-Host ""
    
    if (-not (Ask-YesNo -Prompt "Proceed?" -Default "y")) {
        Write-WarningMsg "Cancelled"
        exit 0
    }
    
    Write-Host ""
    
    # Initialize git if needed
    if (-not (Test-Path (Join-Path $script:TargetPath ".git"))) {
        Write-InfoMsg "Initializing git repository..."
        Push-Location $script:TargetPath
        git init 2>&1 | Out-Null
        Pop-Location
        Write-SuccessMsg "Git repository initialized"
    }
    
    # Install components
    if ($script:InstallGGA) {
        Write-Step "Installing GGA..."
        Install-GGA -Action "install" | Out-Null
        Write-SuccessMsg "GGA installed"
    }
    
    if ($script:InstallOpenSpec) {
        Write-Step "Installing OpenSpec..."
        Install-OpenSpec -Action "install" -TargetDir $script:TargetPath | Out-Null
        Write-SuccessMsg "OpenSpec installed"
    }
    
    if ($script:InstallVSCode -and $vscodeAvailable) {
        Write-Step "Installing VS Code extensions..."
        Install-VSCodeExtensions -Action "install" | Out-Null
        Write-SuccessMsg "VS Code extensions installed"
    }
    
    # Configure project
    Write-Step "Configuring project..."
    $skipGgaFlag = -not $script:InstallGGA
    Set-ProjectConfiguration -Provider $script:Provider -TargetDir $script:TargetPath -SkipGGA:$skipGgaFlag -InstallBiome:$script:Biome | Out-Null
    Write-SuccessMsg "Project configured"
    
    Show-NextSteps -RepoPath $script:TargetPath
}

# Next Steps Display
function Show-NextSteps {
    param([string]$RepoPath)
    
    if ($Silent) { return }
    
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor $CYAN
    Write-Host "  Setup Complete!" -ForegroundColor $GREEN
    Write-Host "================================================================" -ForegroundColor $CYAN
    Write-Host ""
    Write-Host "Your repository is now configured with:" -ForegroundColor $WHITE
    if ($script:InstallGGA) { Write-Host "  - GGA (Guardian Agent)" -ForegroundColor $CYAN }
    if ($script:InstallOpenSpec) { Write-Host "  - OpenSpec (Spec-First methodology)" -ForegroundColor $CYAN }
    if ($script:InstallVSCode) { Write-Host "  - VS Code Extensions" -ForegroundColor $CYAN }
    if ($script:Hooks) { Write-Host "  - OpenCode Command Hooks" -ForegroundColor $CYAN }
    if ($script:Biome) { Write-Host "  - Biome Baseline (optional)" -ForegroundColor $CYAN }
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor $YELLOW
    if ($script:InstallGGA -and $script:Provider) { Write-Host "  1. Review .gga config (provider: $($script:Provider))" -ForegroundColor $WHITE }
    Write-Host "  2. Customize AGENTS.MD for your project" -ForegroundColor $WHITE
    if ($script:InstallOpenSpec) { Write-Host "  3. Use OpenSpec to create specifications" -ForegroundColor $WHITE }
    if ($script:InstallGGA) { Write-Host "  4. Run 'gga review' before committing code" -ForegroundColor $WHITE }
    Write-Host ""
    Write-Host "Repository path: $RepoPath" -ForegroundColor $CYAN
    Write-Host ""
}

# Main Execution
if ($Help) {
    Show-Help
    exit 0
}

# Determine mode
$InteractiveMode = $true

if ($All) {
    $InteractiveMode = $false
    $InstallGGA = $true
    $InstallOpenSpec = $true
    $InstallVSCode = $true
}

if ($InstallGGA -or $InstallOpenSpec -or $InstallVSCode -or $UpdateAll -or $Hooks -or $Biome) {
    $InteractiveMode = $false
}

if ($InteractiveMode) {
    if (-not (Test-InteractiveEnvironment)) {
        Write-WarningMsg "Non-interactive environment detected, using automated mode with -All"
        $InteractiveMode = $false
        $InstallGGA = $true
        $InstallOpenSpec = $true
        $InstallVSCode = $true
    }
}

if ($InteractiveMode) {
    Invoke-InteractiveInstallation
} else {
    Invoke-AutomatedInstallation
}
