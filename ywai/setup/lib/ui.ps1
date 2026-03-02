# Shared UI utilities: colors, Write-* functions, prompts, env detection
# Compatible with both PowerShell 5.1 and 7+

# Guard against double-sourcing
if ($null -ne $Global:_GA_UI_LOADED) { return }
$Global:_GA_UI_LOADED = $true

# Colors
$script:RED = 'Red'
$script:GREEN = 'Green'
$script:YELLOW = 'Yellow'
$script:BLUE = 'Blue'
$script:CYAN = 'Cyan'
$script:WHITE = 'White'
$script:GRAY = 'DarkGray'
$script:BOLD = 'White'

# SILENT can be set externally to suppress non-error output
$script:SILENT = $false

# ── Write helpers ─────────────────────────────────────────────────────────────

function Write-Banner {
    param([string]$Title = "GA + SDD Orchestrator — Setup")
    if ($SILENT) { return }
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $CYAN
    Write-Host "  $Title" -ForegroundColor $CYAN
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor $CYAN
    Write-Host ""
}

function Write-Step {
    param([string]$Message)
    if ($SILENT) { return }
    Write-Host ""
    Write-Host "[>] $Message" -ForegroundColor $GREEN
}

function Write-Success {
    param([string]$Message)
    if ($SILENT) { return }
    Write-Host "  [OK] $Message" -ForegroundColor $GREEN
}

function Write-Info {
    param([string]$Message)
    if ($SILENT) { return }
    Write-Host "  [i] $Message" -ForegroundColor $CYAN
}

function Write-Warning {
    param([string]$Message)
    Write-Host "  [!] $Message" -ForegroundColor $YELLOW
}

function Write-Error {
    param([string]$Message)
    Write-Host "  [X] $Message" -ForegroundColor $RED
}

# ── Utilities ─────────────────────────────────────────────────────────────

function Test-Command {
    param([string]$Cmd)
    $null = Get-Command $Cmd -ErrorAction SilentlyContinue
    return $?
}

function Ask-YesNo {
    param(
        [string]$Prompt,
        [string]$Default = "y"
    )
    if ($Default -eq "y") {
        $reply = Read-Host "$Prompt [Y/n]"
        if ([string]::IsNullOrEmpty($reply)) { $reply = "y" }
    } else {
        $reply = Read-Host "$Prompt [y/N]"
        if ([string]::IsNullOrEmpty($reply)) { $reply = "n" }
    }
    return $reply -match '^[Yy]'
}

# ── Environment detection ─────────────────────────────────────────────────

function Test-InteractiveEnvironment {
    # Not interactive if:
    # - No stdin (pipeline)
    # - CI variables set
    # - TERM=dumb
    # - Noninteractive DEBIAN_FRONTEND
    
    if ($Host.Name -ne "ConsoleHost") { return $false }
    if ($PSInteractiveEnvironment) { return $true }
    
    $ciVars = @('CI', 'CONTINUOUS_INTEGRATION', 'JENKINS_HOME', 'TRAVIS', 
                'CIRCLECI', 'GITLAB_CI', 'GITHUB_ACTIONS', 'BUILDKITE', 'DRONE')
    foreach ($v in $ciVars) {
        if ($null -ne (Get-Variable -Name $v -ErrorAction SilentlyContinue).Value) {
            return $false
        }
    }
    
    if ($env:TERM -eq "dumb") { return $false }
    if ($env:DEBIAN_FRONTEND -eq "noninteractive") { return $false }
    
    return $true
}

# Export functions for use in other scripts
Export-ModuleMember -Function @(
    'Write-Banner', 'Write-Step', 'Write-Success', 'Write-Info', 
    'Write-Warning', 'Write-Error', 'Test-Command', 'Ask-YesNo', 
    'Test-InteractiveEnvironment'
)
