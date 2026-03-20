#requires -version 5.1
<#
.SYNOPSIS
    YWAI Installer for Windows
.EXAMPLE
    irm https://github.com/Yoizen/dev-ai-workflow/releases/latest/download/install.ps1 | iex
#>
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Repo    = 'Yoizen/dev-ai-workflow'
$BinName = 'ywai.exe'
$InstallDir = Join-Path $env:LOCALAPPDATA 'ywai'
$DataDir = Join-Path $env:LOCALAPPDATA 'yoizen\dev-ai-workflow'

# ── Platform ────────────────────────────────────────────────────────
$arch = if ([Environment]::Is64BitOperatingSystem) {
    if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
} else { Write-Error '32-bit not supported'; exit 1 }
$platform = "windows-$arch"

# ── Download binary ─────────────────────────────────────────────────
$url = "https://github.com/$Repo/releases/latest/download/setup-wizard-$platform.exe"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$tmp = Join-Path $env:TEMP "ywai-$([guid]::NewGuid().ToString('N').Substring(0,8)).exe"

Write-Host "Downloading YWAI for $platform..."
Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing | Out-Null
Move-Item -Force $tmp (Join-Path $InstallDir $BinName) | Out-Null

# ── Download extensions + skills ────────────────────────────────────
Write-Host "Downloading extensions and skills..."
New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
$zipUrl = "https://github.com/$Repo/archive/refs/heads/main.zip"
$tmpZip = Join-Path $env:TEMP "ywai-ext-$([guid]::NewGuid().ToString('N').Substring(0,8)).zip"
Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip -UseBasicParsing | Out-Null

$tmpExtract = Join-Path $env:TEMP "ywai-ext-$([guid]::NewGuid().ToString('N').Substring(0,8))"
Expand-Archive -Path $tmpZip -DestinationPath $tmpExtract -Force | Out-Null

$src = Join-Path $tmpExtract 'dev-ai-workflow-main\ywai'
foreach ($dir in @('extensions', 'skills', 'types', 'config')) {
    $srcDir = Join-Path $src $dir
    $dstDir = Join-Path $DataDir 'ywai' $dir
    if (Test-Path $srcDir) {
        New-Item -ItemType Directory -Force -Path (Split-Path $dstDir) | Out-Null
        Copy-Item -Recurse -Force $srcDir $dstDir | Out-Null
    }
}

Remove-Item -Recurse -Force $tmpZip, $tmpExtract -ErrorAction SilentlyContinue | Out-Null

# ── PATH (persist) ─────────────────────────────────────────────────
$currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($currentPath -notlike "*$InstallDir*") {
    [Environment]::SetEnvironmentVariable('Path', "$InstallDir;$currentPath", 'User')
    $env:Path = "$InstallDir;$env:Path"
}

Write-Host ""
Write-Host "YWAI installed to $InstallDir\$BinName" -ForegroundColor Green
Write-Host "Extensions at $DataDir\ywai\" -ForegroundColor Green
Write-Host ""

# ── Launch wizard ───────────────────────────────────────────────────
$exe = Join-Path $InstallDir $BinName
if ($args.Count -gt 0) {
    & $exe @args
} else {
    & $exe
}
