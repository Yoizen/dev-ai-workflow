# Installation Module for GGA Components - PowerShell

$ErrorActionPreference = "SilentlyContinue"

$GGA_REPO = "https://github.com/Yoizen/gga-copilot.git"
$GGA_DIR = "$env:USERPROFILE\.local\share\yoizen\gga-copilot"

function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-ErrorMsg { param($msg) Write-Host "[X] $msg" -ForegroundColor Red }
function Write-WarningMsg { param($msg) Write-Host "[!] $msg" -ForegroundColor Yellow }
function Write-InfoMsg { param($msg) Write-Host "[i] $msg" -ForegroundColor Cyan }

function Install-Gga {
    param(
        [string]$Action = "install"
    )
    
    switch ($Action) {
        "install" {
            Write-InfoMsg "Installing GGA..."
            
            if (Test-Path $GGA_DIR) {
                Write-WarningMsg "GGA directory already exists, pulling latest changes..."
                Push-Location $GGA_DIR
                git fetch origin --quiet 2>&1 | Out-Null
                git pull origin main --quiet 2>&1 | Out-Null
                Pop-Location
            } else {
                Write-InfoMsg "Cloning GGA repository..."
                $parentDir = Split-Path -Parent $GGA_DIR
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
                git clone $GGA_REPO $GGA_DIR --quiet 2>&1 | Out-Null
                
                if (-not (Test-Path $GGA_DIR)) {
                    Write-ErrorMsg "Failed to clone GGA repository"
                    return $false
                }
            }
            
            Write-InfoMsg "Installing GGA system-wide..."
            Push-Location $GGA_DIR
            & .\install.ps1 2>&1 | Out-Null
            Pop-Location
            
            if ($LASTEXITCODE -eq 0 -or (Test-Path $GGA_DIR)) {
                Write-Success "GGA installed successfully"
                return $true
            } else {
                Write-WarningMsg "GGA installation completed with warnings"
                return $true
            }
        }
        
        "update" {
            if (-not (Test-Path $GGA_DIR)) {
                Write-ErrorMsg "GGA not installed. Use 'install' action first."
                return $false
            }
            
            Write-InfoMsg "Updating GGA..."
            Push-Location $GGA_DIR
            git fetch origin --quiet 2>&1 | Out-Null
            git pull origin main --quiet 2>&1 | Out-Null
            Pop-Location
            
            Write-InfoMsg "Reinstalling GGA..."
            Push-Location $GGA_DIR
            & .\install.ps1 2>&1 | Out-Null
            Pop-Location
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "GGA updated successfully"
                return $true
            } else {
                Write-ErrorMsg "Failed to update GGA"
                return $false
            }
        }
        
        "skip" {
            Write-InfoMsg "Skipping GGA installation"
            return $true
        }
        
        default {
            Write-ErrorMsg "Unknown action: $Action"
            return $false
        }
    }
}

