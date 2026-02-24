# GA + SDD Orchestrator Bootstrap - Automated Setup Script
# Simple interactive installer with full parameter support for automation
# Usage: .\bootstrap.ps1 [OPTIONS] [target-directory]

[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$TargetPath = "",
    
    [switch]$All,
    [switch]$InstallGA,
    [switch]$InstallSDD,
    [switch]$InstallVSCode,
    [switch]$SkipGA,
    [switch]$SkipSDD,
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
    [switch]$Biome,

    [string]$Type = "nest",
    [switch]$ListTypes
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
$GA_REPO = "https://github.com/Yoizen/dev-ai-workflow.git"
$GA_DIR = Join-Path $env:USERPROFILE ".local\share\yoizen\dev-ai-workflow"

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
    Write-Host "  GA + SDD Orchestrator Bootstrap" -ForegroundColor $CYAN
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
GA + SDD Orchestrator Bootstrap - Automated Setup

USAGE:
    bootstrap.ps1 [OPTIONS] [target-directory]

INSTALLATION OPTIONS:
    -All                     Install everything (non-interactive mode)
    -InstallGA             Install only GA
    -InstallSDD        Install only SDD Orchestrator
    -InstallVSCode          Install only VS Code extensions
    -Hooks                  Install OpenCode command hooks plugin
    -Biome                  Install optional Biome baseline (minimal rules)

SKIP OPTIONS:
    -SkipGA                Skip GA installation
    -SkipSDD           Skip SDD Orchestrator installation
    -SkipVSCode             Skip VS Code extensions

CONFIGURATION:
    -Provider <name>        Set AI provider (opencode/claude/gemini/ollama)
    -Target <path>          Target directory (default: current directory)
    -Type <name>            Project type: nest, python, react, generic
    -ListTypes              Show all available project types

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

    # Install only GA and SDD Orchestrator, skip VS Code
    .\bootstrap.ps1 -InstallGA -InstallSDD

    # Install with specific provider
    .\bootstrap.ps1 -All -Provider claude

    # Update all components in a specific directory
    .\bootstrap.ps1 -UpdateAll -Target C:\path\to\project

    # Dry run to see what would happen
    .\bootstrap.ps1 -All -DryRun

    # Install for a NestJS project
    .\bootstrap.ps1 -All -Type nest

    # List available project types
    .\bootstrap.ps1 -ListTypes

PROVIDERS:
    opencode                OpenCode AI Coding Agent (default)
    claude                  Anthropic Claude
    gemini                  Google Gemini
    ollama                  Ollama (local models)

For more information, visit:
    https://github.com/Yoizen/dev-ai-workflow
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
    
    if ($gitVersion -eq "NOT_FOUND") {
        Write-ErrorMsg "Missing prerequisite: Git is required."
        exit 1
    }
    
    # node/npm only required when installing hooks (TypeScript build)
    if ($Hooks -and ($nodeVersion -eq "NOT_FOUND" -or $npmVersion -eq "NOT_FOUND")) {
        Write-ErrorMsg "Node.js and npm are required to install OpenCode hooks."
        exit 1
    }
    
    Write-SuccessMsg "Git $gitVersion"
    if ($nodeVersion -ne "NOT_FOUND") { Write-SuccessMsg "Node.js $nodeVersion" } else { Write-WarningMsg "Node.js not found (only needed for -Hooks)" }
    if ($npmVersion -ne "NOT_FOUND") { Write-SuccessMsg "npm $npmVersion" } else { Write-WarningMsg "npm not found (only needed for -Hooks)" }
    
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
    
    if (-not $SkipGA -and $InstallGA) {
        Write-Step "Installing GA..."
        if (-not $DryRun) {
            Install-GA -Action "install"
        } else {
            Write-InfoMsg "[DRY RUN] Would install GA to $GA_DIR"
        }
    }
    
    if (-not $SkipSDD -and $InstallSDD) {
        Write-Step "Installing SDD Orchestrator..."
        if (-not $DryRun) {
            Install-SDD -Action "install" -TargetDir $script:TargetPath
        } else {
            Write-InfoMsg "[DRY RUN] Would install SDD Orchestrator in $script:TargetPath"
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
    
    if ($InstallGA -or $InstallSDD -or $Hooks -or $Biome) {
        Write-Step "Configuring project..."
        if (-not $DryRun) {
            Set-ProjectConfiguration -Provider $Provider -TargetDir $script:TargetPath -SkipGA:$SkipGA -InstallBiome:$false -ProjectType $Type
        } else {
            Write-InfoMsg "[DRY RUN] Would configure project in $script:TargetPath"
            if ($Provider) {
                Write-InfoMsg "[DRY RUN] Would set provider to: $Provider"
            }
            if ($Type) {
                Write-InfoMsg "[DRY RUN] Would apply project type: $Type"
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

    if ($Biome) {
        Write-Step "Installing Biome baseline..."
        if (-not $DryRun) {
            Install-Biome -Action "install" -TargetDir $script:TargetPath
        } else {
            Write-InfoMsg "[DRY RUN] Would install optional Biome baseline"
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
    
    Write-Host "This will install GA + SDD Orchestrator in your project." -ForegroundColor $WHITE
    Write-Host ""
    
    Write-Step "Checking prerequisites..."
    $prereqStatus = Get-Prerequisites
    
    $gitVersion = $prereqStatus.GitVersion
    $nodeVersion = $prereqStatus.NodeVersion
    $npmVersion = $prereqStatus.NpmVersion
    $vscodeAvailable = $prereqStatus.VSCodeAvailable
    
    if ($gitVersion -eq "NOT_FOUND") {
        Write-ErrorMsg "Missing prerequisite: Git is required."
        exit 1
    }
    
    Write-SuccessMsg "Git $gitVersion"
    if ($nodeVersion -ne "NOT_FOUND") { Write-SuccessMsg "Node.js $nodeVersion" } else { Write-WarningMsg "Node.js not found (only needed for -Hooks)" }
    if ($npmVersion -ne "NOT_FOUND") { Write-SuccessMsg "npm $npmVersion" } else { Write-WarningMsg "npm not found (only needed for -Hooks)" }
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
    $script:InstallGA = Ask-YesNo -Prompt "Install GA (AI code review)?" -Default "y"
    $script:InstallSDD = Ask-YesNo -Prompt "Install SDD Orchestrator (spec-first dev)?" -Default "y"
    $script:InstallVSCode = $false
    if ($vscodeAvailable) {
        $script:InstallVSCode = Ask-YesNo -Prompt "Install VS Code extensions?" -Default "y"
    }
    $script:Biome = Ask-YesNo -Prompt "Install optional Biome baseline (minimal lint/format rules)?" -Default "n"
    
    Write-Host ""
    
    # Summary
    Write-Host "Will install:" -ForegroundColor $WHITE
    if ($script:InstallGA) { Write-Host "  - GA" }
    if ($script:InstallSDD) { Write-Host "  - SDD Orchestrator" }
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
    if ($script:InstallGA) {
        Write-Step "Installing GA..."
        Install-GA -Action "install" | Out-Null
        Write-SuccessMsg "GA installed"
    }
    
    if ($script:InstallSDD) {
        Write-Step "Installing SDD Orchestrator..."
        Install-SDD -Action "install" -TargetDir $script:TargetPath | Out-Null
        Write-SuccessMsg "SDD Orchestrator installed"
    }
    
    if ($script:InstallVSCode -and $vscodeAvailable) {
        Write-Step "Installing VS Code extensions..."
        Install-VSCodeExtensions -Action "install" | Out-Null
        Write-SuccessMsg "VS Code extensions installed"
    }
    
    # Configure project
    Write-Step "Configuring project..."
    $skipGaFlag = -not $script:InstallGA
    Set-ProjectConfiguration -Provider $script:Provider -TargetDir $script:TargetPath -SkipGA:$skipGaFlag -InstallBiome:$false -ProjectType $Type | Out-Null
    Write-SuccessMsg "Project configured"

    if ($script:Biome) {
        Write-Step "Installing Biome baseline..."
        Install-Biome -Action "install" -TargetDir $script:TargetPath | Out-Null
        Write-SuccessMsg "Biome baseline installed"
    }
    
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
    if ($script:InstallGA) { Write-Host "  - GA (Guardian Agent)" -ForegroundColor $CYAN }
    if ($script:InstallSDD) { Write-Host "  - SDD Orchestrator (SDD workflow)" -ForegroundColor $CYAN }
    if ($script:InstallVSCode) { Write-Host "  - VS Code Extensions" -ForegroundColor $CYAN }
    if ($script:Hooks) { Write-Host "  - OpenCode Command Hooks" -ForegroundColor $CYAN }
    if ($script:Biome) { Write-Host "  - Biome Baseline (optional)" -ForegroundColor $CYAN }
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor $YELLOW
    if ($script:InstallGA -and $script:Provider) { Write-Host "  1. Review .ga config (provider: $($script:Provider))" -ForegroundColor $WHITE }
    Write-Host "  2. Customize AGENTS.MD for your project" -ForegroundColor $WHITE
    if ($script:InstallSDD) { Write-Host "  3. Use SDD Orchestrator for spec-driven development" -ForegroundColor $WHITE }
    if ($script:InstallGA) { Write-Host "  4. Run 'ga review' before committing code" -ForegroundColor $WHITE }
    Write-Host ""
    Write-Host "Repository path: $RepoPath" -ForegroundColor $CYAN
    Write-Host ""
}

# Main Execution
if ($Help) {
    Show-Help
    exit 0
}

if ($ListTypes) {
    . (Join-Path $PSScriptRoot "lib\installer.ps1") 2>$null
    List-ProjectTypes
    exit 0
}

# Determine mode
$InteractiveMode = $true

if ($All) {
    $InteractiveMode = $false
    $InstallGA = $true
    $InstallSDD = $true
    $InstallVSCode = $true
}

if ($InstallGA -or $InstallSDD -or $InstallVSCode -or $UpdateAll -or $Hooks -or $Biome) {
    $InteractiveMode = $false
}

if ($InteractiveMode) {
    if (-not (Test-InteractiveEnvironment)) {
        Write-WarningMsg "Non-interactive environment detected, using automated mode with -All"
        $InteractiveMode = $false
        $InstallGA = $true
        $InstallSDD = $true
        $InstallVSCode = $true
    }
}

if ($InteractiveMode) {
    Invoke-InteractiveInstallation
} else {
    Invoke-AutomatedInstallation
}
