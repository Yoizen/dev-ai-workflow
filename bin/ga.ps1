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
function Get-GaVersion {
    $packageJsonPaths = @(
        (Join-Path $SCRIPT_DIR "package.json"),
        (Join-Path $PROJECT_DIR "package.json"),
        (Join-Path $env:USERPROFILE "AppData\Local\ga\package.json"),
        (Join-Path $env:USERPROFILE ".local\share\yoizen\dev-ai-workflow\package.json")
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

$VERSION = Get-GaVersion

# Resolve LIB_DIR - check multiple locations
$LIB_DIR = $null
$possible_lib_dirs = @(
    (Join-Path $PROJECT_DIR "lib"),
    (Join-Path $SCRIPT_DIR "lib"),
    (Join-Path $env:USERPROFILE "AppData\Local\ga\lib"),
    (Join-Path $env:USERPROFILE ".local\share\ga\lib")
)

foreach ($dir in $possible_lib_dirs) {
    if (Test-Path $dir) {
        $LIB_DIR = $dir
        break
    }
}

if (-not $LIB_DIR) {
    Write-Host "[ERROR] Library directory not found. Please reinstall GA." -ForegroundColor Red
    exit 1
}

# Source library functions
. (Join-Path $LIB_DIR "providers.ps1")
. (Join-Path $LIB_DIR "cache.ps1")

# Defaults
$DEFAULT_FILE_PATTERNS = "*"
$DEFAULT_PROVIDER = ""
$DEFAULT_RULES_FILE = "AGENTS.md"
$DEFAULT_STRICT_MODE = "true"
$DEFAULT_TIMEOUT = "300"

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
    Write-Host "  ga <command> [options]"
    Write-Host ""
    Write-Host "COMMANDS:" -ForegroundColor White
    Write-Host "  run [--no-cache]  Run code review on staged files (alias: review)"
    Write-Host "  install           Install git pre-commit hook (default)"
    Write-Host "  install --commit-msg"
    Write-Host "                    Install git commit-msg hook (for commit message validation)"
    Write-Host "  uninstall         Remove git hooks from current repo"
    Write-Host "  config            Show current configuration"
    Write-Host "  init              Create a sample .ga config file"
    Write-Host "  cache clear       Clear cache for current project"
    Write-Host "  cache clear-all   Clear all cached data"
    Write-Host "  cache status      Show cache status"
    Write-Host "  help              Show this help message"
    Write-Host "  version           Show version"
    Write-Host ""
    Write-Host "RUN OPTIONS:" -ForegroundColor White
    Write-Host "  --no-cache        Force review all files, ignoring cache"
    Write-Host "  --ci              CI mode: review files changed in last commit (HEAD~1..HEAD)"
    Write-Host "                    Use this in GitLab CI, GitHub Actions, etc."
    Write-Host "  --pr-mode         PR mode: review all files changed in the full PR"
    Write-Host "                    Auto-detects base branch (main/master/develop)"
    Write-Host "  --diff-only       With --pr-mode: send only diffs (faster, cheaper)"
    Write-Host ""
    Write-Host "CONFIG OPTIONS:" -ForegroundColor White
    Write-Host "  PROVIDER           AI provider to use (required)"
    Write-Host "  FILE_PATTERNS      File patterns to review (default: *)"
    Write-Host "  EXCLUDE_PATTERNS   Patterns to exclude from review"
    Write-Host "  RULES_FILE         File containing review rules (default: AGENTS.md)"
    Write-Host "  STRICT_MODE        Fail on ambiguous AI response (default: true)"
    Write-Host "  TIMEOUT            Max seconds to wait for AI response (default: 300)"
    Write-Host "  PR_BASE_BRANCH     Base branch for --pr-mode (default: auto-detect)"
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor White
    Write-Host "  ga init          # Create sample config"
    Write-Host "  ga install       # Install pre-commit hook"
    Write-Host "  ga install --commit-msg  # Install commit-msg hook"
    Write-Host "  ga run           # Run review (with cache)"
    Write-Host "  ga review        # Alias for 'ga run'"
    Write-Host "  ga run --no-cache # Run review (ignore cache)"
    Write-Host "  ga run --ci      # Run review in CI (last commit)"
    Write-Host ""
    Write-Host "ENVIRONMENT VARIABLES:" -ForegroundColor White
    Write-Host "  GA_PROVIDER       Override provider from config"
    Write-Host "  GA_TIMEOUT        Override timeout from config (seconds)"
    Write-Host ""
}

function Load-Config {
    # Reset to defaults
    $script:PROVIDER = $DEFAULT_PROVIDER
    $script:FILE_PATTERNS = $DEFAULT_FILE_PATTERNS
    $script:EXCLUDE_PATTERNS = ""
    $script:RULES_FILE = $DEFAULT_RULES_FILE
    $script:STRICT_MODE = $DEFAULT_STRICT_MODE
    $script:TIMEOUT = $DEFAULT_TIMEOUT
    $script:PR_BASE_BRANCH = ""

    # Load global config
    $GLOBAL_CONFIG = "$env:USERPROFILE\.config\ga\config"
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
    $PROJECT_CONFIG = ".ga"
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
    if ($env:GA_PROVIDER) {
        $script:PROVIDER = $env:GA_PROVIDER
    }
    if ($env:GA_TIMEOUT) {
        $script:TIMEOUT = $env:GA_TIMEOUT
    }
}

function Cmd-Init {
    Print-Banner
    
    $PROJECT_CONFIG = ".ga"
    
    if ((Test-Path $PROJECT_CONFIG) -and -not $Args -contains "-f" -and -not $Args -contains "--force") {
        Log-Error "Config file already exists: $PROJECT_CONFIG"
        Write-Host "Use 'ga init --force' to overwrite"
        exit 1
    }

    $config_content = @"
# Guardian Agent Configuration
# https://github.com/Yoizen/dev-ai-workflow

# AI Provider (required)
# Options: claude, gemini, codex, opencode, ollama:<model>, lmstudio[:model], github:<model>
# Examples:
#   PROVIDER="claude"
#   PROVIDER="gemini"
#   PROVIDER="codex"
#   PROVIDER="opencode"
#   PROVIDER="opencode:anthropic/claude-opus-4-5"
#   PROVIDER="ollama:llama3.2"
#   PROVIDER="ollama:codellama"
#   PROVIDER="lmstudio"
#   PROVIDER="lmstudio:qwen2.5-coder-7b-instruct"
#   PROVIDER="github:gpt-4o"
#   PROVIDER="github:deepseek-r1"
PROVIDER="opencode"

# File patterns to include in review (comma-separated)
# Default: * (all files)
# Examples:
#   FILE_PATTERNS="*.ts,*.tsx"
#   FILE_PATTERNS="*.py"
#   FILE_PATTERNS="*.go,*.mod"
FILE_PATTERNS="*.ts,*.tsx,*.js,*.jsx"

# File patterns to exclude from review (comma-separated)
# Default: none
# Examples:
#   EXCLUDE_PATTERNS="*.test.ts,*.spec.ts"
#   EXCLUDE_PATTERNS="*_test.go,*.mock.ts"
EXCLUDE_PATTERNS="*.test.ts,*.spec.ts,*.test.tsx,*.spec.tsx,*.d.ts"

# File containing code review rules
# Default: AGENTS.md
RULES_FILE="AGENTS.md"

# Strict mode: fail if AI response is ambiguous
# Default: true
STRICT_MODE="true"

# Timeout in seconds for AI provider response
# Default: 300 (5 minutes)
# Increase for large changesets or slow connections
TIMEOUT="300"

# Base branch for --pr-mode (auto-detects main/master/develop if empty)
# Default: auto-detect
# PR_BASE_BRANCH="main"
"@

    Set-Content -Path $PROJECT_CONFIG -Value $config_content -Encoding UTF8
    
    Log-Success "Created config file: $PROJECT_CONFIG"
    Write-Host ""
    Log-Info "Next steps:"
    Write-Host "  1. Edit $PROJECT_CONFIG to set your preferred provider"
    Write-Host "  2. Create $DEFAULT_RULES_FILE with your coding standards"
    Write-Host "  3. Run: ga install"
    Write-Host ""
}

function Cmd-Config {
    Print-Banner
    Load-Config

    Write-Host "Current Configuration:" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Config Files:" -ForegroundColor White
    $GLOBAL_CONFIG = "$env:USERPROFILE\.config\ga\config"
    $PROJECT_CONFIG = ".ga"
    
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
    Write-Host "  TIMEOUT:          $TIMEOUT" -ForegroundColor Gray
    Write-Host "  PR_BASE_BRANCH:   $(if ($PR_BASE_BRANCH) { $PR_BASE_BRANCH } else { 'auto-detect' })" -ForegroundColor Gray
    Write-Host ""
}

function Cmd-Version {
    Write-Host "Guardian Agent v$VERSION"
}

function Build-GaHookBlock {
    param([string]$HookType)
    $runLine = if ($HookType -eq "commit-msg") { 'ga run "$1" || exit 1' } else { 'ga run || exit 1' }
    return @(
        "# ======== GA START ========",
        "# Guardian Agent - Code Review",
        $runLine,
        "# ======== GA END ========"
    )
}

function Install-HookFile {
    param([string]$HookPath, [string]$HookType)
    $gaBlock = Build-GaHookBlock $HookType
    $gaText = ($gaBlock -join "`n")

    if (Test-Path $HookPath) {
        $content = Get-Content -Path $HookPath -Raw
        if ($content -match [regex]::Escape("# ======== GA START ========")) {
            Log-Warning "Guardian Agent hook already installed in $HookType"
            return
        }
        if ($content -match "ai-code-review") {
            $content = $content -replace "ai-code-review", "ga"
            $content = $content -replace "AI Code Review", "Guardian Agent"
            Set-Content -Path $HookPath -Value $content -Encoding UTF8
            Log-Success "Migrated hook to use 'ga'"
            return
        }

        $lines = Get-Content -Path $HookPath
        $exitIndex = -1
        for ($i = $lines.Count - 1; $i -ge 0; $i--) {
            if ($lines[$i] -match '^\s*exit\s*\d*\s*$') {
                $exitIndex = $i
                break
            }
        }
        if ($exitIndex -ge 0) {
            $before = if ($exitIndex -gt 0) { $lines[0..($exitIndex - 1)] } else { @() }
            $after = $lines[$exitIndex..($lines.Count - 1)]
            $newLines = @($before + @("") + $gaBlock + @("") + $after)
            Set-Content -Path $HookPath -Value $newLines -Encoding UTF8
            Log-Success "Inserted Guardian Agent before exit in $HookType hook: $HookPath"
            return
        }

        Add-Content -Path $HookPath -Value ("`n" + $gaText + "`n")
        Log-Success "Appended Guardian Agent to existing $HookType hook: $HookPath"
        return
    }

    $hookContent = @"
#!/bin/sh

# ======== GA START ========
# Guardian Agent - Code Review
$(if ($HookType -eq "commit-msg") { 'ga run "$1" || exit 1' } else { 'ga run || exit 1' })
# ======== GA END ========
"@
    Set-Content -Path $HookPath -Value $hookContent -Encoding UTF8
    Log-Success "Installed $HookType hook: $HookPath"
}

function Cmd-Install {
    Print-Banner

    $installArgs = @($script:Args)
    $hookType = if (
        $installArgs -contains "--commit-msg" -or
        $installArgs -contains "-commit-msg" -or
        $installArgs -contains "commit-msg"
    ) { "commit-msg" } else { "pre-commit" }

    $git_root = Get-GitRoot
    if ([string]::IsNullOrEmpty($git_root)) {
        Log-Error "Not in a git repository"
        exit 1
    }

    $hooks_dir = (& git rev-parse --git-path hooks 2>$null).Trim()
    if ([string]::IsNullOrWhiteSpace($hooks_dir)) {
        $hooks_dir = Join-Path $git_root ".git\hooks"
    }
    New-Item -ItemType Directory -Path $hooks_dir -Force | Out-Null
    $hookFile = Join-Path $hooks_dir $hookType

    Install-HookFile -HookPath $hookFile -HookType $hookType
}

function Remove-GaFromHook {
    param([string]$HookPath, [string]$HookType)

    $content = Get-Content -Path $HookPath -Raw
    if ($content -notmatch "ga") {
        return $false
    }

    if ($content -match [regex]::Escape("# ======== GA START ========")) {
        $updated = [regex]::Replace(
            $content,
            '(?ms)^\# ======== GA START ========.*?^\# ======== GA END ========\r?\n?',
            ''
        ).Trim()
        if ([string]::IsNullOrWhiteSpace($updated) -or $updated -match '^#!/bin/sh\s*$') {
            Remove-Item -Path $HookPath -Force
            Log-Success "Removed $HookType hook (was GA-only)"
        } else {
            Set-Content -Path $HookPath -Value $updated -Encoding UTF8
            Log-Success "Removed Guardian Agent from $HookType hook"
        }
        return $true
    }

    # Legacy cleanup
    $lines = Get-Content -Path $HookPath | Where-Object {
        $_ -notmatch '# Guardian Agent' -and $_ -notmatch '^\s*ga run'
    }
    if ($lines.Count -eq 0 -or ($lines.Count -eq 1 -and $lines[0] -match '^#!/bin/sh\s*$')) {
        Remove-Item -Path $HookPath -Force
        Log-Success "Removed $HookType hook"
    } else {
        Set-Content -Path $HookPath -Value $lines -Encoding UTF8
        Log-Success "Removed Guardian Agent from $HookType hook"
    }
    return $true
}

function Cmd-Uninstall {
    Print-Banner

    $git_root = Get-GitRoot
    if ([string]::IsNullOrEmpty($git_root)) {
        Log-Error "Not in a git repository"
        exit 1
    }

    $hooks_dir = (& git rev-parse --git-path hooks 2>$null).Trim()
    if ([string]::IsNullOrWhiteSpace($hooks_dir)) {
        $hooks_dir = Join-Path $git_root ".git\hooks"
    }

    $foundAny = $false
    foreach ($hookType in @("pre-commit", "commit-msg")) {
        $hookFile = Join-Path $hooks_dir $hookType
        if (Test-Path $hookFile) {
            if (Remove-GaFromHook -HookPath $hookFile -HookType $hookType) {
                $foundAny = $true
            }
        }
    }
    if (-not $foundAny) {
        Log-Warning "Guardian Agent hook not found"
    }
}

function Get-CiFiles {
    $sourceCommit = if ($env:GA_CI_SOURCE_COMMIT) { $env:GA_CI_SOURCE_COMMIT } else { "HEAD~1" }
    $output = @(& git diff --name-only --diff-filter=ACMR "$sourceCommit..HEAD" 2>$null)
    if ($LASTEXITCODE -ne 0) {
        return @()
    }
    return $output | Where-Object { $_ -and (Test-Path $_) }
}

function Test-GitRefExists {
    param([string]$RefName)
    & git show-ref --verify --quiet "refs/heads/$RefName" 2>$null
    if ($LASTEXITCODE -eq 0) { return $true }
    & git show-ref --verify --quiet "refs/remotes/origin/$RefName" 2>$null
    return ($LASTEXITCODE -eq 0)
}

function Get-PrBaseBranch {
    param([string]$ConfiguredBase)
    if ($ConfiguredBase -and (Test-GitRefExists $ConfiguredBase)) {
        return $ConfiguredBase
    }
    foreach ($candidate in @("main", "master", "develop")) {
        if (Test-GitRefExists $candidate) {
            return $candidate
        }
    }
    return $null
}

function Get-PrRange {
    param([string]$ConfiguredBase)
    $baseBranch = Get-PrBaseBranch $ConfiguredBase
    if (-not $baseBranch) {
        return $null
    }
    $mergeBase = (& git merge-base HEAD $baseBranch 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($mergeBase)) {
        return $null
    }
    return @{
        BaseBranch = $baseBranch
        Range = "$mergeBase...HEAD"
    }
}

function Get-PrFiles {
    param([string]$Range)
    $output = @(& git diff --name-only --diff-filter=ACMR $Range 2>$null)
    if ($LASTEXITCODE -ne 0) {
        return @()
    }
    return $output | Where-Object { $_ -and (Test-Path $_) }
}

function Cmd-Run {
    Load-Config

    $no_cache = $Args -contains "--no-cache"
    $ci_mode = $Args -contains "--ci"
    $pr_mode = $Args -contains "--pr-mode"
    $diff_only = $Args -contains "--diff-only"

    if ($diff_only -and -not $pr_mode) {
        Log-Error "--diff-only requires --pr-mode"
        exit 1
    }
    if ($ci_mode -and $pr_mode) {
        Log-Error "--ci and --pr-mode cannot be used together"
        exit 1
    }

    if ([string]::IsNullOrWhiteSpace($PROVIDER)) {
        Log-Error "No provider configured"
        Write-Host "Configure a provider in .ga or set GA_PROVIDER"
        Write-Host "Run 'ga init' to create a config file"
        exit 1
    }

    Log-Info "Running code review with provider: $PROVIDER"

    if (-not (Validate-Provider $PROVIDER)) {
        exit 1
    }

    $prRangeData = $null
    if ($pr_mode) {
        $prRangeData = Get-PrRange $PR_BASE_BRANCH
        if (-not $prRangeData) {
            Log-Error "Could not determine PR range"
            Write-Host "Set PR_BASE_BRANCH in your .ga config to specify the base branch."
            Write-Host '  Example: PR_BASE_BRANCH="main"'
            exit 1
        }
        Log-Info "PR range: $($prRangeData.Range)"
    }

    $candidateFiles = if ($pr_mode) {
        Get-PrFiles $prRangeData.Range
    } elseif ($ci_mode) {
        Get-CiFiles
    } else {
        Get-StagedFiles
    }
    if ($candidateFiles.Count -eq 0) {
        if ($pr_mode) {
            Log-Warning "No matching files changed in PR"
        } elseif ($ci_mode) {
            Log-Warning "No matching files changed in last commit"
        } else {
            Log-Warning "No staged files to review"
        }
        exit 0
    }

    # Parse optional commit message file from hook
    $commitMsgFile = $null
    foreach ($arg in $Args) {
        if ($arg -notlike "--*" -and (Test-Path $arg)) {
            $commitMsgFile = $arg
            break
        }
    }

    if (-not (Test-Path $RULES_FILE)) {
        Log-Error "Rules file not found: $RULES_FILE"
        Write-Host "Please create a $RULES_FILE file with your coding standards."
        exit 1
    }

    Log-Info "Found $($candidateFiles.Count) file(s)"

    $files_to_review = @()
    $skipped_files = @()

    foreach ($file in $candidateFiles) {
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
        
        # Check cache (disabled for CI/PR mode)
        if (-not $no_cache -and -not $ci_mode -and -not $pr_mode) {
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
    
    if ($pr_mode) {
        if ($diff_only) {
            Log-Info "Mode: PR (diff-only review)"
        } else {
            Log-Info "Mode: PR (full file review)"
        }
    } elseif ($ci_mode) {
        Log-Info "Mode: CI (reviewing last commit)"
    }
    if ($pr_mode -or $ci_mode) {
        Log-Info "Cache: disabled"
    } elseif ($no_cache) {
        Log-Info "Cache: disabled (--no-cache)"
    } else {
        Log-Info "Cache: enabled"
    }
    Log-Info "Reviewing $($files_to_review.Count) file(s)..."
    
    $all_passed = $true
    
    foreach ($file in $files_to_review) {
        Write-Host ""
        Log-Info "Reviewing: $file"
        
        if ($pr_mode -and $diff_only) {
            $content = (& git diff --no-color $prRangeData.Range -- $file 2>$null) -join "`n"
            if ([string]::IsNullOrWhiteSpace($content)) {
                $content = Get-Content $file -Raw -Encoding UTF8
            }
        } elseif ($ci_mode -or $pr_mode) {
            $content = Get-Content $file -Raw -Encoding UTF8
        } else {
            $staged = (& git show ":$file" 2>$null) -join "`n"
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($staged)) {
                $content = $staged
            } else {
                $content = Get-Content $file -Raw -Encoding UTF8
            }
        }
        
        $rules_content = Get-Content $RULES_FILE -Raw -Encoding UTF8
        $commitMsgContent = ""
        $commitSection = ""
        if ($commitMsgFile) {
            $commitMsgContent = Get-Content $commitMsgFile -Raw -Encoding UTF8
            if (-not [string]::IsNullOrWhiteSpace($commitMsgContent)) {
                $commitSection = @"
Commit message:
~~~
$commitMsgContent
~~~

"@
            }
        }
        
        $prompt = @"
Review this code file for issues. Apply the following rules:

$rules_content

File: $file$(if ($pr_mode -and $diff_only) { " (DIFF)" } else { "" })
```
$content
```

$commitSection

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
            Write-Host "Usage: ga cache {clear|clear-all|status}"
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
        Write-Host "Run 'ga help' for usage information"
        exit 1
    }
}