function Install-Openspec {
    param(
        [string]$Action = "install",
        [string]$TargetDir = "."
    )
    
    switch ($Action) {
        "install" {
            Write-InfoMsg "Installing OpenSpec..."

            if (Get-Command npm -ErrorAction SilentlyContinue) {
                Write-InfoMsg "Installing OpenSpec globally..."
                npm install -g "@fission-ai/openspec@latest" 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "OpenSpec global install completed"
                } else {
                    Write-WarningMsg "Global OpenSpec install failed (continuing with local install)"
                }
            } else {
                Write-WarningMsg "npm not found; skipping global OpenSpec install"
            }
            
            if (-not (Test-Path "$TargetDir\package.json")) {
                Write-InfoMsg "Initializing package.json..."
                Push-Location $TargetDir
                npm init -y 2>&1 | Out-Null
                Pop-Location
            }
            
            Write-InfoMsg "Installing @fission-ai/openspec..."
            Push-Location $TargetDir
            npm install "@fission-ai/openspec" --save-dev 2>&1 | Out-Null
            Pop-Location
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "OpenSpec installed successfully"
                
                $binDir = Join-Path $TargetDir "bin"
                New-Item -ItemType Directory -Path $binDir -Force | Out-Null
                
                $wrapperPath = Join-Path $binDir "openspec.ps1"
                
                if (-not (Test-Path $wrapperPath)) {
                    $wrapperContent = @'
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Push-Location $ProjectRoot
try {
    & npm exec openspec -- @args
} finally {
    Pop-Location
}
'@
                    Set-Content -Path $wrapperPath -Value $wrapperContent
                    Write-Success "Created openspec wrapper"
                }
                
                Write-InfoMsg "Initializing OpenSpec structure..."
                Push-Location $TargetDir
                npm exec openspec init -- --tools opencode,github-copilot 2>&1 | Out-Null
                Pop-Location
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "OpenSpec initialized"
                } else {
                    Write-WarningMsg "OpenSpec init had issues (may need manual configuration)"
                }
                
                return $true
            } else {
                Write-ErrorMsg "Failed to install OpenSpec"
                return $false
            }
        }
        
        "update" {
            Write-InfoMsg "Updating OpenSpec..."
            Push-Location $TargetDir
            npm update "@fission-ai/openspec" 2>&1 | Out-Null
            Pop-Location
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "OpenSpec updated successfully"
                return $true
            } else {
                Write-ErrorMsg "Failed to update OpenSpec"
                return $false
            }
        }
        
        "skip" {
            Write-InfoMsg "Skipping OpenSpec installation"
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
        [bool]$SkipGga = $false,
        [bool]$InstallBiome = $false
    )
    
    Write-InfoMsg "Configuring project at $TargetDir..."
    
    $autoDir = Split-Path -Parent $PSScriptRoot
    $projectRoot = Split-Path -Parent $autoDir
    
    $files = @("AGENTS.MD", "REVIEW.md")
    
    foreach ($file in $files) {
        $source = Join-Path $autoDir $file
        $target = Join-Path $TargetDir $file
        
        $sourceNorm = [System.IO.Path]::GetFullPath($source)
        $targetNorm = [System.IO.Path]::GetFullPath($target)
        
        if ($sourceNorm -eq $targetNorm) {
            Write-InfoMsg "$file already in place"
            continue
        }
        
        if (Test-Path $source) {
            Copy-Item $source $target -Force
            Write-Success "Copied $file"
        } else {
            Write-WarningMsg "Source file $file not found"
        }
    }
    
    $skillsSource = Join-Path $projectRoot "skills"
    $skillsTarget = Join-Path $TargetDir "skills"
    
    $skillsSourceNorm = [System.IO.Path]::GetFullPath($skillsSource)
    $skillsTargetNorm = [System.IO.Path]::GetFullPath($skillsTarget)
    
    if ($skillsSourceNorm -eq $skillsTargetNorm) {
        Write-InfoMsg "skills/ directory already in place"
    } elseif (Test-Path $skillsSource) {
        if (Test-Path $skillsTarget) {
            Write-WarningMsg "skills/ directory already exists in target, skipping copy"
        } else {
            Copy-Item $skillsSource $skillsTarget -Recurse -Force
            Write-Success "Copied skills/ directory"
        }
    } else {
        Write-WarningMsg "skills/ directory not found in source"
    }
    
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
    
    $openspecDir = Join-Path $TargetDir "openspec"
    $agentsMdSource = Join-Path $autoDir "AGENTS.MD"
    if ((Test-Path $openspecDir) -and (Test-Path $agentsMdSource)) {
        $projectMd = Join-Path $openspecDir "project.md"
        if (Test-Path $projectMd) {
            Copy-Item $agentsMdSource $projectMd -Force
            Write-Success "Updated openspec/project.md with AGENTS.MD"
        }
    }
    
    if (-not $SkipGga) {
        $ggaCmd = Get-Command gga -ErrorAction SilentlyContinue
        if ($ggaCmd) {
            Write-InfoMsg "Initializing GGA in repository..."
            Push-Location $TargetDir
            & gga init 2>&1 | Out-Null
            Pop-Location
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "GGA initialized"
                
                $ggaConfig = Join-Path $TargetDir ".gga"
                $ggaTemplate = Join-Path $projectRoot ".gga.opencode-template"
                
                if ((Test-Path $ggaTemplate) -and (Test-Path $ggaConfig)) {
                    Copy-Item $ggaTemplate $ggaConfig -Force
                    Write-Success "Applied OpenCode template to .gga"
                }
                
                if ($Provider -and $Provider -ne "opencode") {
                    if (Test-Path $ggaConfig) {
                        $content = Get-Content $ggaConfig -Raw
                        $content = $content -replace 'PROVIDER="opencode:github-copilot/claude-haiku-4.5"', "PROVIDER=`"$Provider`""
                        Set-Content -Path $ggaConfig -Value $content
                        Write-Success "Provider set to: $Provider"
                    }
                }
                
                Write-InfoMsg "Installing GGA hooks..."
                Push-Location $TargetDir
                & gga install 2>&1 | Out-Null
                Pop-Location
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "GGA hooks installed"
                } else {
                    Write-WarningMsg "GGA hook installation had issues"
                }
            } else {
                Write-WarningMsg "Failed to initialize GGA"
            }
        } else {
            Write-WarningMsg "GGA command not available, skipping initialization"
        }
    }
    
    $lefthookCmd = Get-Command lefthook -ErrorAction SilentlyContinue
    if ($lefthookCmd) {
        $lefthookConfig = Join-Path $TargetDir "lefthook.yml"
        if (-not (Test-Path $lefthookConfig)) {
            $lefthookTemplate = Join-Path $autoDir "lefthook.yml.template"
            if (Test-Path $lefthookTemplate) {
                Copy-Item $lefthookTemplate $lefthookConfig -Force
                Write-Success "Created lefthook.yml"
                
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

    if ($InstallBiome) {
        Set-BiomeBaseline -TargetDir $TargetDir | Out-Null
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
                Write-InfoMsg "Installing @biomejs/biome..."
                Push-Location $TargetDir
                npm install --save-dev "@biomejs/biome" 2>&1 | Out-Null
                Pop-Location
                if ($LASTEXITCODE -eq 0) {
                        Write-Success "Installed @biomejs/biome"
                } else {
                        Write-WarningMsg "Failed to install @biomejs/biome automatically"
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
            $installedSource = Join-Path $GGA_DIR "hooks\opencodehooks"
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
    
    $ggaInfo = Detect-Gga
    $ggaParts = $ggaInfo -split '\|'
    $ggaStatus = $ggaParts[0]
    $ggaCurrent = $ggaParts[1]
    
    if ($ggaStatus -eq "OUTDATED") {
        if (Install-Gga -Action "update") {
            $updated++
        } else {
            $failed++
        }
    } elseif ($ggaStatus -eq "UP_TO_DATE") {
        Write-InfoMsg "GGA is up to date ($ggaCurrent)"
    }
    
    $openspecInfo = Detect-Openspec
    $openspecParts = $openspecInfo -split '\|'
    $openspecStatus = $openspecParts[0]
    $openspecCurrent = $openspecParts[1]
    
    if ($openspecStatus -eq "OUTDATED") {
        if (Install-Openspec -Action "update" -TargetDir $TargetDir) {
            $updated++
        } else {
            $failed++
        }
    } elseif ($openspecStatus -eq "UP_TO_DATE") {
        Write-InfoMsg "OpenSpec is up to date ($openspecCurrent)"
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

if ($MyInvocation.InvocationName -ne '.') {
    $command = $args[0]
    
    switch ($command) {
        "install-gga" {
            Install-Gga -Action "install"
        }
        "install-openspec" {
            $targetDir = if ($args.Count -gt 1) { $args[1] } else { "." }
            Install-Openspec -Action "install" -TargetDir $targetDir
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
            Write-Host "Usage: .\installer.ps1 {install-gga|install-openspec|install-vscode|install-biome|configure|update-all}"
            exit 1
        }
    }
}
