#!/usr/bin/env bash
# ============================================================================
# GA + SDD Orchestrator Setup — Main entry point
# ============================================================================
# Usage: ./setup.sh [OPTIONS] [target-directory]
# Replaces: setup/bootstrap.sh, install.sh
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source config early so YWAI_* vars are available before bootstrap.
# config.sh may not exist yet (running via curl|bash), so we guard it.
[[ -f "$SCRIPT_DIR/lib/config.sh" ]] && source "$SCRIPT_DIR/lib/config.sh"

# Bootstrap compat: honour legacy env vars as overrides
[[ -n "${DEV_AI_WORKFLOW_BOOTSTRAP_REPO:-}" ]] && YWAI_REPO_URL="$DEV_AI_WORKFLOW_BOOTSTRAP_REPO"
[[ -n "${DEV_AI_WORKFLOW_REF:-}" ]]            && YWAI_FALLBACK_BRANCH="$DEV_AI_WORKFLOW_REF"

BOOTSTRAP_REPO="${YWAI_REPO_URL:-https://github.com/Yoizen/dev-ai-workflow.git}"
BOOTSTRAP_DIR="${DEV_AI_WORKFLOW_BOOTSTRAP_DIR:-}"

_bootstrap_from_repo_if_needed() {
  local expected_ui="$SCRIPT_DIR/lib/ui.sh"
  local expected_detector="$SCRIPT_DIR/lib/detector.sh"
  local expected_installer="$SCRIPT_DIR/lib/installer.sh"

  if [[ -f "$expected_ui" && -f "$expected_detector" && -f "$expected_installer" ]]; then
    return 0
  fi

  local repo_dir="$BOOTSTRAP_DIR"

  if [[ -n "$repo_dir" ]]; then
    if [[ ! -f "$repo_dir/ywai/setup/setup.sh" ]]; then
      echo "Bootstrap directory is invalid: $repo_dir" >&2
      echo "Expected: $repo_dir/ywai/setup/setup.sh" >&2
      exit 1
    fi
  else
    command -v git >/dev/null 2>&1 || {
      echo "Git is required to bootstrap the installer when running via curl | bash." >&2
      exit 1
    }

    repo_dir="$(mktemp -d "${TMPDIR:-/tmp}/dev-ai-workflow-setup-XXXXXX")"

    # Resolve which ref to bootstrap from: release tag or fallback branch
    local bootstrap_ref
    if [[ -f "$SCRIPT_DIR/lib/config.sh" ]]; then
      source "$SCRIPT_DIR/lib/config.sh"
      bootstrap_ref="$(ywai_resolve_ref)"
    else
      # When running via curl|bash with specific tag, extract from URL
      if [[ -n "${YWAI_VERSION:-}" ]]; then
        bootstrap_ref="$YWAI_VERSION"
      else
        # config.sh not available yet — fetch stable release directly
        bootstrap_ref=$(curl -fsSL --connect-timeout 5 \
          "https://api.github.com/repos/Yoizen/dev-ai-workflow/releases" 2>/dev/null \
          | grep -E '"tag_name"|"prerelease"' \
          | paste - - \
          | grep '"prerelease": *false' \
          | grep -o '"tag_name": *"[^"]*"' \
          | head -1 \
          | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
        bootstrap_ref="${bootstrap_ref:-${DEV_AI_WORKFLOW_REF:-main}}"
      fi
    fi

    echo "Bootstrapping installer from ${BOOTSTRAP_REPO} (${bootstrap_ref})..." >&2

    if ! git clone --depth 1 --branch "$bootstrap_ref" "$BOOTSTRAP_REPO" "$repo_dir" >/dev/null 2>&1; then
      local fallback="${YWAI_FALLBACK_BRANCH:-${DEV_AI_WORKFLOW_REF:-main}}"
      echo "Ref '${bootstrap_ref}' not found, falling back to '${fallback}'..." >&2
      if ! git clone --depth 1 --branch "$fallback" "$BOOTSTRAP_REPO" "$repo_dir" >/dev/null 2>&1; then
        echo "Failed to download the installer." >&2
        echo "Override repo:    YWAI_REPO_URL=<url>" >&2
        echo "Override version: YWAI_VERSION=<tag>" >&2
        echo "Override branch:  YWAI_FALLBACK_BRANCH=<branch>" >&2
        exit 1
      fi
    fi
  fi

  exec bash "$repo_dir/ywai/setup/setup.sh" "$@"
}

_bootstrap_from_repo_if_needed "$@"

# Source library modules
# shellcheck source=lib/ui.sh
source "$SCRIPT_DIR/lib/ui.sh"
# shellcheck source=lib/detector.sh
source "$SCRIPT_DIR/lib/detector.sh"
# shellcheck source=lib/installer.sh
source "$SCRIPT_DIR/lib/installer.sh"

# ── Default flags ─────────────────────────────────────────────────────────────

INTERACTIVE_MODE=true
INSTALL_GA=false
INSTALL_SDD=false
INSTALL_VSCODE=false
SKIP_GA=false
SKIP_SDD=false
SKIP_VSCODE=false
PROVIDER=""
TARGET_DIR=""
PROJECT_TYPE="nest"
UPDATE_ALL=false
FORCE=false
DRY_RUN=false
SHOW_HELP=false
INSTALL_EXTENSIONS=false
LIST_VERSIONS=false

# ── Help ──────────────────────────────────────────────────────────────────────

_show_help() {
  cat << 'EOF'
GA + SDD Orchestrator — Setup

USAGE:
    setup.sh [OPTIONS] [target-directory]

INSTALLATION OPTIONS:
    --all                    Install everything (non-interactive)
    --install-ga             Install only GA
    --install-sdd            Install only SDD Orchestrator
    --install-vscode         Install only VS Code extensions
    --extensions             Install extensions declared by the project type

SKIP OPTIONS:
    --skip-ga                Skip GA installation
    --skip-sdd               Skip SDD Orchestrator installation
    --skip-vscode            Skip VS Code extensions

CONFIGURATION:
    --provider=<name>        AI provider: opencode, claude, gemini, ollama
    --target=<path>          Target directory (default: current directory)
    --type=<name>            Project type: nest, nest-angular, nest-react, python, dotnet, generic
    --list-types             List available project types
    --list-extensions        List available extensions

RELEASE:
    --version=<ref>          Use specific version: tag (v1.0.0), 'stable', or 'latest'
    --channel=<name>         Release channel: stable (default), latest
    --list-versions          List available releases from GitHub

ADVANCED:
    --update-all             Update all installed components
    --force                  Force reinstall/overwrite
    --silent                 Minimal output
    --dry-run                Show what would happen without executing

    -h, --help               Show this help message

ENVIRONMENT:
    YWAI_REPO_URL            Override git repository URL
    YWAI_VERSION             Pin a version/tag (e.g. v1.0.0)
    YWAI_CHANNEL             Release channel: stable (default) | latest
    YWAI_FALLBACK_BRANCH     Branch used when no releases exist (default: main)

EXAMPLES:
    ./setup.sh                               # Interactive mode
    ./setup.sh --all                         # Install everything
    ./setup.sh --all --provider=claude       # Install with Claude provider
    ./setup.sh --install-ga --install-sdd    # Install GA and SDD only
    ./setup.sh --update-all                  # Update all components
    ./setup.sh --all --dry-run               # Preview what would happen

PROVIDERS:
    opencode   OpenCode AI Coding Agent (default)
    claude     Anthropic Claude
    gemini     Google Gemini
    ollama     Ollama (local models)

For more information: https://github.com/Yoizen/dev-ai-workflow
EOF
}

# ── Argument parser ───────────────────────────────────────────────────────────

_parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --all)
        INTERACTIVE_MODE=false; INSTALL_GA=true; INSTALL_SDD=true; INSTALL_VSCODE=true; INSTALL_EXTENSIONS=true; shift ;;
      --install-ga)
        INTERACTIVE_MODE=false; INSTALL_GA=true; shift ;;
      --install-sdd)
        INTERACTIVE_MODE=false; INSTALL_SDD=true; shift ;;
      --install-vscode)
        INTERACTIVE_MODE=false; INSTALL_VSCODE=true; shift ;;
      --skip-ga)   SKIP_GA=true; shift ;;
      --skip-sdd)  SKIP_SDD=true; shift ;;
      --skip-vscode) SKIP_VSCODE=true; shift ;;
      --provider=*) PROVIDER="${1#*=}"; shift ;;
      --target=*)   TARGET_DIR="${1#*=}"; shift ;;
      --type=*)     PROJECT_TYPE="${1#*=}"; shift ;;
      --list-types) list_project_types; exit 0 ;;
      --version=*)   YWAI_VERSION="${1#*=}"; shift ;;
      --channel=*)   YWAI_CHANNEL="${1#*=}"; shift ;;
      --list-versions) LIST_VERSIONS=true; shift ;;
      --list-extensions) list_extensions; exit 0 ;;
      --update-all)
        INTERACTIVE_MODE=false; UPDATE_ALL=true; shift ;;
      --force)   FORCE=true; shift ;;
      --silent)  SILENT=true; shift ;;
      --dry-run) DRY_RUN=true; shift ;;
      -h|--help) SHOW_HELP=true; shift ;;
      --extensions|--install-extensions)
        INTERACTIVE_MODE=false; INSTALL_EXTENSIONS=true; shift ;;
      -*)
        print_error "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1 ;;
      *) TARGET_DIR="$1"; shift ;;
    esac
  done
}

