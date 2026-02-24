# Installation Module for GA Components - PowerShell

$ErrorActionPreference = "SilentlyContinue"

$GA_REPO = "https://github.com/Yoizen/dev-ai-workflow.git"
$GA_DIR = "$env:USERPROFILE\.local\share\yoizen\dev-ai-workflow"

function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-ErrorMsg { param($msg) Write-Host "[X] $msg" -ForegroundColor Red }
function Write-WarningMsg { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-InfoMsg { param($msg) Write-Host "[i] $msg" -ForegroundColor Cyan }

function Install-Ga {
    param(
        [string]$Action = "install"
    )
    
    switch ($Action) {
        "install" {
            Write-InfoMsg "Installing GA..."
            
            if (Test-Path $GA_DIR) {
                Write-WarningMsg "GA directory already exists, pulling latest changes..."
                Push-Location $GA_DIR
                git fetch origin --quiet 2>&1 | Out-Null
                git pull origin main --quiet 2>&1 | Out-Null
                Pop-Location
            } else {
                Write-InfoMsg "Cloning GA repository..."
                $parentDir = Split-Path -Parent $GA_DIR
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                git clone $GA_REPO $GA_DIR --quiet 2>&1 | Out-Null
                
                if (-not (Test-Path $GA_DIR)) {
                    Write-ErrorMsg "Failed to clone GA repository"
                    return $false
                }
            }
            
            Write-InfoMsg "Installing GA system-wide..."
            Push-Location $GA_DIR
            & .\install.ps1 2>&1 | Out-Null
            Pop-Location
            
            if ($LASTEXITCODE -eq 0 -or (Test-Path $GA_DIR)) {
                Write-Success "GA installed successfully"
                return $true
            } else {
                Write-WarningMsg "GA installation completed with warnings"
                return $true
            }
        }
        
        "update" {
            if (-not (Test-Path $GA_DIR)) {
                Write-ErrorMsg "GA not installed. Use 'install' action first."
                return $false
            }
            
            Write-InfoMsg "Updating GA..."
            Push-Location $GA_DIR
            git fetch origin --quiet 2>&1 | Out-Null
            git pull origin main --quiet 2>&1 | Out-Null
            Pop-Location
            
            Write-InfoMsg "Reinstalling GA..."
            Push-Location $GA_DIR
            & .\install.ps1 2>&1 | Out-Null
            Pop-Location
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "GA updated successfully"
                return $true
            } else {
                Write-ErrorMsg "Failed to update GA"
                return $false
            }
        }
        
        "skip" {
            Write-InfoMsg "Skipping GA installation"
            return $true
        }
        
        default {
            Write-ErrorMsg "Unknown action: $Action"
            return $false
        }
    }
}

function Install-SDD {
    param(
        [string]$Action = "install",
        [string]$TargetDir = "."
    )
    
    # Resolve source directory (local repo or GA install)
    $scriptParent = Split-Path -Parent $PSScriptRoot  # lib -> auto
    $repoRoot = Split-Path -Parent $scriptParent       # auto -> repo root
    $sourceDir = Join-Path $repoRoot "skills"
    
    # Fallback to GA install dir if local source not available
    if (-not (Test-Path $sourceDir)) {
        $sourceDir = Join-Path $GA_DIR "skills"
    }
    
    switch ($Action) {
        "install" {
            Write-InfoMsg "Installing SDD Orchestrator..."
            
            # Copy sdd-* skills to the project's skills/ directory
            $skillsTarget = Join-Path $TargetDir "skills"
            New-Item -ItemType Directory -Path $skillsTarget -Force | Out-Null
            
            $copied = 0
            $sddSkills = Get-ChildItem -Path $sourceDir -Directory -Filter "sdd-*" -ErrorAction SilentlyContinue
            
            foreach ($skillDir in $sddSkills) {
                $destPath = Join-Path $skillsTarget $skillDir.Name
                # Skip if source and target are the same
                $srcNorm = [System.IO.Path]::GetFullPath($skillDir.FullName)
                $dstNorm = [System.IO.Path]::GetFullPath($destPath)
                if ($srcNorm -eq $dstNorm) {
                    $copied++
                    continue
                }
                Copy-Item $skillDir.FullName $destPath -Recurse -Force
                $copied++
            }
            
            if ($copied -gt 0) {
                Write-Success "Copied $copied SDD skills to skills/"
            } else {
                Write-WarningMsg "No SDD skills found in $sourceDir"
            }

            # Copy setup scripts for AI skills bootstrap parity with bash installer
            $setupSource = Join-Path $sourceDir "setup.sh"
            $setupTarget = Join-Path $skillsTarget "setup.sh"
            if ((Test-Path $setupSource) -and -not ([System.IO.Path]::GetFullPath($setupSource) -eq [System.IO.Path]::GetFullPath($setupTarget))) {
                Copy-Item -Path $setupSource -Destination $setupTarget -Force
                Write-Success "Copied skills/setup.sh"
            }
            $setupPsSource = Join-Path $sourceDir "setup.ps1"
            $setupPsTarget = Join-Path $skillsTarget "setup.ps1"
            if ((Test-Path $setupPsSource) -and -not ([System.IO.Path]::GetFullPath($setupPsSource) -eq [System.IO.Path]::GetFullPath($setupPsTarget))) {
                Copy-Item -Path $setupPsSource -Destination $setupPsTarget -Force
                Write-Success "Copied skills/setup.ps1"
            }
            
            Write-Success "SDD Orchestrator installed successfully"
            return $true
        }
        
        "update" {
            Write-InfoMsg "Updating SDD Orchestrator..."
            # Re-install to get latest skills
            return (Install-SDD -Action "install" -TargetDir $TargetDir)
        }
        
        "skip" {
            Write-InfoMsg "Skipping SDD Orchestrator installation"
            return $true
        }
        
        default {
            Write-ErrorMsg "Unknown action: $Action"
            return $false
        }
    }
}

