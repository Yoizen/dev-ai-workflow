#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter()]
    [string]$Init
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot

# --- Project init mode --------------------------------------------------------
if ($Init) {
    $typeDir = Join-Path $repoRoot "project-types" $Init
    if (-not (Test-Path $typeDir)) {
        $available = Get-ChildItem -Directory (Join-Path $repoRoot "project-types") | ForEach-Object { $_.Name }
        Write-Error "Unknown project type '$Init'. Available: $($available -join ', ')"
    }
    $copied = 0
    foreach ($file in @("AGENTS.md", "REVIEW.md")) {
        $src = Join-Path $typeDir $file
        $dst = Join-Path (Get-Location) $file
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination $dst -Force
            Write-Host "Copied $file -> $dst"
            $copied++
        }
    }
    if ($copied -eq 0) {
        Write-Warning "No AGENTS.md or REVIEW.md found in $typeDir"
    } else {
        Write-Host "Project initialized as '$Init'."
    }
    exit 0
}

# 1. Check gentle-ai
$ga = Get-Command gentle-ai -ErrorAction SilentlyContinue
if (-not $ga) {
    if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
        Write-Error "Go is not installed. Install Go first: https://go.dev/dl/"
    }
    Write-Host "Installing gentle-ai..."
    go install github.com/Gentleman-Programming/gentle-ai@latest
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "User")
} else {
    Write-Host "gentle-ai already installed: $($ga.Source)"
}

# 2. Install Gentleman Stack (ecosystem-only preset covers SDD, Engram, Context7, Skills, GGA)
Write-Host ""
Write-Host "Run the following to install the base Gentleman Stack:"
Write-Host "   gentle-ai install --agent <your-agent> --preset ecosystem-only"
Write-Host ""
Write-Host "Supported agents: claude-code, opencode, gemini-cli, cursor, vscode-copilot, codex, windsurf, antigravity"
Write-Host ""

# 3. Detect installed agents and link extra skills
function Get-AgentSkillsDir {
    param([string]$Agent)
    switch ($Agent) {
        "windsurf" {
            $dir = Join-Path $env:USERPROFILE ".windsurf" "skills"
            if (Test-Path $dir) { return $dir }
            if (Get-Command windsurf -ErrorAction SilentlyContinue) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                return $dir
            }
        }
        "opencode" {
            $dir = Join-Path $env:APPDATA "opencode" "skills"
            if (Test-Path $dir) { return $dir }
            if ((Get-Command opencode -ErrorAction SilentlyContinue) -or (Test-Path (Join-Path $env:APPDATA "opencode"))) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                return $dir
            }
        }
        "claude-code" {
            $dir = Join-Path $env:USERPROFILE ".claude" "skills"
            if (Test-Path $dir) { return $dir }
            if (Get-Command claude -ErrorAction SilentlyContinue) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                return $dir
            }
        }
        "cursor" {
            $dir = Join-Path $env:USERPROFILE ".cursor" "skills"
            if (Test-Path $dir) { return $dir }
            $alt = Join-Path $env:APPDATA "Cursor" "User" "skills"
            if (Test-Path $alt) { return $alt }
            if (Get-Command cursor -ErrorAction SilentlyContinue) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                return $dir
            }
        }
        "gemini-cli" {
            $dir = Join-Path $env:USERPROFILE ".gemini" "skills"
            if (Test-Path $dir) { return $dir }
            if (Get-Command gemini -ErrorAction SilentlyContinue) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                return $dir
            }
        }
        "vscode-copilot" {
            $dir = Join-Path $env:APPDATA "Code" "User" "skills"
            if (Test-Path $dir) { return $dir }
            if (Test-Path (Join-Path $env:LOCALAPPDATA "Programs" "Microsoft VS Code" "Code.exe")) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                return $dir
            }
        }
        "codex" {
            $dir = Join-Path $env:USERPROFILE ".codex" "skills"
            if (Test-Path $dir) { return $dir }
            if (Get-Command codex -ErrorAction SilentlyContinue) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                return $dir
            }
        }
        default { return $null }
    }
    return $null
}

function Install-Skills {
    param([string]$SkillsDir)
    $extraSkills = Join-Path $repoRoot "skills"
    $items = Get-ChildItem -Directory $extraSkills
    foreach ($item in $items) {
        $target = Join-Path $SkillsDir $item.Name
        if (Test-Path $target) {
            if ((Get-Item $target -ErrorAction SilentlyContinue).Target -eq $item.FullName) { continue }
            Remove-Item -Recurse -Force $target
        }
        New-Item -ItemType SymbolicLink -Path $target -Target $item.FullName -Force | Out-Null
        Write-Host "  Linked skill: $($item.Name)"
    }
}

$agents = @("opencode", "windsurf", "claude-code", "cursor", "gemini-cli", "vscode-copilot", "codex")
$installed = @()
foreach ($agent in $agents) {
    $dir = Get-AgentSkillsDir -Agent $agent
    if ($dir) {
        Write-Host "[$agent] -> $dir"
        Install-Skills -SkillsDir $dir
        $installed += $agent
    }
}

if ($installed.Count -eq 0) {
    Write-Warning "No supported agents detected. Install one first, then re-run this script."
    Write-Host ""
    Write-Host "Example:"
    Write-Host "   npm install -g @anthropic-ai/claude-code   # claude-code"
    Write-Host "   npm install -g opencode                     # opencode"
    Write-Host "   # or install Windsurf/Cursor from their websites"
} else {
    Write-Host ""
    Write-Host "Done. Extra skills linked for: $($installed -join ', ')"
}