# ── Prerequisite check ────────────────────────────────────────────────────────

_check_prereqs() {
  print_step "Checking prerequisites..."
  local prereq_status
  prereq_status=$(detect_prerequisites)

  IFS='|' read -r _git_ver _node_ver _npm_ver _vscode_status <<< "$prereq_status"

  if [[ "$_git_ver" == "not_found" ]]; then
    print_error "Git is required but not found."
    exit 1
  fi

  print_success "Git $_git_ver"
  [[ "$_node_ver" != "not_found" ]] \
    && print_success "Node.js $_node_ver" \
    || print_warning "Node.js not found (may be needed for some extensions)"
  [[ "$_npm_ver" != "not_found" ]] \
    && print_success "npm $_npm_ver" \
    || print_warning "npm not found (may be needed for some extensions)"

  if [[ "$_vscode_status" == "available" ]]; then
    print_success "VS Code CLI available"
  else
    print_warning "VS Code CLI not found (extensions will be skipped)"
    SKIP_VSCODE=true
  fi

  # Export so callers can use it
  VSCODE_STATUS="$_vscode_status"
}

# ── Resolve target directory ──────────────────────────────────────────────────

_resolve_target_dir() {
  [[ -z "$TARGET_DIR" ]] && TARGET_DIR="$(pwd)"

  if [[ ! -d "$TARGET_DIR" ]]; then
    print_error "Directory not found: $TARGET_DIR"
    exit 1
  fi

  TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
  print_info "Target directory: $TARGET_DIR"
}

