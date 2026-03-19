#requires -version 5.1
# OpenCode Command Hooks Extension — Windows
param(
    [string]$TargetDir = "."
)

$ErrorActionPreference = 'Stop'

$absTarget = Resolve-Path $TargetDir
$opencodeDir = Join-Path $absTarget '.opencode'
$pluginsDir = Join-Path $opencodeDir 'plugins'
$legacyPluginsDir = Join-Path $opencodeDir 'plugin'
$pluginFile = Join-Path $pluginsDir 'command-hooks.js'
$legacyPluginFile = Join-Path $legacyPluginsDir 'command-hooks.js'

$hookSource = Split-Path -Parent $MyInvocation.MyCommand.Path

# Check for bun
if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
    Write-Host "Bun is required to build the OpenCode command hooks plugin"
    Write-Host "Install: powershell -c 'irm bun.sh/install.ps1 | iex'"
    Write-Host "Skipping hook installation for now (non-fatal)"
    exit 0
}

New-Item -ItemType Directory -Force -Path $pluginsDir | Out-Null
New-Item -ItemType Directory -Force -Path $legacyPluginsDir | Out-Null

# Clean up legacy plugin directories
foreach ($dir in @(
    (Join-Path $pluginsDir 'opencode-command-hooks'),
    (Join-Path $legacyPluginsDir 'opencode-command-hooks')
)) {
    if (Test-Path $dir) {
        Remove-Item -Recurse -Force $dir
        Write-Host "Removed legacy plugin directory"
    }
}

# Build plugin
$buildDir = Join-Path $env:TEMP "ywaibuild-$([guid]::NewGuid().ToString('N').Substring(0,8))"
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

Copy-Item (Join-Path $hookSource 'package.json') $buildDir
if (Test-Path (Join-Path $hookSource 'tsconfig.json')) {
    Copy-Item (Join-Path $hookSource 'tsconfig.json') $buildDir
}
if (Test-Path (Join-Path $hookSource 'src')) {
    Copy-Item -Recurse (Join-Path $hookSource 'src') (Join-Path $buildDir 'src')
}

Write-Host "Installing plugin dependencies..."
Push-Location $buildDir
try {
    bun install --frozen-lockfile 2>$null
} catch {
    bun install 2>$null
}
Pop-Location

Write-Host "Bundling OpenCode command hooks..."
Push-Location $buildDir
try {
    $result = bun build src/index.ts --target=bun --outfile="$pluginFile" --external '@opencode-ai/plugin' --external '@opencode-ai/sdk' 2>&1
    if ($LASTEXITCODE -ne 0) {
        Remove-Item -Recurse -Force $buildDir
        Write-Host "Plugin bundle failed" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}
Remove-Item -Recurse -Force $buildDir
Copy-Item -Force $pluginFile $legacyPluginFile

# Clean up legacy opencode.json references
$opencodeJson = Join-Path $opencodeDir 'opencode.json'
if (Test-Path $opencodeJson) {
    try {
        $cfg = Get-Content $opencodeJson -Raw | ConvertFrom-Json
        if ($cfg.plugin) {
            $cfg.plugin = @($cfg.plugin | Where-Object { $_ -notmatch 'opencode-command-hooks' })
            if ($cfg.plugin.Count -eq 0) { $cfg.PSObject.Properties.Remove('plugin') }
            $cfg | ConvertTo-Json -Depth 10 | Set-Content $opencodeJson
        }
    } catch {}
}

Remove-Item (Join-Path $opencodeDir 'bun.lock') -ErrorAction SilentlyContinue
if (Test-Path (Join-Path $opencodeDir 'package.json')) {
    if ((Get-Content (Join-Path $opencodeDir 'package.json') -Raw) -match 'opencode-command-hooks') {
        Remove-Item (Join-Path $opencodeDir 'package.json') -ErrorAction SilentlyContinue
        Remove-Item -Recurse -Force (Join-Path $opencodeDir 'node_modules') -ErrorAction SilentlyContinue
    }
}

# Create hooks config
$hooksConfig = Join-Path $opencodeDir 'command-hooks.jsonc'
if (-not (Test-Path $hooksConfig)) {
    @'
{
  // OpenCode Command Hooks Configuration
  "truncationLimit": 30000,
  "tool": [
    {
      "id": "post-edit-lint",
      "when": { "phase": "after", "tool": ["edit", "write"] },
      "run": ["npm run lint --silent 2>&1 || true"],
      "inject": "Lint Results (exit {exitCode}):\n```\n{stdout}\n{stderr}\n```",
      "toast": { "title": "Lint Check", "message": "exit {exitCode}", "variant": "info" }
    },
    {
      "id": "post-edit-typecheck",
      "when": { "phase": "after", "tool": ["edit", "write"] },
      "run": ["npx tsc --noEmit 2>&1 || true"],
      "inject": "Type Check Results (exit {exitCode}):\n```\n{stdout}\n{stderr}\n```",
      "toast": { "title": "Type Check", "message": "exit {exitCode}", "variant": "info" }
    }
  ],
  "session": []
}
'@ | Set-Content $hooksConfig
}

# Create engineer agent
$agentDir = Join-Path $opencodeDir 'agent'
$agentTarget = Join-Path $agentDir 'engineer.md'
New-Item -ItemType Directory -Force -Path $agentDir | Out-Null
if (-not (Test-Path $agentTarget)) {
    $agentSource = Join-Path $hookSource 'agents\engineer.md'
    if (Test-Path $agentSource) {
        Copy-Item -Force $agentSource $agentTarget
    } else {
        @'
---
description: Senior Software Engineer - Writes clean, tested, and maintainable code
mode: subagent
hooks:
  after:
    - run: ["npm run lint"]
      inject: "Lint Results (exit {exitCode}):\n```\n{stdout}\n{stderr}\n```"
    - run: ["npm run typecheck"]
      inject: "Type Check Results (exit {exitCode}):\n```\n{stdout}\n{stderr}\n```"
---

You are a senior software engineer. Follow best practices, ensure type safety,
write tests, and fix any lint or type errors before considering a task complete.
'@ | Set-Content $agentTarget
    }
}

Write-Host "OpenCode command hooks installed (.opencode\plugins + .opencode\plugin compatibility)"
