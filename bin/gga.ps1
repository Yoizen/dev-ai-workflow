# Guardian Agent - Windows PowerShell Version
# Provider-agnostic code review using AI

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Command = "help",
    
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_DIR = Split-Path -Parent $SCRIPT_DIR

# Get version from package.json
function Get-GgaVersion {
    $packageJsonPaths = @(
        (Join-Path $PROJECT_DIR "package.json"),
        (Join-Path $env:USERPROFILE "AppData\Local\gga\package.json"),
        (Join-Path $env:USERPROFILE ".local\share\yoizen\gga-copilot\package.json")
    )
    
    foreach ($path in $packageJsonPaths) {
        if (Test-Path $path) {
            try {
                $pkg = Get-Content $path -Raw | ConvertFrom-Json
                if ($pkg.version) {
                    return $pkg.version
                }
            } catch {}
        }
    }
    return "unknown"
}

$VERSION = Get-GgaVersion

# Resolve LIB_DIR - check multiple locations
$LIB_DIR = $null
$possible_lib_dirs = @(
    (Join-Path $PROJECT_DIR "lib"),
    (Join-Path $SCRIPT_DIR "lib"),
    (Join-Path $env:USERPROFILE "AppData\Local\gga\lib"),
    (Join-Path $env:USERPROFILE ".local\share\gga\lib")
)

foreach ($dir in $possible_lib_dirs) {
    if (Test-Path $dir) {
        $LIB_DIR = $dir
        break
    }
}

if (-not $LIB_DIR) {
    Write-Host "[ERROR] Library directory not found. Please reinstall GGA." -ForegroundColor Red
    exit 1
}

# Source library functions
. (Join-Path $LIB_DIR "providers.ps1")
. (Join-Path $LIB_DIR "cache.ps1")

# Defaults
$DEFAULT_FILE_PATTERNS = "*"
$DEFAULT_PROVIDER = "opencode"
$DEFAULT_RULES_FILE = "REVIEW.md"
$DEFAULT_STRICT_MODE = "true"

