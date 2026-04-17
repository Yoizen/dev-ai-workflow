$ErrorActionPreference = 'Stop'

$repoRoot = 'e:\workflow\dev-ai-workflow'
$bin = Join-Path $repoRoot 'ywai\setup\wizard\ywai-smoke.exe'

$tmp = Join-Path $env:TEMP ("ywai-smoke-" + [guid]::NewGuid())
$homeDir = Join-Path $tmp 'home'
$xdg = Join-Path $tmp 'xdg'
$appdata = Join-Path $tmp 'appdata'
New-Item -ItemType Directory -Force -Path $homeDir, $xdg, $appdata | Out-Null

# Put a user-owned agent to verify preservation.
$opencodeAgent = Join-Path $xdg 'opencode\agent'
New-Item -ItemType Directory -Force -Path $opencodeAgent | Out-Null
Set-Content -Path (Join-Path $opencodeAgent 'my-custom.md') -Value 'user-owned' -NoNewline

$env:HOME = $homeDir
$env:USERPROFILE = $homeDir
$env:XDG_CONFIG_HOME = $xdg
$env:APPDATA = $appdata

Write-Host "--- Running $bin --update-global-agents --type=nest ---"
& $bin --update-global-agents --type=nest

Write-Host ""
Write-Host "--- Generated files in opencode/agent ---"
Get-ChildItem $opencodeAgent | Select-Object -ExpandProperty Name

$customStillThere = Test-Path (Join-Path $opencodeAgent 'my-custom.md')
Write-Host ""
Write-Host "user-owned file preserved: $customStillThere"

$nest = Get-Content (Join-Path $opencodeAgent 'nest-engineer.md') -Raw
Write-Host ""
Write-Host "--- nest-engineer.md head ---"
Write-Host ($nest.Substring(0, [Math]::Min(1500, $nest.Length)))

Write-Host ""
Write-Host "--- Destinations populated ---"
Get-ChildItem $tmp -Recurse -Filter '*.md' | Sort-Object FullName | Select-Object -ExpandProperty FullName

# Cleanup
Remove-Item -Recurse -Force $tmp
