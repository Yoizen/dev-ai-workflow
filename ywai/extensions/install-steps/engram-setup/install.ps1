#requires -version 5.1
# Engram Setup Extension — Windows
# Downloads engram CLI and configures it for supported targets.
param(
    [string]$TargetDir = "."
)

$ErrorActionPreference = 'Stop'

$Repo      = 'Gentleman-Programming/engram'
$BinName   = 'engram.exe'
$InstallDir = Join-Path $env:LOCALAPPDATA 'ywai\engram'
$StateDir   = Join-Path $TargetDir '.ywai\engram'
$StatusFile = Join-Path $StateDir 'status.txt'

New-Item -ItemType Directory -Force -Path $StateDir | Out-Null

# ── Platform ────────────────────────────────────────────────────────
$arch = if ([Environment]::Is64BitOperatingSystem) {
    if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
} else {
    Write-Error '32-bit not supported'
    exit 1
}

# ── Install engram ──────────────────────────────────────────────────
if (-not (Get-Command engram -ErrorAction SilentlyContinue)) {
    Write-Host "Engram CLI not found. Installing..."

    # Find latest release zip
    $apiUrl = "https://api.github.com/repos/$Repo/releases/latest"
    $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
    $asset = $release.assets | Where-Object {
        $_.name -match "engram_.*_windows_${arch}\.zip$"
    } | Select-Object -First 1

    if (-not $asset) {
        # Fallback: try without version pattern
        $asset = $release.assets | Where-Object {
            $_.name -match "windows.*${arch}.*\.zip$"
        } | Select-Object -First 1
    }

    if (-not $asset) {
        Write-Host "ERROR: Could not find engram release for windows/$arch"
        "engram: install_failed`nauto_configured: no`nnote: no release asset for windows/$arch" | Set-Content $StatusFile
        exit 1
    }

    $tmp = Join-Path $env:TEMP "engram-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $zip = Join-Path $tmp 'engram.zip'

    Write-Host "Downloading $($asset.name)..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $tmp -Force

    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    $extracted = Get-ChildItem -Path $tmp -Filter 'engram.exe' -Recurse | Select-Object -First 1
    if (-not $extracted) {
        Write-Host "ERROR: engram.exe not found in archive"
        "engram: install_failed`nauto_configured: no`nnote: engram.exe not in zip" | Set-Content $StatusFile
        exit 1
    }

    Copy-Item -Force $extracted.FullName (Join-Path $InstallDir $BinName)
    Remove-Item -Recurse -Force $tmp

    # Add to PATH (persist)
    $currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($currentPath -notlike "*$InstallDir*") {
        [Environment]::SetEnvironmentVariable('Path', "$InstallDir;$currentPath", 'User')
        $env:Path = "$InstallDir;$env:Path"
    }

    Write-Host "Engram installed to $InstallDir\$BinName" -ForegroundColor Green
}

# ── Version ─────────────────────────────────────────────────────────
$version = (engram version 2>$null | Select-Object -First 1)
if (-not $version) { $version = 'unknown' }

# ── Configure targets ──────────────────────────────────────────────
$configured = 0
$failed = 0

foreach ($target in @('opencode', 'codex', 'gemini-cli')) {
    try {
        engram setup $target 2>$null | Out-Null
        Write-Host "Configured engram for $target"
        $configured++
    } catch {
        Write-Host "Could not auto-configure engram for $target"
        $failed++
    }
}

# ── Copilot MCP ─────────────────────────────────────────────────────
$extDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$mcpTemplate = Join-Path $extDir 'copilot-mcp.json'
$vscodeDir = Join-Path $TargetDir '.vscode'
$mcpFile = Join-Path $vscodeDir 'mcp.json'

if (Test-Path $mcpTemplate) {
    New-Item -ItemType Directory -Force -Path $vscodeDir | Out-Null
    if (Test-Path $mcpFile) {
        try {
            $existing = Get-Content $mcpFile -Raw | ConvertFrom-Json
            $template = Get-Content $mcpTemplate -Raw | ConvertFrom-Json
            if (-not $existing.servers) { $existing | Add-Member -NotePropertyName 'servers' -NotePropertyValue @{} }
            foreach ($key in $template.servers.PSObject.Properties.Name) {
                $existing.servers | Add-Member -NotePropertyName $key -NotePropertyValue $template.servers.$key -Force
            }
            $existing | ConvertTo-Json -Depth 10 | Set-Content $mcpFile
            Write-Host "Configured engram MCP for Copilot at .vscode\mcp.json"
        } catch {
            Copy-Item -Force $mcpTemplate $mcpFile
            Write-Host "Created .vscode\mcp.json from template"
        }
    } else {
        Copy-Item -Force $mcpTemplate $mcpFile
        Write-Host "Created .vscode\mcp.json"
    }
}

# ── Status ──────────────────────────────────────────────────────────
@"
engram: installed
version: $version
auto_configured: yes
configured_targets: $configured
failed_targets: $failed
"@ | Set-Content $StatusFile

Write-Host "Engram setup complete ($configured configured, $failed failed)"
