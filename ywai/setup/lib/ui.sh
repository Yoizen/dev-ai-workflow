#!/usr/bin/env bash
# Shared UI utilities: colors, print functions, prompts, env detection

# Colors (guard against double-sourcing)
if [[ -z "${_GA_UI_LOADED:-}" ]]; then
  _GA_UI_LOADED=1

  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  WHITE='\033[1;37m'
  GRAY='\033[0;90m'
  BOLD='\033[1m'
  NC='\033[0m'

  # SILENT can be set externally to suppress non-error output
  SILENT="${SILENT:-false}"
fi

# ── Print helpers ─────────────────────────────────────────────────────────────

print_banner() {
  [[ "$SILENT" == true ]] && return
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}  ${BOLD}${1:-GA + SDD Orchestrator — Setup}${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
}

print_step()    { [[ "$SILENT" == true ]] && return; echo -e "\n${GREEN}▶ $1${NC}"; }
print_success() { [[ "$SILENT" == true ]] && return; echo -e "${GREEN}  ✓ $1${NC}"; }
print_info()    { [[ "$SILENT" == true ]] && return; echo -e "${CYAN}  ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}  ⚠ $1${NC}" >&2; }
print_error()   { echo -e "${RED}  ✗ $1${NC}" >&2; }

# ── Utilities ─────────────────────────────────────────────────────────────────

# Returns 0 if command exists
command_exists() { command -v "$1" &>/dev/null; }

# Prompt yes/no; default is first char of $2 (y or n)
# Returns 0 for yes, 1 for no
ask_yes_no() {
  local prompt="$1" default="${2:-y}" reply
  if [[ "$default" == "y" ]]; then
    read -rp "$prompt [Y/n]: " reply
    reply="${reply:-y}"
  else
    read -rp "$prompt [y/N]: " reply
    reply="${reply:-n}"
  fi
  [[ "$reply" =~ ^[Yy]$ ]]
}

# ── Environment detection ─────────────────────────────────────────────────────

# Returns 0 when running in a real interactive terminal (not CI, not piped)
is_interactive_environment() {
  [[ -t 0 && -t 1 ]] || return 1
  [[ -z "${CI:-}" && -z "${CONTINUOUS_INTEGRATION:-}" && \
     -z "${JENKINS_HOME:-}" && -z "${TRAVIS:-}" && \
     -z "${CIRCLECI:-}" && -z "${GITLAB_CI:-}" && \
     -z "${GITHUB_ACTIONS:-}" && -z "${BUILDKITE:-}" && \
     -z "${DRONE:-}" ]] || return 1
  [[ "${DEBIAN_FRONTEND:-}" != "noninteractive" ]] || return 1
  [[ "${TERM:-}" != "dumb" ]] || return 1
}
