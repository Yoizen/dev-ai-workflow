#requires -version 5.1
<#
.SYNOPSIS
    YWAI Installer for Windows
.EXAMPLE
    irm https://github.com/Yoizen/dev-ai-workflow/releases/latest/download/install.ps1 | iex
#>
$ErrorActionPreference = 'Stop'

$Repo    = 'Yoizen/dev-ai-workflow'
$BinName = 'ywai.exe'
$InstallDir = Join-Path $env:LOCALAPPDATA 'ywai'

# ── Platform ────────────────────────────────────────────────────────
$arch = if ([Environment]::Is64BitOperatingSystem) {
    if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
} else { Write-Error '32-bit not supported'; exit 1 }
$platform = "windows-$arch"

# ── Download ────────────────────────────────────────────────────────
$url = "https://github.com/$Repo/releases/latest/download/setup-wizard-$platform.exe"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$tmp = Join-Path $env:TEMP "ywai-$([guid]::NewGuid().ToString('N').Substring(0,8)).exe"

Write-Host "Downloading YWAI for $platform..."
Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
Move-Item -Force $tmp (Join-Path $InstallDir $BinName)

# ── PATH (persist) ─────────────────────────────────────────────────
$currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($currentPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable('Path', "$InstallDir;$currentPath", 'User')
    $env:Path = "$InstallDir;$env:Path"
}

Write-Host ""
Write-Host "YWAI installed to $InstallDir\$BinName" -ForegroundColor Green
Write-Host ""

# ── Launch wizard ───────────────────────────────────────────────────
$exe = Join-Path $InstallDir $BinName
if ($args.Count -gt 0) {
    & $exe @args
} else {
    & $exe
}