function Install-VscodeExtensions {
    param(
        [string]$Action = "install"
    )
    
    $codeCmd = Get-Command code -ErrorAction SilentlyContinue
    if (-not $codeCmd) {
        Write-WarningMsg "VS Code CLI not available, skipping extensions"
        return $true
    }
    
    $extensions = @("github.copilot", "github.copilot-chat")
    
    switch ($Action) {
        "install" {
            Write-InfoMsg "Installing VS Code extensions..."
            
            foreach ($ext in $extensions) {
                Write-InfoMsg "Installing $ext..."
                & code --install-extension $ext --force 2>&1 | Out-Null
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "$ext installed"
                } else {
                    Write-WarningMsg "Could not install $ext"
                }
            }
            
            return $true
        }
        
        "skip" {
            Write-InfoMsg "Skipping VS Code extensions"
            return $true
        }
        
        default {
            Write-ErrorMsg "Unknown action: $Action"
            return $false
        }
    }
}

function Set-ProjectConfiguration {
    param(
        [string]$Provider = "opencode",
        [string]$TargetDir = ".",
        [bool]$SkipGa = $false,
        [bool]$InstallBiome = $false,
        [string]$ProjectType = ""
    )
    
    Write-InfoMsg "Configuring project at $TargetDir..."
    
    $autoDir = Split-Path -Parent $PSScriptRoot
    $projectRoot = Split-Path -Parent $autoDir
    
    # Apply type-specific AGENTS.md, REVIEW.md and skills (falls back to generic)
    Apply-ProjectType -ProjectType $ProjectType -TargetDir $TargetDir

    $promptsSource = Join-Path $projectRoot ".github\prompts"
    $promptsTarget = Join-Path $TargetDir ".github\prompts"
    
    $promptsSourceNorm = [System.IO.Path]::GetFullPath($promptsSource)
    $promptsTargetNorm = [System.IO.Path]::GetFullPath($promptsTarget)
    
    if ($promptsSourceNorm -eq $promptsTargetNorm) {
        Write-InfoMsg ".github/prompts directory already in place"
    } elseif (Test-Path $promptsSource) {
        if (Test-Path $promptsTarget) {
            Write-WarningMsg ".github/prompts directory already exists in target, skipping copy"
        } else {
            $parentPrompts = Split-Path -Parent $promptsTarget
            New-Item -ItemType Directory -Path $parentPrompts -Force | Out-Null
            Copy-Item $promptsSource $promptsTarget -Recurse -Force
            Write-Success "Copied .github/prompts directory"
        }
    } else {
        Write-WarningMsg ".github/prompts directory not found in source"
    }
    

    
    if (-not $SkipGa) {
        $gaCmd = Get-Command ga -ErrorAction SilentlyContinue
        if ($gaCmd) {
            Write-InfoMsg "Initializing GA in repository..."
            Push-Location $TargetDir
            & ga init 2>&1 | Out-Null
            Pop-Location
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "GA initialized"
                
                $gaConfig = Join-Path $TargetDir ".ga"
                $gaTemplate = Join-Path $projectRoot ".ga.opencode-template"
                
                if ((Test-Path $gaTemplate) -and (Test-Path $gaConfig)) {
                    Copy-Item $gaTemplate $gaConfig -Force
                    Write-Success "Applied OpenCode template to .ga"
                }
                
                if ($Provider -and $Provider -ne "opencode") {
                    if (Test-Path $gaConfig) {
                        $content = Get-Content $gaConfig -Raw
                        $content = $content -replace 'PROVIDER="opencode:github-copilot/claude-haiku-4.5"', "PROVIDER=`"$Provider`""
                        Set-Content -Path $gaConfig -Value $content
                        Write-Success "Provider set to: $Provider"
                    }
                }
                
                Write-InfoMsg "Installing GA hooks..."
                Push-Location $TargetDir
                & ga install 2>&1 | Out-Null
                Pop-Location
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "GA hooks installed"
                } else {
                    Write-WarningMsg "GA hook installation had issues"
                }
            } else {
                Write-WarningMsg "Failed to initialize GA"
            }
        } else {
            Write-WarningMsg "GA command not available, skipping initialization"
        }
    }
    
    $lefthookCmd = Get-Command lefthook -ErrorAction SilentlyContinue
    if ($lefthookCmd) {
        $lefthookConfig = Join-Path $TargetDir "lefthook.yml"
        if (-not (Test-Path $lefthookConfig)) {
            $effectiveType = if ($ProjectType) { $ProjectType } else { "generic" }
            $typeLefthookTemplate = Join-Path $autoDir "types\$effectiveType\lefthook.yml"
            $lefthookTemplate = if (Test-Path $typeLefthookTemplate) {
                $typeLefthookTemplate
            } else {
                Join-Path $autoDir "lefthook.yml.template"
            }
            if (Test-Path $lefthookTemplate) {
                Copy-Item $lefthookTemplate $lefthookConfig -Force
                Write-Success "Created lefthook.yml ($effectiveType)"
                
                Write-InfoMsg "Installing Lefthook hooks..."
                Push-Location $TargetDir
                & lefthook install 2>&1 | Out-Null
                Pop-Location
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "Lefthook hooks installed"
                } else {
                    Write-WarningMsg "Lefthook installation had issues"
                }
            } else {
                Write-WarningMsg "Lefthook template not found"
            }
        } else {
            Write-InfoMsg "lefthook.yml already exists"
        }
    } else {
        Write-InfoMsg "Lefthook not installed, skipping hook configuration"
    }
    
    # Update .gitignore - only add missing patterns
    $gitignoreTarget = Join-Path $TargetDir ".gitignore"
    
    # Essential patterns that should be in every .gitignore
    $essentialPatterns = @(
        "# Dependencies",
        "node_modules/",
        "",
        "# Environment",
        ".env",
        ".env.local",
        ".env.*.local",
        "",
        "# AI Assistants",
        "CLAUDE.md",
        "CURSOR.md",
        "GEMINI.md",
        ".cursorrules",
        "",
        "# OpenCode",
        ".opencode/plugins/**/node_modules/",
        ".opencode/plugins/**/dist/",
        ".opencode/**/cache/",
        "",
        "# System",
        ".DS_Store",
        "Thumbs.db",
        "",
        "# Logs",
        "*.log",
        "logs/",
        "",
        "# IDE",
        ".idea/",
        "*.iml",
        ".vscode/"
    )
    
    # Create .gitignore if doesn't exist
    if (-not (Test-Path $gitignoreTarget)) {
        Write-InfoMsg "Creating .gitignore..."
        New-Item -ItemType File -Path $gitignoreTarget -Force | Out-Null
    }
    
    # Add only missing patterns
    $addedCount = 0
    $existingContent = Get-Content $gitignoreTarget -Raw
    
    foreach ($pattern in $essentialPatterns) {
        # Skip empty lines (they are section separators)
        if ([string]::IsNullOrWhiteSpace($pattern)) {
            # Only add blank line if file not empty and last line not blank
            if ($existingContent -and -not $existingContent.EndsWith("`n`n")) {
                Add-Content -Path $gitignoreTarget -Value ""
            }
            continue
        }
        
        # Check if pattern already exists
        $escapedPattern = [Regex]::Escape($pattern)
        if (-not (Select-String -Path $gitignoreTarget -Pattern $escapedPattern -SimpleMatch -Quiet)) {
            Add-Content -Path $gitignoreTarget -Value $pattern
            $addedCount++
        }
    }
    
    if ($addedCount -gt 0) {
        Write-Success "Added $addedCount patterns to .gitignore"
    } else {
        Write-InfoMsg ".gitignore already up to date"
    }

    $autoBiomeForType = ($ProjectType -eq "nest")
    if ($autoBiomeForType -and -not $InstallBiome) {
        Write-InfoMsg "Auto-enabling Biome baseline for project type: nest"
    }

    if ($InstallBiome -or $autoBiomeForType) {
        Set-BiomeBaseline -TargetDir $TargetDir | Out-Null
    }

    # Configure AI skills for Copilot + OpenCode
    $skillsSetupPs = Join-Path $TargetDir "skills\setup.ps1"
    $skillsSetup = Join-Path $TargetDir "skills\setup.sh"
    if (-not (Test-Path $skillsSetupPs) -and -not (Test-Path $skillsSetup)) {
        $fallbackSetup = Join-Path $projectRoot "skills\setup.sh"
        $fallbackSetupPs = Join-Path $projectRoot "skills\setup.ps1"
        if ((Test-Path $fallbackSetupPs) -and (Test-Path (Join-Path $TargetDir "skills"))) {
            Copy-Item -Path $fallbackSetupPs -Destination $skillsSetupPs -Force
            Write-Success "Copied skills/setup.ps1"
        }
        if ((Test-Path $fallbackSetup) -and (Test-Path (Join-Path $TargetDir "skills"))) {
            Copy-Item -Path $fallbackSetup -Destination $skillsSetup -Force
            Write-Success "Copied skills/setup.sh"
        }
    }

    if (Test-Path $skillsSetupPs) {
        Write-InfoMsg "Configuring AI skills (Copilot + OpenCode) via setup.ps1..."
        Push-Location $TargetDir
        & powershell -NoProfile -ExecutionPolicy Bypass -File $skillsSetupPs -Copilot -Opencode 2>&1 | Out-Null
        Pop-Location
        if ($LASTEXITCODE -eq 0) {
            Write-Success "AI skills configured for Copilot and OpenCode"
        } else {
            Write-WarningMsg "AI skills setup had issues"
        }
    } elseif (Test-Path $skillsSetup) {
        $bashCmd = Get-Command bash -ErrorAction SilentlyContinue
        if ($bashCmd) {
            Write-InfoMsg "Configuring AI skills (Copilot + OpenCode) via setup.sh..."
            Push-Location $TargetDir
            & bash $skillsSetup --copilot --opencode 2>&1 | Out-Null
            Pop-Location
            if ($LASTEXITCODE -eq 0) {
                Write-Success "AI skills configured for Copilot and OpenCode"
            } else {
                Write-WarningMsg "AI skills setup had issues"
            }
        } else {
            Write-InfoMsg "bash not found, skipping skills/setup.sh auto-configuration"
        }
    } else {
        Write-WarningMsg "skills/setup.ps1/setup.sh not found, skipping AI skills setup"
    }

    $vscodeDir = Join-Path $TargetDir ".vscode"
    New-Item -ItemType Directory -Path $vscodeDir -Force | Out-Null
    
    $settingsFile = Join-Path $vscodeDir "settings.json"
    if (-not (Test-Path $settingsFile)) {
        $settings = @{
            "github.copilot.chat.useAgentsMdFile" = $true
        } | ConvertTo-Json -Depth 10
        
        Set-Content -Path $settingsFile -Value $settings
        Write-Success "Created VS Code settings"
    }
    
    Write-Success "Project configured successfully"
    return $true
}

function Set-BiomeBaseline {
        param(
                [string]$TargetDir = "."
        )

        Write-InfoMsg "Configuring optional Biome baseline..."

        $biomeConfig = Join-Path $TargetDir "biome.json"
        $packageJson = Join-Path $TargetDir "package.json"

        if (Test-Path $biomeConfig) {
                Write-InfoMsg "biome.json already exists, skipping baseline config file"
        } else {
                $biomeContent = @'
{
    "$schema": "https://biomejs.dev/schemas/2.3.2/schema.json",
    "files": {
        "ignoreUnknown": true,
        "includes": [
            "**",
            "!!**/node_modules",
            "!!**/dist",
            "!!**/build",
            "!!**/coverage",
            "!!**/.next",
            "!!**/.nuxt",
            "!!**/.svelte-kit",
            "!!**/.turbo",
            "!!**/.vercel",
            "!!**/.cache",
            "!!**/__generated__",
            "!!**/*.generated.*",
            "!!**/*.gen.*",
            "!!**/generated",
            "!!**/codegen"
        ]
    },
    "formatter": {
        "enabled": true,
        "formatWithErrors": true,
        "indentStyle": "space",
        "indentWidth": 2,
        "lineEnding": "lf",
        "lineWidth": 80,
        "bracketSpacing": true
    },
    "assist": {
        "actions": {
            "source": {
                "organizeImports": "on",
                "useSortedAttributes": "on",
                "noDuplicateClasses": "on",
                "useSortedInterfaceMembers": "on",
                "useSortedProperties": "on"
            }
        }
    },
    "linter": {
        "enabled": true,
        "rules": {
            "correctness": {
                "noUnusedImports": {
                    "fix": "safe",
                    "level": "error"
                },
                "noUnusedVariables": "error",
                "noUnusedFunctionParameters": "error",
                "noUndeclaredVariables": "error",
                "useParseIntRadix": "warn",
                "useValidTypeof": "error",
                "noUnreachable": "error"
            },
            "style": {
                "useBlockStatements": {
                    "fix": "safe",
                    "level": "error"
                },
                "useConst": "error",
                "useImportType": "warn",
                "noNonNullAssertion": "error",
                "useTemplate": "warn"
            },
            "security": {
                "noGlobalEval": "error"
            },
            "suspicious": {
                "noExplicitAny": "error",
                "noImplicitAnyLet": "error",
                "noDoubleEquals": "warn",
                "noGlobalIsNan": "error",
                "noPrototypeBuiltins": "error"
            },
            "complexity": {
                "useOptionalChain": "error",
                "useLiteralKeys": "warn",
                "noForEach": "warn"
            },
            "nursery": {
                "useSortedClasses": {
                    "fix": "safe",
                    "level": "error",
                    "options": {
                        "attributes": ["className"],
                        "functions": ["clsx", "cva", "tw", "twMerge", "cn", "twJoin", "tv"]
                    }
                }
            }
        }
    },
    "javascript": {
        "formatter": {
            "arrowParentheses": "always",
            "semicolons": "always",
            "trailingCommas": "es5"
        }
    },
    "organizeImports": {
        "enabled": true
    },
    "vcs": {
        "enabled": true,
        "clientKind": "git",
        "useIgnoreFile": true,
        "defaultBranch": "main"
    }
}
'@
                Set-Content -Path $biomeConfig -Value $biomeContent
                Write-Success "Created biome.json baseline"
        }

        if (-not (Test-Path $packageJson)) {
                Write-WarningMsg "package.json not found, skipping Biome package/scripts setup"
                return $true
        }

        $pkgRaw = Get-Content $packageJson -Raw
        if ($pkgRaw -match '"@biomejs/biome"') {
                Write-InfoMsg "@biomejs/biome already present in package.json"
        } else {
                $npmCmd = Get-Command npm -ErrorAction SilentlyContinue
                if (-not $npmCmd) {
                        Write-WarningMsg "npm not found, skipping @biomejs/biome automatic install"
                } else {
                        Write-InfoMsg "Installing @biomejs/biome..."
                        Push-Location $TargetDir
                        & npm install --save-dev "@biomejs/biome" 2>&1 | Out-Null
                        Pop-Location
                        if ($LASTEXITCODE -eq 0) {
                                Write-Success "Installed @biomejs/biome"
                        } else {
                                Write-WarningMsg "Failed to install @biomejs/biome automatically"
                        }
                }
        }

        if (Get-Command node -ErrorAction SilentlyContinue) {
                Push-Location $TargetDir
                try {
                        & node -e "
const fs = require('fs');
const path = require('path');
const packagePath = path.resolve('package.json');
if (!fs.existsSync(packagePath)) process.exit(0);
const pkg = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
pkg.scripts = pkg.scripts || {};
const desired = {
    lint: 'biome check .',
    'lint:fix': 'biome check --write .',
    format: 'biome format --write .',
    'format:check': 'biome format .'
};
let changed = false;
for (const [name, command] of Object.entries(desired)) {
    if (!pkg.scripts[name]) {
        pkg.scripts[name] = command;
        changed = true;
    }
}
if (changed) {
    fs.writeFileSync(packagePath, JSON.stringify(pkg, null, 2) + '\\n');
}
" 2>&1 | Out-Null

                        if ($LASTEXITCODE -eq 0) {
                                Write-Success "Applied Biome scripts (without overriding existing scripts)"
                        } else {
                                Write-WarningMsg "Failed to update package.json scripts for Biome"
                        }
                } finally {
                        Pop-Location
                }
        }

        return $true
}

function Install-Biome {
    param(
        [string]$Action = "install",
        [string]$TargetDir = "."
    )

    switch ($Action) {
        "install" {
            return (Set-BiomeBaseline -TargetDir $TargetDir)
        }

        "skip" {
            Write-InfoMsg "Skipping Biome baseline installation"
            return $true
        }

        default {
            Write-ErrorMsg "Unknown action: $Action"
            return $false
        }
    }
}

function Install-Hooks {
    param(
        [string]$Action = "install",
        [string]$TargetDir = "."
    )
    
    switch ($Action) {
        "install" {
            Write-InfoMsg "Installing OpenCode command hooks..."
            
            $opencodeDir = Join-Path $TargetDir ".opencode"
            $pluginsDir = Join-Path $opencodeDir "plugins"
            $pluginFile = Join-Path $pluginsDir "command-hooks.js"

            # Determine source directory (prefer local source if running from repo/temp)
            $scriptParent = Split-Path -Parent $PSScriptRoot # lib
            $repoRoot = Split-Path -Parent $scriptParent     # auto/.. = root
            $localSource = Join-Path $repoRoot "hooks\opencodehooks"
            $installedSource = Join-Path $GA_DIR "hooks\opencodehooks"
            $hooksSource = ""

            if (Test-Path $localSource) {
                $hooksSource = $localSource
            } elseif (Test-Path $installedSource) {
                $hooksSource = $installedSource
            } else {
                Write-ErrorMsg "Hooks plugin source not found."
                Write-InfoMsg "Checked: $localSource"
                Write-InfoMsg "Checked: $installedSource"
                return $false
            }

            Write-InfoMsg "Using hooks source: $hooksSource"

            # Check for bun (required by OpenCode for bundling)
            if (-not (Get-Command bun -ErrorAction SilentlyContinue)) {
                Write-ErrorMsg "Bun is required to build hooks plugin (OpenCode uses Bun internally)"
                Write-InfoMsg "Install Bun: powershell -c 'irm bun.sh/install.ps1 | iex'"
                return $false
            }

            # Create plugins directory
            New-Item -ItemType Directory -Path $pluginsDir -Force | Out-Null

            # Remove old directory-based plugin if it exists (legacy format)
            $oldHooksDir = Join-Path $pluginsDir "opencode-command-hooks"
            if (Test-Path $oldHooksDir) {
                Write-InfoMsg "Removing legacy plugin directory..."
                Remove-Item -Path $oldHooksDir -Recurse -Force
            }

            # Build and bundle the plugin into a single file
            # OpenCode local plugins are single .js/.ts files in .opencode/plugins/
            $buildDir = Join-Path $env:TEMP "opencode-hooks-build-$(Get-Random)"
            New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

            # Copy source files to temp build dir
            Copy-Item -Path (Join-Path $hooksSource "package.json") -Destination $buildDir
            Copy-Item -Path (Join-Path $hooksSource "tsconfig.json") -Destination $buildDir -ErrorAction SilentlyContinue
            $srcSource = Join-Path $hooksSource "src"
            if (Test-Path $srcSource) {
                Copy-Item -Path $srcSource -Destination $buildDir -Recurse -Force
            }

            Write-InfoMsg "Installing dependencies..."
            Push-Location $buildDir
            try {
                & bun install 2>&1 | Out-Null
                Write-Success "Dependencies installed"

                Write-InfoMsg "Bundling plugin..."
                & bun build src/index.ts --target=bun --outfile="$pluginFile" --external @opencode-ai/plugin --external @opencode-ai/sdk 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "Plugin bundle failed" }
                Write-Success "Plugin bundled to $pluginFile"
            } catch {
                Write-ErrorMsg "Plugin build failed: $_"
                Pop-Location
                Remove-Item -Path $buildDir -Recurse -Force -ErrorAction SilentlyContinue
                return $false
            }
            Pop-Location

            # Clean up temp build dir
            Remove-Item -Path $buildDir -Recurse -Force -ErrorAction SilentlyContinue

            # Remove stale opencode.json plugin references from previous installs
            $opencodeJson = Join-Path $opencodeDir "opencode.json"
            if ((Test-Path $opencodeJson) -and ((Get-Content $opencodeJson -Raw) -match "opencode-command-hooks")) {
                Write-InfoMsg "Removing legacy file: plugin reference from opencode.json..."
                & node -e "
                    const fs = require('fs');
                    const p = '$($opencodeJson -replace '\\','/')';
                    const cfg = JSON.parse(fs.readFileSync(p, 'utf8'));
                    if (Array.isArray(cfg.plugin)) {
                        cfg.plugin = cfg.plugin.filter(p => !p.includes('opencode-command-hooks'));
                        if (cfg.plugin.length === 0) delete cfg.plugin;
                    }
                    fs.writeFileSync(p, JSON.stringify(cfg, null, 2) + '\n');
                " 2>&1 | Out-Null
                Write-Success "Cleaned up opencode.json"
            }

            # Also clean stale OpenCode-managed state
            $bunLock = Join-Path $opencodeDir "bun.lock"
            if (Test-Path $bunLock) { Remove-Item -Force $bunLock }
            $ocPkg = Join-Path $opencodeDir "package.json"
            if ((Test-Path $ocPkg) -and ((Get-Content $ocPkg -Raw) -match "opencode-command-hooks")) {
                Remove-Item -Force $ocPkg
                $ocNm = Join-Path $opencodeDir "node_modules"
                if (Test-Path $ocNm) { Remove-Item -Recurse -Force $ocNm }
                Write-InfoMsg "Cleared stale OpenCode package cache"
            }
            
            # Create default command-hooks.jsonc if it doesn't exist
            $hooksConfig = Join-Path $opencodeDir "command-hooks.jsonc"
            if (-not (Test-Path $hooksConfig)) {
                $configContent = @'
{
  // OpenCode Command Hooks Configuration

  "truncationLimit": 30000,

  "tool": [
    {
      "id": "post-edit-lint",
      "when": {
        "phase": "after",
        "tool": ["edit", "write"]
      },
      "run": ["npm run lint --silent 2>&1 || true"],
      "inject": "Lint Results (exit {exitCode}):\n```\n{stdout}\n{stderr}\n```",
      "toast": {
        "title": "Lint Check",
        "message": "Lint finished with exit code {exitCode}",
        "variant": "info"
      }
    },
    {
      "id": "post-edit-typecheck",
      "when": {
        "phase": "after",
        "tool": ["edit", "write"]
      },
      "run": ["npx tsc --noEmit 2>&1 || true"],
      "inject": "Type Check Results (exit {exitCode}):\n```\n{stdout}\n{stderr}\n```",
      "toast": {
        "title": "Type Check",
        "message": "TypeScript check finished with exit code {exitCode}",
        "variant": "info"
      }
    }
  ],

  "session": []
}
'@
                Set-Content -Path $hooksConfig -Value $configContent
                Write-Success "Created default command-hooks.jsonc"
            } else {
                Write-InfoMsg "command-hooks.jsonc already exists"
            }
            
            # Create Engineer agent with hooks
            $agentDir = Join-Path $opencodeDir "agent"
            New-Item -ItemType Directory -Path $agentDir -Force | Out-Null
            
            $agentSource = Join-Path $hooksSource "agents\engineer.md"
            $agentTarget = Join-Path $agentDir "engineer.md"
            
            if (Test-Path $agentSource) {
                if (-not (Test-Path $agentTarget)) {
                    Copy-Item -Path $agentSource -Destination $agentTarget
                    Write-Success "Created Engineer agent with validation hooks"
                } else {
                    Write-InfoMsg "Engineer agent already exists"
                }
            } else {
                # Create default Engineer agent if source not found
                if (-not (Test-Path $agentTarget)) {
                    $agentContent = @'
---
description: Senior Software Engineer - Writes clean, tested, and maintainable code
mode: subagent
hooks:
  after:
    - run: ["npm run lint"]
      inject: "Lint Results (exit {exitCode}):
```
{stdout}
{stderr}
```"
      toast:
        title: "Lint Check"
        message: "Lint finished with exit code {exitCode}"
        variant: "info"
    - run: ["npm run typecheck"]
      inject: "Type Check Results (exit {exitCode}):
```
{stdout}
{stderr}
```"
      toast:
        title: "Type Check"
        message: "TypeScript check finished with exit code {exitCode}"
        variant: "info"
---

# Engineer Agent

You are a senior software engineer with expertise in writing clean, maintainable, and well-tested code.

## Responsibilities

- Write code following best practices and design patterns
- Ensure type safety and proper error handling
- Write comprehensive tests for new functionality
- Follow the existing codebase conventions
- Refactor when necessary to improve code quality

## Guidelines

- Always consider edge cases and error scenarios
- Write self-documenting code with clear variable names
- Keep functions focused and cohesive
- Avoid premature optimization
- Ensure backward compatibility when possible

## Before Completing

- Run the validation hooks that execute automatically after your task
- If lint or typecheck fail, fix the issues before considering the task complete
- Ensure all tests pass
'@
                    Set-Content -Path $agentTarget -Value $agentContent
                    Write-Success "Created Engineer agent with validation hooks"
                } else {
                    Write-InfoMsg "Engineer agent already exists"
                }
            }
            
            Write-Success "OpenCode command hooks installed successfully"
            return $true
        }
        
        "skip" {
            Write-InfoMsg "Skipping hooks installation"
            return $true
        }
        
        default {
            Write-ErrorMsg "Unknown action: $Action"
            return $false
        }
    }
}

function Update-AllComponents {
    param(
        [string]$TargetDir = "."
    )
    
    $updated = 0
    $failed = 0
    
    Write-InfoMsg "Checking for updates..."
    
    $detectorScript = Join-Path $PSScriptRoot "detector.ps1"
    . $detectorScript
    
    $gaInfo = Detect-Ga
    $gaParts = $gaInfo -split '\|'
    $gaStatus = $gaParts[0]
    $gaCurrent = $gaParts[1]
    
    if ($gaStatus -eq "OUTDATED") {
        if (Install-Ga -Action "update") {
            $updated++
        } else {
            $failed++
        }
    } elseif ($gaStatus -eq "UP_TO_DATE") {
        Write-InfoMsg "GA is up to date ($gaCurrent)"
    }
    
    $sddInfo = Detect-SDD -TargetDir $TargetDir
    $sddParts = $sddInfo -split '\|'
    $sddStatus = $sddParts[0]
    $sddCurrent = $sddParts[1]
    
    if ($sddStatus -eq "NOT_INSTALLED" -or $sddStatus -eq "PARTIAL") {
        if (Install-SDD -Action "update" -TargetDir $TargetDir) {
            $updated++
        } else {
            $failed++
        }
    } elseif ($sddStatus -eq "INSTALLED") {
        Write-InfoMsg "Refreshing SDD Orchestrator skills ($sddCurrent detected)..."
        if (Install-SDD -Action "update" -TargetDir $TargetDir) {
            $updated++
        } else {
            $failed++
        }
    }
    
    if ($updated -gt 0) {
        Write-Success "Updated $updated component(s)"
    }
    
    if ($failed -gt 0) {
        Write-WarningMsg "Failed to update $failed component(s)"
        return $false
    }
    
    return $true
}

# ---------------------------------------------------------------------------
# Project Type System
# ---------------------------------------------------------------------------

function Apply-ProjectType {
    param(
        [string]$ProjectType = "",
        [string]$TargetDir = ".",
        [switch]$Force
    )

    $autoDir = Split-Path -Parent $PSScriptRoot
    $typesDir = Join-Path $autoDir "types"
    $projectRoot = Split-Path -Parent $autoDir

    # Resolve type (fall back to generic)
    if (-not $ProjectType) { $ProjectType = "generic" }

    $typeDir = Join-Path $typesDir $ProjectType
    if (-not (Test-Path $typeDir)) {
        Write-WarningMsg "Unknown project type '$ProjectType'. Falling back to 'generic'."
        $ProjectType = "generic"
        $typeDir = Join-Path $typesDir "generic"
        if (-not (Test-Path $typeDir)) {
            Write-WarningMsg "generic type directory not found, skipping type application"
            return
        }
    }

    Write-InfoMsg "Applying project type: $ProjectType"

    # Copy AGENTS.md
    $agentsSource = Join-Path $typeDir "AGENTS.md"
    $agentsTarget = Join-Path $TargetDir "AGENTS.md"
    if (Test-Path $agentsSource) {
        if (-not (Test-Path $agentsTarget) -or $Force) {
            Copy-Item $agentsSource $agentsTarget -Force
            Write-Success "Copied AGENTS.md ($ProjectType)"
        } else {
            Write-WarningMsg "AGENTS.md already exists, skipping (use -Force to overwrite)"
        }
    }

    # Copy REVIEW.md
    $reviewSource = Join-Path $typeDir "REVIEW.md"
    $reviewTarget = Join-Path $TargetDir "REVIEW.md"
    if (Test-Path $reviewSource) {
        if (-not (Test-Path $reviewTarget) -or $Force) {
            Copy-Item $reviewSource $reviewTarget -Force
            Write-Success "Copied REVIEW.md ($ProjectType)"
        } else {
            Write-WarningMsg "REVIEW.md already exists, skipping (use -Force to overwrite)"
        }
    }

    # Copy skills listed in types.json
    $typesJson = Join-Path $typesDir "types.json"
    $mainSkillsDir = Join-Path $projectRoot "skills"

    if ((Test-Path $typesJson) -and (Test-Path $mainSkillsDir)) {
        try {
            $typesData = Get-Content $typesJson -Raw | ConvertFrom-Json
            $typeSkills = $typesData.types.$ProjectType.skills
            if ($typeSkills) {
                $skillsTarget = Join-Path $TargetDir "skills"
                New-Item -ItemType Directory -Path $skillsTarget -Force | Out-Null
                $copiedCount = 0
                foreach ($skill in $typeSkills) {
                    $skillSource = Join-Path $mainSkillsDir $skill
                    $skillDest   = Join-Path $skillsTarget $skill
                    if ((Test-Path $skillSource) -and -not (Test-Path $skillDest)) {
                        Copy-Item $skillSource $skillDest -Recurse -Force
                        $copiedCount++
                    }
                }
                if ($copiedCount -gt 0) {
                    Write-Success "Copied $copiedCount type skills ($($typeSkills -join ', '))"
                }
            }
        } catch {
            Write-WarningMsg "Could not parse types.json: $_"
        }
    } elseif (Test-Path $mainSkillsDir) {
        # No types.json – copy entire skills dir as fallback
        $skillsTarget = Join-Path $TargetDir "skills"
        $skillsSourceNorm = [System.IO.Path]::GetFullPath($mainSkillsDir)
        $skillsTargetNorm = [System.IO.Path]::GetFullPath($skillsTarget)
        if ($skillsSourceNorm -ne $skillsTargetNorm) {
            if (-not (Test-Path $skillsTarget)) {
                Copy-Item $mainSkillsDir $skillsTarget -Recurse -Force
                Write-Success "Copied skills/ directory"
            } else {
                Write-WarningMsg "skills/ directory already exists in target, skipping copy"
            }
        }
    } else {
        Write-WarningMsg "skills/ directory not found"
    }

    Write-Success "Project type '$ProjectType' applied"
}

function List-ProjectTypes {
    $autoDir = Split-Path -Parent $PSScriptRoot
    $typesDir = Join-Path $autoDir "types"
    $typesJson = Join-Path $typesDir "types.json"

    Write-Host "Available project types:" -ForegroundColor Cyan
    if (Test-Path $typesJson) {
        try {
            $data = Get-Content $typesJson -Raw | ConvertFrom-Json
            foreach ($name in $data.types.PSObject.Properties.Name) {
                $desc = $data.types.$name.description
                if ($desc) {
                    Write-Host ("  {0,-14} - {1}" -f $name, $desc)
                } else {
                    Write-Host "  $name"
                }
            }
            Write-Host ""
            Write-Host "  default: $($data.default)" -ForegroundColor Gray
        } catch {
            Get-ChildItem $typesDir -Directory | ForEach-Object { Write-Host "  - $($_.Name)" }
        }
    } else {
        Get-ChildItem $typesDir -Directory | ForEach-Object { Write-Host "  - $($_.Name)" }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $command = $args[0]
    
    switch ($command) {
        "install-ga" {
            Install-Ga -Action "install"
        }
        "install-sdd" {
            $targetDir = if ($args.Count -gt 1) { $args[1] } else { "." }
            Install-SDD -Action "install" -TargetDir $targetDir
        }
        "install-vscode" {
            Install-VscodeExtensions -Action "install"
        }
        "install-biome" {
            $targetDir = if ($args.Count -gt 1) { $args[1] } else { "." }
            Install-Biome -Action "install" -TargetDir $targetDir
        }
        "configure" {
            $provider = if ($args.Count -gt 1) { $args[1] } else { "opencode" }
            $targetDir = if ($args.Count -gt 2) { $args[2] } else { "." }
            Set-ProjectConfiguration -Provider $provider -TargetDir $targetDir
        }
        "update-all" {
            $targetDir = if ($args.Count -gt 1) { $args[1] } else { "." }
            Update-AllComponents -TargetDir $targetDir
        }
        default {
            Write-Host "Usage: .\installer.ps1 {install-ga|install-sdd|install-vscode|install-biome|configure|update-all}"
            exit 1
        }
    }
}