# ── Ensure git repo ───────────────────────────────────────────────────────────

_ensure_git_repo() {
  [[ -d "$TARGET_DIR/.git" ]] && return 0
  [[ "$DRY_RUN" == true ]] && { print_info "[DRY RUN] Would initialize git repository"; return 0; }
  print_info "Initializing git repository..."
  (cd "$TARGET_DIR" && git init >/dev/null 2>&1)
  print_success "Git repository initialized"
}

# ── Run installs ──────────────────────────────────────────────────────────────

_run_installs() {
  local configured_project=false

  if [[ "$UPDATE_ALL" == true ]]; then
    [[ "$DRY_RUN" == true ]] \
      && print_info "[DRY RUN] Would update all components" \
      || update_all_components "$TARGET_DIR"
    return
  fi

  if [[ "$SKIP_GA" == false && "$INSTALL_GA" == true ]]; then
    print_step "Installing GA..."
    if [[ "$DRY_RUN" == true ]]; then
      print_info "[DRY RUN] Would install GA to $GA_DIR"
    else
      local force_flag="false"
      [[ "$INTERACTIVE_MODE" == false || "$FORCE" == true ]] && force_flag="true"
      install_ga "install" "$force_flag"
    fi
  fi

  if [[ "$SKIP_SDD" == false && "$INSTALL_SDD" == true ]]; then
    print_step "Installing SDD Orchestrator..."
    [[ "$DRY_RUN" == true ]] \
      && print_info "[DRY RUN] Would install SDD Orchestrator in $TARGET_DIR" \
      || install_sdd "$TARGET_DIR"
  fi

  if [[ "$SKIP_VSCODE" == false && "$INSTALL_VSCODE" == true && "${VSCODE_STATUS:-}" == "available" ]]; then
    print_step "Installing VS Code extensions..."
    [[ "$DRY_RUN" == true ]] \
      && print_info "[DRY RUN] Would install VS Code extensions" \
      || install_vscode_extensions
  fi

  if [[ "$UPDATE_ALL" == false ]]; then
    print_step "Installing OpenCode CLI..."
    [[ "$DRY_RUN" == true ]] \
      && print_info "[DRY RUN] Would install OpenCode CLI (npm i -g opencode-ai)" \
      || install_opencode
  fi


  if [[ "$INSTALL_GA" == true || "$INSTALL_SDD" == true ]]; then
    print_step "Configuring project..."
    if [[ "$DRY_RUN" == true ]]; then
      print_info "[DRY RUN] Would configure project in $TARGET_DIR"
      [[ -n "$PROVIDER" ]] && print_info "[DRY RUN] Provider: $PROVIDER"
      print_info "[DRY RUN] Project type: ${PROJECT_TYPE:-nest}"
    else
      local skip_ga_flag="false"
      [[ "$SKIP_GA" == true ]] && skip_ga_flag="true"
      local force_flag="false"
      [[ "$FORCE" == true ]] && force_flag="true"
      configure_project "$PROVIDER" "$TARGET_DIR" "$skip_ga_flag" "$PROJECT_TYPE" "$force_flag"
    fi
    configured_project=true
  fi

  if [[ "$configured_project" == true ]]; then
    INSTALL_EXTENSIONS=true
  fi

  if [[ "$INSTALL_EXTENSIONS" == true || "$configured_project" == true ]]; then
    print_step "Installing extensions for type: $PROJECT_TYPE..."
    [[ "$DRY_RUN" == true ]] \
      && print_info "[DRY RUN] Would install extensions for type $PROJECT_TYPE in $TARGET_DIR" \
      || install_type_extensions "$PROJECT_TYPE" "$TARGET_DIR"
  fi
}

