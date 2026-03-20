#requires -version 5.1
# Global Skills Extension — Windows
# Instala skills en todas las rutas de Copilot/Claude/Agents en Windows
param(
    [string]$TargetDir = "."
)

$ErrorActionPreference = 'Stop'

$extDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Join-Path $extDir '..\..\..\..'
$skillsSource = Join-Path $repoRoot 'ywai\skills'

Write-Host "Installing global skills for AI assistants on Windows..." -ForegroundColor Cyan

$homeDir = $env:USERPROFILE

$skillLocations = @{
    "OpenCode"    = Join-Path $homeDir ".config\opencode\skills"
    "Copilot"     = Join-Path $homeDir ".copilot\skills"
    "Claude"      = Join-Path $homeDir ".claude\skills"
    "Agents"      = Join-Path $homeDir ".agents\skills"
}

$copiedTotal = 0
$skippedTotal = 0

foreach ($platformName in $skillLocations.Keys) {
    $destDir = $skillLocations[$platformName]
    if (Test-Path $destDir) {
        Get-ChildItem -Path $destDir -Directory -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-SkillToLocation {
    param(
        [string]$SourceSkillDir,
        [string]$DestSkillsDir,
        [string]$PlatformName
    )

    $skillName = Split-Path $SourceSkillDir -Leaf
    $skillMd = Join-Path $SourceSkillDir 'SKILL.md'

    if (-not (Test-Path $skillMd)) {
        Write-Host "  Skipping $skillName (no SKILL.md found)"
        return @{ Copied = 0; Skipped = 1 }
    }

    $skillDestDir = Join-Path $DestSkillsDir $skillName
    New-Item -ItemType Directory -Force -Path $skillDestDir | Out-Null
    Copy-Item -Force $skillMd (Join-Path $skillDestDir 'SKILL.md')

    $assetsDir = Join-Path $SourceSkillDir 'assets'
    if (Test-Path $assetsDir) {
        $destAssetsDir = Join-Path $skillDestDir 'assets'
        Copy-Item -Recurse -Force $assetsDir $destAssetsDir
    }

    $referencesDir = Join-Path $SourceSkillDir 'references'
    if (Test-Path $referencesDir) {
        $destRefsDir = Join-Path $skillDestDir 'references'
        Copy-Item -Recurse -Force $referencesDir $destRefsDir
    }

    Write-Host "  [$PlatformName] Installed: $skillName" -ForegroundColor Green
    return @{ Copied = 1; Skipped = 0 }
}

$skills = Get-ChildItem -Path $skillsSource -Directory
$totalSkills = $skills.Count

Write-Host ""
Write-Host "Found $totalSkills skills to install" -ForegroundColor Yellow
Write-Host ""

foreach ($platformName in $skillLocations.Keys) {
    $destDir = $skillLocations[$platformName]
    Write-Host "Installing to $platformName : $destDir" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null

    foreach ($skill in $skills) {
        $result = Install-SkillToLocation -SourceSkillDir $skill.FullName -DestSkillsDir $destDir -PlatformName $platformName
        $copiedTotal += $result.Copied
        $skippedTotal += $result.Skipped
    }
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Green
Write-Host "Global skills installation complete!" -ForegroundColor Green
Write-Host "Installed: $copiedTotal skills" -ForegroundColor Green
Write-Host "Skipped: $skippedTotal (no SKILL.md)" -ForegroundColor Yellow
Write-Host ""
Write-Host "Locations:" -ForegroundColor White
foreach ($platformName in $skillLocations.Keys) {
    Write-Host "  $platformName : $($skillLocations[$platformName])" -ForegroundColor Gray
}
