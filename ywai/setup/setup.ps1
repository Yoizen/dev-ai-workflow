# GA + SDD Orchestrator Setup — Main entry point
# Replaces: bootstrap.ps1, ga/install.ps1

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
    [switch]$Extensions,

    [string]$Type = "nest",
    [switch]$ListTypes
)

$ErrorActionPreference = "Stop"

# Script Directory Detection
$ScriptDir = Split-Path -Parent $PSCommandPath

# Source Library Modules
. "$ScriptDir\lib\ui.ps1"
. "$ScriptDir\lib\detector.ps1"
. "$ScriptDir\lib\installer.ps1"

# Configuration
$GA_REPO = "https://github.com/Yoizen/dev-ai-workflow.git"
$GA_DIR = Join-Path $env:USERPROFILE ".local\share\yoizen\dev-ai-workflow"

# ── Show Help ─────────────────────────────────────────────────────────────

function Show-Help {
    @"
GA + SDD Orchestrator — Setup

USAGE:
    .\setup.ps1 [OPTIONS] [target-directory]

INSTALLATION OPTIONS:
    -All                    Install everything (non-interactive)
    -InstallGA             Install only GA
    -InstallSDD            Install only SDD Orchestrator
    -InstallVSCode         Install only VS Code extensions
    -Extensions            Install extensions declared by the project type

SKIP OPTIONS:
    -SkipGA                Skip GA installation
    -SkipSDD               Skip SDD Orchestrator installation
    -SkipVSCode            Skip VS Code extensions

CONFIGURATION:
    -Provider <name>       AI provider: opencode, claude, gemini, ollama
    -Target <path>         Target directory (default: current directory)
    -Type <name>           Project type: nest, nest-angular, nest-react, python, dotnet, generic
    -ListTypes             List available project types

ADVANCED:
    -UpdateAll             Update all installed components
    -Force                 Force reinstall/overwrite
    -Silent                Minimal output
    -DryRun                Show what would happen without executing
    -Help                  Show this help message

EXAMPLES:
    .\setup.ps1                               # Interactive mode
    .\setup.ps1 -All                         # Install everything
    .\setup.ps1 -All -Provider claude       # Install with Claude provider
    .\setup.ps1 -InstallGA -InstallSDD       # Install GA and SDD only
    .\setup.ps1 -UpdateAll                  # Update all components
    .\setup.ps1 -All -DryRun                # Preview what would happen

PROVIDERS:
    opencode   OpenCode AI Coding Agent (default)
    claude     Anthropic Claude
    gemini     Google Gemini
    ollama     Ollama (local models)

For more information: https://github.com/Yoizen/dev-ai-workflow
"@
}

# ── Check Prerequisites ─────────────────────────────────────────────────

function Test-Prerequisites {
    Write-Step "Checking prerequisites..."
    
    $prereqStatus = Detect-Prerequisites
    $parts = $prereqStatus -split '\|'
    $gitVersion = $parts[0]
    $nodeVersion = $parts[1]
    $npmVersion = $parts[2]
    $vscodeStatus = $parts[3]

    if ($gitVersion -eq "not_found") {
        Write-Error "Git is required but not found."
        exit 1
    }

    if ($Extensions -and ($nodeVersion -eq "not_found" -or $npmVersion -eq "not_found")) {
        Write-Error "Node.js and npm may be required for some extensions."
        exit 1
    }

    Write-Success "Git $gitVersion"
    if ($nodeVersion -ne "not_found") {
        Write-Success "Node.js $nodeVersion"
    } else {
        Write-Warning "Node.js not found (may be needed for some extensions)"
    }
    if ($npmVersion -ne "not_found") {
        Write-Success "npm $npmVersion"
    } else {
        Write-Warning "npm not found (may be needed for some extensions)"
    }

    if ($vscodeStatus -eq "available") {
        Write-Success "VS Code CLI available"
    } else {
        Write-Warning "VS Code CLI not found (extensions will be skipped)"
        $script:SkipVSCode = $true
    }

    $script:VSCODE_STATUS = $vscodeStatus
}

# ── Resolve Target Directory ───────────────────────────────────────────

function Resolve-TargetDirectory {
    if ([string]::IsNullOrEmpty($script:TargetPath)) {
        $script:TargetPath = Get-Location
    }

    if (-not (Test-Path $script:TargetPath)) {
        Write-Error "Directory not found: $script:TargetPath"
        exit 1
    }

    $script:TargetPath = (Get-Item $script:TargetPath).FullName
    Write-Info "Target directory: $script:TargetPath"
}

# ── Ensure Git Repository ─────────────────────────────────────────────

function Initialize-GitRepository {
    $gitDir = Join-Path $script:TargetPath ".git"
    if (Test-Path $gitDir) { return }

    if ($DryRun) {
        Write-Info "[DRY RUN] Would initialize git repository"
        return
    }

    Write-Info "Initializing git repository..."
    Push-Location $script:TargetPath
    try {
        git init 2>$null | Out-Null
        Write-Success "Git repository initialized"
    } finally {
        Pop-Location
    }
}

# ── Run Installation ─────────────────────────────────────────────────