# ── Next steps display ────────────────────────────────────────────────────────

_show_next_steps() {
  [[ "$SILENT" == true ]] && return
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}  Setup Complete!${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "${WHITE}Configured:${NC}"
  [[ "$INSTALL_GA" == true ]]     && echo -e "${CYAN}  • GA (Guardian Agent)${NC}"
  [[ "$INSTALL_SDD" == true ]]    && echo -e "${CYAN}  • SDD Orchestrator${NC}"
  [[ "$INSTALL_VSCODE" == true ]] && echo -e "${CYAN}  • VS Code Extensions${NC}"
  [[ "$INSTALL_EXTENSIONS" == true ]] && echo -e "${CYAN}  • Type Extensions (${PROJECT_TYPE:-nest})${NC}"
  echo ""
  echo -e "${YELLOW}Next steps:${NC}"
  [[ "$INSTALL_GA" == true && -n "$PROVIDER" ]] && echo -e "${WHITE}  1. Review .ga config (provider: $PROVIDER)${NC}"
  echo -e "${WHITE}  2. Customize AGENTS.md for your project${NC}"
  [[ "$INSTALL_SDD" == true ]]  && echo -e "${WHITE}  3. Use /sdd:new for spec-driven development${NC}"
  [[ "$INSTALL_GA" == true ]]   && echo -e "${WHITE}  4. Run 'ga run' before committing code${NC}"
  echo ""
  echo -e "${CYAN}Repository path: $TARGET_DIR${NC}"
  echo ""
}

# ── Automated mode ────────────────────────────────────────────────────────────

_run_automated() {
  print_banner "GA + SDD Orchestrator — Setup"

  [[ "$DRY_RUN" == true ]] && { print_warning "DRY RUN MODE — no changes will be made"; echo ""; }

  _resolve_target_dir
  _check_prereqs
  _ensure_git_repo
  _run_installs

  [[ "$DRY_RUN" == true ]] \
    && print_warning "DRY RUN completed — no changes made" \
    || _show_next_steps
}