# Helper Functions
function Log-Success { param([string]$Message) Write-Host "[OK] $Message" -ForegroundColor Green }
function Log-Error { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Log-Warning { param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Log-Info { param([string]$Message) Write-Host "[INFO] $Message" -ForegroundColor Cyan }

function Print-Banner {
    Write-Host ""
    Write-Host "========================================================================" -ForegroundColor Cyan
    Write-Host "  Guardian Agent v$VERSION" -ForegroundColor Cyan
    Write-Host "  Provider-agnostic code review using AI" -ForegroundColor Cyan
    Write-Host "========================================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Print-Help {
    Print-Banner
    Write-Host "USAGE:" -ForegroundColor White
    Write-Host "  gga <command> [options]"
    Write-Host ""
    Write-Host "COMMANDS:" -ForegroundColor White
    Write-Host "  run [--no-cache]  Run code review on staged files"
    Write-Host "  install           Install git pre-commit hook in current repo"
    Write-Host "  uninstall         Remove git pre-commit hook from current repo"
    Write-Host "  config            Show current configuration"
    Write-Host "  init              Create a sample .gga config file"
    Write-Host "  cache clear       Clear cache for current project"
    Write-Host "  cache clear-all   Clear all cached data"
    Write-Host "  cache status      Show cache status"
    Write-Host "  help              Show this help message"
    Write-Host "  version           Show version"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor White
    Write-Host "  gga init          # Create sample config"
    Write-Host "  gga install       # Install git hook"
    Write-Host "  gga run           # Run review (with cache)"
    Write-Host "  gga run --no-cache # Run review (ignore cache)"
    Write-Host ""
}

function Load-Config {
    # Reset to defaults
    $script:PROVIDER = $DEFAULT_PROVIDER
    $script:FILE_PATTERNS = $DEFAULT_FILE_PATTERNS
    $script:EXCLUDE_PATTERNS = ""
    $script:RULES_FILE = $DEFAULT_RULES_FILE
    $script:STRICT_MODE = $DEFAULT_STRICT_MODE

    # Load global config
    $GLOBAL_CONFIG = "$env:USERPROFILE\.config\gga\config"
    if (Test-Path $GLOBAL_CONFIG) {
        Get-Content $GLOBAL_CONFIG | ForEach-Object {
            if ($_ -match '^([A-Z_]+)="?([^"]+)"?$') {
                $key = $Matches[1]
                $value = $Matches[2]
                Set-Variable -Name $key -Value $value -Scope Script
            }
        }
    }

    # Load project config (overrides global)
    $PROJECT_CONFIG = ".gga"
    if (Test-Path $PROJECT_CONFIG) {
        Get-Content $PROJECT_CONFIG | ForEach-Object {
            if ($_ -match '^([A-Z_]+)="?([^"]+)"?$') {
                $key = $Matches[1]
                $value = $Matches[2]
                Set-Variable -Name $key -Value $value -Scope Script
            }
        }
    }

    # Environment variable override
    if ($env:GGA_PROVIDER) {
        $script:PROVIDER = $env:GGA_PROVIDER
    }
}

function Cmd-Init {
    Print-Banner
    
    $PROJECT_CONFIG = ".gga"
    
    if ((Test-Path $PROJECT_CONFIG) -and -not $Args -contains "-f" -and -not $Args -contains "--force") {
        Log-Error "Config file already exists: $PROJECT_CONFIG"
        Write-Host "Use 'gga init --force' to overwrite"
        exit 1
    }

    $config_content = @"
# GGA Configuration File
# See 'gga help' for all options

# AI provider to use (claude, gemini, codex, ollama:<model>, opencode[:github-copilot/<model>])
# Examples:
#   PROVIDER="opencode"
#   PROVIDER="opencode:github-copilot/claude-haiku-4.5"
#   PROVIDER="opencode:github-copilot/gemini-3-flash"
PROVIDER="opencode"

# File patterns to review (comma-separated)
FILE_PATTERNS="*"

# Patterns to exclude from review
EXCLUDE_PATTERNS="*.test.ts,*.spec.ts,*.test.tsx,*.spec.tsx,*.d.ts"

# File containing code review rules
RULES_FILE="REVIEW.md"

# Strict mode: fail if AI response is ambiguous
STRICT_MODE="true"
"@

    Set-Content -Path $PROJECT_CONFIG -Value $config_content -Encoding UTF8
    
    Log-Success "Created config file: $PROJECT_CONFIG"
    Write-Host ""
    Log-Info "Next steps:"
    Write-Host "  1. Edit $PROJECT_CONFIG to set your preferred provider"
    Write-Host "  2. Create $DEFAULT_RULES_FILE with your coding standards"
    Write-Host "  3. Run: gga install"
    Write-Host ""
}

function Cmd-Config {
    Print-Banner
    Load-Config

    Write-Host "Current Configuration:" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Config Files:" -ForegroundColor White
    $GLOBAL_CONFIG = "$env:USERPROFILE\.config\gga\config"
    $PROJECT_CONFIG = ".gga"
    
    if (Test-Path $GLOBAL_CONFIG) {
        Write-Host "  Global:  $GLOBAL_CONFIG" -ForegroundColor Gray
    } else {
        Write-Host "  Global:  (not found)" -ForegroundColor Gray
    }
    
    if (Test-Path $PROJECT_CONFIG) {
        Write-Host "  Project: $PROJECT_CONFIG" -ForegroundColor Gray
    } else {
        Write-Host "  Project: (not found)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "Active Settings:" -ForegroundColor White
    Write-Host "  PROVIDER:         $PROVIDER" -ForegroundColor Gray
    Write-Host "  FILE_PATTERNS:    $FILE_PATTERNS" -ForegroundColor Gray
    Write-Host "  EXCLUDE_PATTERNS: $EXCLUDE_PATTERNS" -ForegroundColor Gray
    Write-Host "  RULES_FILE:       $RULES_FILE" -ForegroundColor Gray
    Write-Host "  STRICT_MODE:      $STRICT_MODE" -ForegroundColor Gray
    Write-Host ""
}

function Cmd-Version {
    Write-Host "Guardian Agent v$VERSION"
}

function Cmd-Install {
    Print-Banner
    
    $git_root = Get-GitRoot
    if ([string]::IsNullOrEmpty($git_root)) {
        Log-Error "Not in a git repository"
        exit 1
    }
    
    $hooks_dir = Join-Path $git_root ".git\hooks"
    $hook_file = Join-Path $hooks_dir "pre-commit"
    
    if (Test-Path $hook_file) {
        $content = Get-Content $hook_file -Raw
        if ($content -match "gga") {
            Log-Warning "GGA hook already installed"
            return
        }
        
        # Backup existing hook
        $backup = "$hook_file.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item $hook_file $backup
        Log-Info "Backed up existing hook to: $backup"
    }
    
    $hook_content = @"
#!/bin/sh
# GGA Pre-commit hook
gga run
"@
    
    Set-Content -Path $hook_file -Value $hook_content -Encoding UTF8
    Log-Success "Installed pre-commit hook"
    Log-Info "GGA will now run automatically before each commit"
}

function Cmd-Uninstall {
    Print-Banner
    
    $git_root = Get-GitRoot
    if ([string]::IsNullOrEmpty($git_root)) {
        Log-Error "Not in a git repository"
        exit 1
    }
    
    $hooks_dir = Join-Path $git_root ".git\hooks"
    $hook_file = Join-Path $hooks_dir "pre-commit"
    
    if (-not (Test-Path $hook_file)) {
        Log-Warning "No pre-commit hook found"
        return
    }
    
    $content = Get-Content $hook_file -Raw
    if ($content -notmatch "gga") {
        Log-Warning "Pre-commit hook does not contain GGA"
        return
    }
    
    Remove-Item $hook_file -Force
    Log-Success "Removed pre-commit hook"
    
    # Restore backup if exists
    $backups = Get-ChildItem -Path $hooks_dir -Filter "pre-commit.backup.*" | Sort-Object -Descending
    if ($backups.Count -gt 0) {
        $latest_backup = $backups[0].FullName
        Copy-Item $latest_backup $hook_file
        Log-Info "Restored backup from: $latest_backup"
    }
}

function Cmd-Run {
    Load-Config
    
    $no_cache = $Args -contains "--no-cache"
    
    Log-Info "Running code review with provider: $PROVIDER"
    
    if (-not (Validate-Provider $PROVIDER)) {
        exit 1
    }
    
    $staged_files = Get-StagedFiles
    
    if ($staged_files.Count -eq 0) {
        Log-Warning "No staged files to review"
        exit 0
    }
    
    Log-Info "Found $($staged_files.Count) staged file(s)"
    
    # Check for rules file
    if (-not (Test-Path $RULES_FILE)) {
        Log-Warning "Rules file not found: $RULES_FILE"
        Log-Info "Create one or run 'gga init' to get started"
    }
    
    $files_to_review = @()
    $skipped_files = @()
    
    foreach ($file in $staged_files) {
        if (-not (Test-Path $file)) {
            continue
        }
        
        # Check file patterns
        $should_review = $false
        if ($FILE_PATTERNS -eq "*") {
            $should_review = $true
        } else {
            foreach ($pattern in ($FILE_PATTERNS -split ",")) {
                if ($file -like $pattern.Trim()) {
                    $should_review = $true
                    break
                }
            }
        }
        
        # Check exclude patterns
        if ($should_review -and $EXCLUDE_PATTERNS) {
            foreach ($pattern in ($EXCLUDE_PATTERNS -split ",")) {
                if ($file -like $pattern.Trim()) {
                    $should_review = $false
                    break
                }
            }
        }
        
        if (-not $should_review) {
            $skipped_files += $file
            continue
        }
        
        # Check cache
        if (-not $no_cache) {
            $cached_status = Get-CachedFileStatus $file
            if ($cached_status -eq "PASS") {
                Log-Info "Cache hit (PASS): $file"
                continue
            }
        }
        
        $files_to_review += $file
    }
    
    if ($skipped_files.Count -gt 0) {
        Log-Info "Skipped $($skipped_files.Count) file(s) (pattern mismatch)"
    }
    
    if ($files_to_review.Count -eq 0) {
        Log-Success "All files passed (from cache or skipped)"
        exit 0
    }
    
    Log-Info "Reviewing $($files_to_review.Count) file(s)..."
    
    $all_passed = $true
    
    foreach ($file in $files_to_review) {
        Write-Host ""
        Log-Info "Reviewing: $file"
        
        $content = Get-Content $file -Raw -Encoding UTF8
        
        $rules_content = ""
        if (Test-Path $RULES_FILE) {
            $rules_content = Get-Content $RULES_FILE -Raw -Encoding UTF8
        }
        
        $prompt = @"
Review this code file for issues. Apply the following rules:

$rules_content

File: $file
```
$content
```

Respond with ONLY one of:
- "PASS" if no issues found
- "FAIL: <brief reason>" if issues found

Be strict but fair. Focus on real problems, not style preferences.
"@
        
        $response = Execute-Provider $PROVIDER $prompt
        
        if ($response -match "^PASS") {
            Log-Success "PASS: $file"
            Set-CachedFileStatus $file "PASS"
        } else {
            Log-Error "FAIL: $file"
            Write-Host $response -ForegroundColor Yellow
            Set-CachedFileStatus $file "FAIL"
            $all_passed = $false
        }
    }
    
    Write-Host ""
    
    if ($all_passed) {
        Log-Success "All files passed review"
        exit 0
    } else {
        Log-Error "Some files failed review"
        if ($STRICT_MODE -eq "true") {
            exit 1
        } else {
            Log-Warning "Continuing anyway (STRICT_MODE=false)"
            exit 0
        }
    }
}

function Cmd-Cache {
    $subcommand = if ($Args.Count -gt 0) { $Args[0] } else { "status" }
    
    switch ($subcommand.ToLower()) {
        "clear" {
            Clear-ProjectCache
        }
        "clear-all" {
            Clear-AllCache
        }
        "status" {
            Get-CacheStatus
        }
        default {
            Log-Error "Unknown cache command: $subcommand"
            Write-Host "Usage: gga cache {clear|clear-all|status}"
            exit 1
        }
    }
}

# Main command dispatcher
switch ($Command.ToLower()) {
    "init" { Cmd-Init }
    "config" { Cmd-Config }
    "version" { Cmd-Version }
    "install" { Cmd-Install }
    "uninstall" { Cmd-Uninstall }
    "run" { Cmd-Run }
    "review" { Cmd-Run }
    "cache" { Cmd-Cache }
    "help" { Print-Help }
    default {
        Log-Error "Unknown command: $Command"
        Write-Host "Run 'gga help' for usage information"
        exit 1
    }
}