function Start-Installation {
    $configuredProject = $false

    if ($UpdateAll) {
        if ($DryRun) {
            Write-Info "[DRY RUN] Would update all components"
        } else {
            Update-AllComponents -TargetDir $script:TargetPath
        }
        return
    }

    # Install GA
    if (-not $SkipGA -and $InstallGA) {
        Write-Step "Installing GA..."
        if (-not $DryRun) {
            $forceFlag = -not $All.IsPresent
            Install-Ga -Action "install" -ForceUpdate:$forceFlag
        } else {
            Write-Info "[DRY RUN] Would install GA to $GA_DIR"
        }
    }

    # Install SDD
    if (-not $SkipSDD -and $InstallSDD) {
        Write-Step "Installing SDD Orchestrator..."
        if (-not $DryRun) {
            Install-Sdd -Action "install" -TargetDir $script:TargetPath
        } else {
            Write-Info "[DRY RUN] Would install SDD Orchestrator in $script:TargetPath"
        }
    }

    # Install VS Code
    if (-not $SkipVSCode -and $InstallVSCode -and $VSCODE_STATUS -eq "available") {
        Write-Step "Installing VS Code extensions..."
        if (-not $DryRun) {
            Install-VscodeExtensions -Action "install"
        } else {
            Write-Info "[DRY RUN] Would install VS Code extensions"
        }
    }

    Write-Step "Installing OpenCode CLI..."
    if (-not $DryRun) {
        Install-OpenCodeCli | Out-Null
    } else {
        Write-Info "[DRY RUN] Would install OpenCode CLI (npm i -g opencode-ai)"
    }

    # Configure Project
    if ($InstallGA -or $InstallSDD -or $Extensions) {
        Write-Step "Configuring project..."
        if (-not $DryRun) {
            $skipGaFlag = $SkipGA.IsPresent
            Configure-Project -Provider $Provider -TargetDir $script:TargetPath -SkipGA:$skipGaFlag -ProjectType $Type
        } else {
            Write-Info "[DRY RUN] Would configure project in $script:TargetPath"
            if ($Provider) { Write-Info "[DRY RUN] Provider: $Provider" }
            Write-Info "[DRY RUN] Project type: $Type"
        }
        $configuredProject = $true
    }

    if ($configuredProject) {
        $Extensions = $true
    }

    if ($Extensions -or $configuredProject) {
        Write-Step "Installing type extensions..."
        if (-not $DryRun) {
            Install-Extensions -Action "install" -TargetDir $script:TargetPath -ProjectType $Type
        } else {
            Write-Info "[DRY RUN] Would install type extensions for $Type"
        }
    }
}

# ── Show Next Steps ───────────────────────────────────────────────────

function Show-NextSteps {
    if ($Silent) { return }

    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "  Setup Complete!" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Configured:" -ForegroundColor White
    if ($InstallGA)     { Write-Host "  • GA (Guardian Agent)" -ForegroundColor Cyan }
    if ($InstallSDD)    { Write-Host "  • SDD Orchestrator" -ForegroundColor Cyan }
    if ($InstallVSCode) { Write-Host "  • VS Code Extensions" -ForegroundColor Cyan }
    if ($Extensions)    { Write-Host "  • Type Extensions ($Type)" -ForegroundColor Cyan }
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    if ($InstallGA -and $Provider) { Write-Host "  1. Review .ga config (provider: $Provider)" -ForegroundColor White }
    Write-Host "  2. Customize AGENTS.md for your project" -ForegroundColor White
    if ($InstallSDD) { Write-Host "  3. Use /sdd:new for spec-driven development" -ForegroundColor White }
    if ($InstallGA)  { Write-Host "  4. Run 'ga run' before committing code" -ForegroundColor White }
    Write-Host ""
    Write-Host "Repository path: $script:TargetPath" -ForegroundColor Cyan
    Write-Host ""
}

# ── Main ─────────────────────────────────────────────────────────────

if ($Help) {
    Show-Help
    exit 0
}

if ($ListTypes) {
    # List types from types.json if available
    $typesJson = Join-Path $ScriptDir "types\types.json"
    if (Test-Path $typesJson) {
        Write-Host "Available project types:" 
        Write-Host "  nest         - NestJS backend (TypeScript, Clean Architecture)"
        Write-Host "  nest-angular - NestJS + Angular fullstack (TypeScript, Clean Architecture)"
        Write-Host "  nest-react   - NestJS + React fullstack (TypeScript, Clean Architecture)"
        Write-Host "  python       - Python backend / scripts (FastAPI, Django, scripts)"
        Write-Host "  dotnet       - .NET / C# backend (ASP.NET Core, Clean Architecture)"
        Write-Host "  generic      - Generic project (language-agnostic defaults)"
        Write-Host ""
        Write-Host "default: nest"
    } else {
        Write-Host "Available: nest, nest-angular, nest-react, python, dotnet, generic"
    }
    exit 0
}

if ($All) {
    $InstallGA = $true
    $InstallSDD = $true
    $InstallVSCode = $true
    $Extensions = $true
}

# Auto-switch to non-interactive in CI environments
$IsInteractive = Test-InteractiveEnvironment
if ($All -and -not $IsInteractive) {
    Write-Warning "Non-interactive environment detected — using automated mode with -All"
}

# Banner
Write-Banner "GA + SDD Orchestrator — Setup"

if ($DryRun) {
    Write-Warning "DRY RUN MODE — no changes will be made"
    Write-Host ""
}

# Run installation
Resolve-TargetDirectory
Test-Prerequisites
Initialize-GitRepository
Start-Installation

if ($DryRun) {
    Write-Warning "DRY RUN completed — no changes made"
} else {
    Show-NextSteps
}
