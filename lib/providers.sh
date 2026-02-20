#!/usr/bin/env bash

# ============================================================================
# Guardian Agent - Provider Functions
# ============================================================================
# Handles execution for different AI providers:
# - claude: Anthropic Claude Code CLI
# - gemini: Google Gemini CLI
# - codex: OpenAI Codex CLI
# - ollama:<model>: Ollama with specified model
# - opencode: Opencode AI Coding Agent
# ============================================================================

# Colors (in case sourced independently)
RED='\033[0;31m'
NC='\033[0m'

# ============================================================================
# Provider Validation
# ============================================================================

validate_provider() {
  local provider="$1"
  local base_provider="${provider%%:*}"

  case "$base_provider" in
    claude)
      if ! command -v claude &> /dev/null; then
        echo -e "${RED}❌ Claude CLI not found${NC}"
        echo ""
        echo "Install Claude Code CLI:"
        echo "  https://claude.ai/code"
        echo ""
        return 1
      fi
      ;;
    gemini)
      if ! command -v gemini &> /dev/null; then
        echo -e "${RED}❌ Gemini CLI not found${NC}"
        echo ""
        echo "Install Gemini CLI:"
        echo "  npm install -g @anthropic-ai/gemini-cli"
        echo "  # or"
        echo "  brew install gemini"
        echo ""
        return 1
      fi
      ;;
    codex)
      if ! command -v codex &> /dev/null; then
        echo -e "${RED}❌ Codex CLI not found${NC}"
        echo ""
        echo "Install OpenAI Codex CLI:"
        echo "  npm install -g @openai/codex"
        echo "  # or"
        echo "  brew install --cask codex"
        echo ""
        return 1
      fi
      ;;
    ollama)
      if ! command -v ollama &> /dev/null; then
        echo -e "${RED}❌ Ollama not found${NC}"
        echo ""
        echo "Install Ollama:"
        echo "  https://ollama.ai/download"
        echo "  # or"
        echo "  brew install ollama"
        echo ""
        return 1
      fi
      # Check if model is specified
      local model="${provider#*:}"
      if [[ "$model" == "$provider" || -z "$model" ]]; then
        echo -e "${RED}❌ Ollama requires a model${NC}"
        echo ""
        echo "Specify model in provider config:"
        echo "  PROVIDER=\"ollama:llama3.2\""
        echo "  PROVIDER=\"ollama:codellama\""
        echo ""
        return 1
      fi
      ;;
    opencode)
      if ! command -v opencode &> /dev/null; then
        echo -e "${RED}❌ Opencode CLI not found${NC}"
        echo ""
        echo "Install Opencode:"
        echo "  curl -fsSL https://opencode.ai/install | bash"
        echo "  # or"
        echo "  brew install anomalyco/tap/opencode"
        echo "  # or"
        echo "  npm install -g opencode-ai"
        echo ""
        echo "Configure Opencode:"
        echo "  Run 'opencode' and use '/connect' command"
        echo ""
        return 1
      fi
      ;;
    *)
      echo -e "${RED}❌ Unknown provider: $provider${NC}"
      echo ""
      echo "Supported providers:"
      echo "  - claude"
      echo "  - gemini"
      echo "  - codex"
      echo "  - ollama:<model>"
      echo "  - opencode"
      echo ""
      return 1
      ;;
  esac

  return 0
}

# ============================================================================
# Provider Execution
# ============================================================================

execute_provider() {
  local provider="$1"
  local prompt="$2"
  local base_provider="${provider%%:*}"

  case "$base_provider" in
    claude)
      execute_claude "$prompt"
      ;;
    gemini)
      execute_gemini "$prompt"
      ;;
    codex)
      execute_codex "$prompt"
      ;;
    ollama)
      local model="${provider#*:}"
      execute_ollama "$model" "$prompt"
      ;;
    opencode)
      local model="${provider#*:}"
      if [[ "$model" == "$provider" ]]; then
        model=""
      fi
      execute_opencode "$model" "$prompt"
      ;;
  esac
}

# ============================================================================
# Individual Provider Implementations
# ============================================================================

execute_claude() {
  local prompt="$1"
  
  # Claude CLI accepts prompt via stdin pipe
  echo "$prompt" | claude --print 2>&1
  return "${PIPESTATUS[1]}"
}

execute_gemini() {
  local prompt="$1"
  
  # Gemini CLI accepts prompt via stdin pipe or -p flag
  echo "$prompt" | gemini 2>&1
  return "${PIPESTATUS[1]}"
}

execute_codex() {
  local prompt="$1"
  
  # Codex uses exec subcommand for non-interactive mode
  # Using --output-last-message to get just the final response
  codex exec "$prompt" 2>&1
  return $?
}

execute_ollama() {
  local model="$1"
  local prompt="$2"
  
  # Ollama accepts prompt as argument after model name
  ollama run "$model" "$prompt" 2>&1
  return $?
}


execute_opencode() {
  local model="$1"
  local prompt="$2"
  
  # Opencode CLI uses 'run' command for non-interactive mode
  # Pass prompt as arguments (opencode will read from stdin if needed)
  if [[ -n "$model" ]]; then
    opencode run --model "$model" "$prompt" 2>&1
  else
    opencode run "$prompt" 2>&1
  fi
  return $?
}

# ============================================================================
# Provider Info
# ============================================================================

get_provider_info() {
  local provider="$1"
  local base_provider="${provider%%:*}"

  case "$base_provider" in
    claude)
      echo "Anthropic Claude Code CLI"
      ;;
    gemini)
      echo "Google Gemini CLI"
      ;;
    codex)
      echo "OpenAI Codex CLI"
      ;;
    ollama)
      local model="${provider#*:}"
      echo "Ollama (model: $model)"
      ;;
    opencode)
      local model="${provider#*:}"
      if [[ "$model" == "$provider" || -z "$model" ]]; then
        echo "Opencode AI Coding Agent"
      else
        echo "Opencode AI Coding Agent (model: $model)"
      fi
      ;;
    *)
      echo "Unknown provider"
      ;;
  esac
}
