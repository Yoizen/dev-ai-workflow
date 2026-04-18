#requires -version 5.1
# SDD Engram Plugin Setup — Windows
# Registers opencode-sdd-engram-manage plugin in ~/.config/opencode/tui.json
param(
    [string]$TargetDir = "."
)

$ErrorActionPreference = 'Stop'

function Write-Log($msg)  { Write-Host "[sdd-engram-plugin] $msg" }
function Write-Warn($msg) { Write-Host "[sdd-engram-plugin] WARN: $msg" -ForegroundColor Yellow }

$TuiJson = Join-Path $HOME '.config' 'opencode' 'tui.json'
$PluginEntry = 'opencode-sdd-engram-manage'

# ---------------------------------------------------------------------------
# Ensure tui.json exists
# ---------------------------------------------------------------------------
if (-not (Test-Path $TuiJson)) {
  Write-Log "Creating $TuiJson with plugin entry"
  $TuiDir = Split-Path $TuiJson -Parent
  if (-not (Test-Path $TuiDir)) {
    New-Item -ItemType Directory -Path $TuiDir -Force | Out-Null
  }
  @{
    '$schema' = 'https://opencode.ai/tui.json'
    plugin = @($PluginEntry)
  } | ConvertTo-Json -Depth 20 | Set-Content -Path $TuiJson -Encoding UTF8
  Write-Log "Created $TuiJson with $PluginEntry"
  exit 0
}

# ---------------------------------------------------------------------------
# Add plugin to tui.json
# ---------------------------------------------------------------------------
try {
  $raw = Get-Content $TuiJson -Raw
  $cfg = $raw | ConvertFrom-Json

  if (-not $cfg.plugin) {
    $cfg | Add-Member -NotePropertyName plugin -NotePropertyValue @() -Force
  }

  $plugins = @($cfg.plugin)
  if ($plugins -contains $PluginEntry) {
    Write-Log "Plugin already present in $TuiJson"
  } else {
    $plugins += $PluginEntry
    $cfg.plugin = $plugins
    ($cfg | ConvertTo-Json -Depth 20) | Set-Content -Path $TuiJson -Encoding UTF8
    Write-Log "Added $PluginEntry to plugin[] in $TuiJson"
  }
} catch {
  Write-Warn "Could not edit $TuiJson: $($_.Exception.Message)"
  Write-Warn "Manually add '$PluginEntry' to the plugin[] array in $TuiJson"
}

Write-Log "Done"