# ── Interactive mode ──────────────────────────────────────────────────────────

_run_interactive() {
  print_banner "GA + SDD Orchestrator — Setup"

  echo -e "${WHITE}This will install GA + SDD Orchestrator in your project.${NC}"
  echo ""

  _check_prereqs
  echo ""

  if [[ -z "$TARGET_DIR" ]]; then
    read -rp "Target directory [$(pwd)]: " TARGET_DIR
    TARGET_DIR="${TARGET_DIR:-$(pwd)}"
  fi
  _resolve_target_dir
  echo ""

  INSTALL_GA=false; INSTALL_SDD=false; INSTALL_VSCODE=false
  ask_yes_no "Install GA (AI code review)?" "y"      && INSTALL_GA=true
  ask_yes_no "Install SDD Orchestrator (spec-first dev)?" "y" && INSTALL_SDD=true
  [[ "${VSCODE_STATUS:-}" == "available" ]] && ask_yes_no "Install VS Code extensions?" "y" && INSTALL_VSCODE=true
  echo ""

  echo -e "${WHITE}Will install:${NC}"
  [[ "$INSTALL_GA" == true ]]     && echo "  • GA"
  [[ "$INSTALL_SDD" == true ]]    && echo "  • SDD Orchestrator"
  [[ "$INSTALL_VSCODE" == true ]] && echo "  • VS Code Extensions"
  echo "  → Target: $TARGET_DIR"
  echo ""

  ask_yes_no "Proceed?" "y" || { print_warning "Cancelled"; exit 0; }
  echo ""

  _ensure_git_repo

  if [[ "$INSTALL_GA" == true ]]; then
    print_step "Installing GA..."
    install_ga "install" "false"
  fi
  if [[ "$INSTALL_SDD" == true ]]; then
    print_step "Installing SDD Orchestrator..."
    install_sdd "$TARGET_DIR"
  fi
  if [[ "$INSTALL_VSCODE" == true ]]; then
    print_step "Installing VS Code extensions..."
    install_vscode_extensions
  fi
  print_step "Installing OpenCode CLI..."
  install_opencode
  print_step "Configuring project..."
  local skip_ga_flag="false"
  [[ "$INSTALL_GA" == false ]] && skip_ga_flag="true"
  configure_project "$PROVIDER" "$TARGET_DIR" "$skip_ga_flag" "$PROJECT_TYPE"

  INSTALL_EXTENSIONS=true
  print_step "Installing extensions for type: $PROJECT_TYPE..."
  install_type_extensions "$PROJECT_TYPE" "$TARGET_DIR"

  _show_next_steps
}

# ── Main ──────────────────────────────────────────────────────────────────────

_parse_args "$@"

# Propagate CLI overrides to sourced libs/subprocesses (e.g. ywai_resolve_ref, installers).
export YWAI_VERSION

if [[ "$SHOW_HELP" == true ]]; then
  _show_help; exit 0
fi

if [[ "$LIST_VERSIONS" == true ]]; then
  echo "Available releases for ${YWAI_REPO}:"
  curl -fsSL --connect-timeout 5 "${YWAI_API_URL}/releases" 2>/dev/null \
    | grep '"tag_name"' \
    | sed -E 's/.*"tag_name": *"([^"]+)".*/  \1/' \
    || echo "  (could not reach GitHub API)"
  echo ""
  echo "  Current channel : ${YWAI_CHANNEL}"
  echo "  Resolved ref    : $(ywai_resolve_ref)"
  exit 0
fi

# Auto-switch to non-interactive in CI / piped environments
if [[ "$INTERACTIVE_MODE" == true ]] && ! is_interactive_environment; then
  print_warning "Non-interactive environment detected — using automated mode with --all"
  INTERACTIVE_MODE=false
  INSTALL_GA=true; INSTALL_SDD=true; INSTALL_VSCODE=true; INSTALL_EXTENSIONS=true
fi

if [[ "$INTERACTIVE_MODE" == true ]]; then
  _run_interactive
else
  _run_automated
fi
