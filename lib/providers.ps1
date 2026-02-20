# ============================================================================
# Guardian Agent - Windows PowerShell Providers
# ============================================================================

# ============================================================================
# Provider Validation
# ============================================================================

function Validate-Provider {
    param([string]$Provider)
    
    $base_provider = $Provider -split ":" | Select-Object -First 1
    
    switch ($base_provider) {
        "claude" {
            if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
                Write-Host "❌ Claude CLI not found" -ForegroundColor Red
                Write-Host ""
                Write-Host "Install Claude Code CLI:"
                Write-Host "  https://claude.ai/code"
                Write-Host ""
                return $false
            }
        }
        "gemini" {
            if (-not (Get-Command gemini -ErrorAction SilentlyContinue)) {
                Write-Host "❌ Gemini CLI not found" -ForegroundColor Red
                Write-Host ""
                Write-Host "Install Gemini CLI:"
                Write-Host "  npm install -g @anthropic-ai/gemini-cli"
                Write-Host ""
                return $false
            }
        }
        "codex" {
            if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
                Write-Host "❌ Codex CLI not found" -ForegroundColor Red
                Write-Host ""
                Write-Host "Install OpenAI Codex CLI:"
                Write-Host "  npm install -g @openai/codex"
                Write-Host ""
                return $false
            }
        }
        "ollama" {
            if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
                Write-Host "❌ Ollama not found" -ForegroundColor Red
                Write-Host ""
                Write-Host "Install Ollama:"
                Write-Host "  https://ollama.ai/download"
                Write-Host ""
                return $false
            }
            
            $model = $Provider -split ":" | Select-Object -Last 1
            if ($model -eq $Provider -or [string]::IsNullOrEmpty($model)) {
                Write-Host "❌ Ollama requires a model" -ForegroundColor Red
                Write-Host ""
                Write-Host "Specify model in provider config:"
                Write-Host "  `$PROVIDER = 'ollama:llama3.2'"
                Write-Host "  `$PROVIDER = 'ollama:codellama'"
                Write-Host ""
                return $false
            }
        }
        "opencode" {
            if (-not (Get-Command opencode -ErrorAction SilentlyContinue)) {
                Write-Host "❌ Opencode CLI not found" -ForegroundColor Red
                Write-Host ""
                Write-Host "Install Opencode:"
                Write-Host "  npm install -g opencode-ai"
                Write-Host "  # or using Chocolatey"
                Write-Host "  choco install opencode"
                Write-Host "  # or using Scoop"
                Write-Host "  scoop install opencode"
                Write-Host ""
                Write-Host "Configure Opencode:"
                Write-Host "  Run 'opencode' and use '/connect' command"
                Write-Host ""
                return $false
            }
        }
        default {
            Write-Host "❌ Unknown provider: $Provider" -ForegroundColor Red
            Write-Host ""
            Write-Host "Supported providers:"
            Write-Host "  - claude"
            Write-Host "  - gemini"
            Write-Host "  - codex"
            Write-Host "  - ollama:<model>"
            Write-Host "  - opencode"
            Write-Host ""
            return $false
        }
    }
    
    return $true
}

# ============================================================================
# Provider Execution
# ============================================================================

function Execute-Provider {
    param(
        [string]$Provider,
        [string]$Prompt
    )
    
    $base_provider = $Provider -split ":" | Select-Object -First 1
    
    switch ($base_provider) {
        "claude" {
            Execute-Claude $Prompt
        }
        "gemini" {
            Execute-Gemini $Prompt
        }
        "codex" {
            Execute-Codex $Prompt
        }
        "ollama" {
            $model = $Provider -split ":" | Select-Object -Last 1
            Execute-Ollama $model $Prompt
        }
        "opencode" {
            $model = $Provider -split ":" | Select-Object -Last 1
            if ([string]::IsNullOrEmpty($model) -or $model -eq $Provider) {
                $model = ""
            }
            Execute-Opencode $model $Prompt
        }
    }
}

# ============================================================================
# Individual Provider Implementations
# ============================================================================

function Execute-Claude {
    param([string]$Prompt)
    
    $Prompt | & claude --print 2>&1
    return $LASTEXITCODE
}

function Execute-Gemini {
    param([string]$Prompt)
    
    $Prompt | & gemini 2>&1
    return $LASTEXITCODE
}

function Execute-Codex {
    param([string]$Prompt)
    
    & codex exec $Prompt 2>&1
    return $LASTEXITCODE
}

function Execute-Ollama {
    param(
        [string]$Model,
        [string]$Prompt
    )
    
    & ollama run $Model $Prompt 2>&1
    return $LASTEXITCODE
}


function Execute-Opencode {
    param(
        [string]$Model,
        [string]$Prompt
    )
    
    # Opencode CLI uses 'run' command for non-interactive mode
    if (-not [string]::IsNullOrEmpty($Model)) {
        & opencode run --model $Model $Prompt 2>&1
    } else {
        & opencode run $Prompt 2>&1
    }
    return $LASTEXITCODE
}

# ============================================================================
# Provider Info
# ============================================================================

function Get-ProviderInfo {
    param([string]$Provider)
    
    $base_provider = $Provider -split ":" | Select-Object -First 1
    
    switch ($base_provider) {
        "claude" {
            return "Anthropic Claude Code CLI"
        }
        "gemini" {
            return "Google Gemini CLI"
        }
        "codex" {
            return "OpenAI Codex CLI"
        }
        "ollama" {
            $model = $Provider -split ":" | Select-Object -Last 1
            return "Ollama (model: $model)"
        }
        "opencode" {
            $model = $Provider -split ":" | Select-Object -Last 1
            if ([string]::IsNullOrEmpty($model) -or $model -eq $Provider) {
                return "Opencode AI Coding Agent"
            } else {
                return "Opencode AI Coding Agent (model: $model)"
            }
        }
        default {
            return "Unknown provider"
        }
    }
}
