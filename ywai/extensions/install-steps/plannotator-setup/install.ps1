#requires -version 5.1
# Plannotator Setup Extension — Windows
# Installs plannotator CLI and configures detected agent tools.
param(
    [string]$TargetDir = "."
)

$ErrorActionPreference = 'Stop'

function Write-Log($msg)  { Write-Host "[plannotator-setup] $msg" }
function Write-Warn($msg) { Write-Host "[plannotator-setup] WARN: $msg" -ForegroundColor Yellow }
function Has-Cmd($name)   { [bool](Get-Command $name -ErrorAction SilentlyContinue) }

# ---------------------------------------------------------------------------
# 1. Install plannotator CLI
# ---------------------------------------------------------------------------
if (Has-Cmd 'plannotator') {
    Write-Log "plannotator CLI already installed"
} else {
    try {
        Write-Log "Installing plannotator CLI from https://plannotator.ai/install.ps1"
        Invoke-Expression (Invoke-RestMethod 'https://plannotator.ai/install.ps1')
        Write-Log "plannotator CLI installed"
    } catch {
        Write-Warn "plannotator CLI install failed: $($_.Exception.Message)"
    }
}

# ---------------------------------------------------------------------------
# 2. Configure OpenCode (if opencode.json exists in target)
# ---------------------------------------------------------------------------
function Update-OpenCodePlugin {
    param([string]$JsonPath)
    try {
        $raw = Get-Content $JsonPath -Raw
        $cfg = $raw | ConvertFrom-Json
        if (-not $cfg.plugin) {
            $cfg | Add-Member -NotePropertyName plugin -NotePropertyValue @() -Force
        }
        $entry = '@plannotator/opencode@latest'
        $plugins = @($cfg.plugin)
        if ($plugins -contains $entry) {
            Write-Log "OpenCode: plannotator plugin already configured in $JsonPath"
        } else {
            $plugins += $entry
            $cfg.plugin = $plugins
            ($cfg | ConvertTo-Json -Depth 20) | Set-Content -Path $JsonPath -Encoding UTF8
            Write-Log "OpenCode: added $entry to plugin[] in $JsonPath"
        }
    } catch {
        Write-Warn "OpenCode: could not update $JsonPath: $($_.Exception.Message)"
    }
}

$OpenCodeJson = Join-Path $TargetDir 'opencode.json'
$GlobalOpenCodeJson = Join-Path $HOME '.config' 'opencode' 'opencode.json'

if (Test-Path $OpenCodeJson) {
    Update-OpenCodePlugin -JsonPath $OpenCodeJson
}

if (Test-Path $GlobalOpenCodeJson) {
    Update-OpenCodePlugin -JsonPath $GlobalOpenCodeJson
}

if (-not (Test-Path $OpenCodeJson) -and -not (Test-Path $GlobalOpenCodeJson)) {
    Write-Log "OpenCode: no opencode.json found (skipping)"
}

# ---------------------------------------------------------------------------
# 3. Gemini CLI — plannotator installer auto-detects ~/.gemini
# ---------------------------------------------------------------------------
$geminiDir = Join-Path $HOME '.gemini'
if (Test-Path $geminiDir) {
    Write-Log "Gemini CLI detected (~/.gemini) - plannotator installer auto-configures hook + slash commands"
}

# ---------------------------------------------------------------------------
# 4. Claude Code / Copilot CLI — manual plugin step
# ---------------------------------------------------------------------------
if (Has-Cmd 'claude') {
    Write-Log "Claude Code detected. Run inside Claude Code:"
    Write-Log "    /plugin marketplace add backnotprop/plannotator"
}
if (Has-Cmd 'copilot') {
    Write-Log "Copilot CLI detected. Run inside Copilot CLI:"
    Write-Log "    /plugin marketplace add backnotprop/plannotator"
    Write-Log "    /plugin install plannotator-copilot@plannotator"
}

# ---------------------------------------------------------------------------
# 5. Pi extension
# ---------------------------------------------------------------------------
if (Has-Cmd 'pi') {
    Write-Log "Pi detected - installing @plannotator/pi-extension"
    try {
        pi install npm:@plannotator/pi-extension | Out-Null
        Write-Log "Pi extension installed"
    } catch {
        Write-Warn "Failed to install @plannotator/pi-extension via pi"
    }
}

Write-Log "Done"
