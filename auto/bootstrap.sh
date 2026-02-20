#!/bin/bash
# ============================================================================
# GGA + OpenSpec Bootstrap - Automated Setup Script
# ============================================================================
# Simple interactive installer with full flag support for automation
# Usage: ./bootstrap.sh [OPTIONS] [target-directory]
# ============================================================================

set -e

# ============================================================================
# Script Directory Detection
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$SCRIPT_DIR"

# ============================================================================
# Source Library Modules
# ============================================================================

source "$BOOTSTRAP_DIR/lib/env-detect.sh"
source "$BOOTSTRAP_DIR/lib/detector.sh"
source "$BOOTSTRAP_DIR/lib/installer.sh"

# ============================================================================
# Configuration
# ============================================================================

GGA_REPO="https://github.com/Yoizen/gga-copilot.git"
GGA_DIR="$HOME/.local/share/yoizen/gga-copilot"

VSCODE_EXTENSIONS=(
    "github.copilot"
    "github.copilot-chat"
)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# ============================================================================
# Default Flags
# ============================================================================

INTERACTIVE_MODE=true
INSTALL_GGA=false
INSTALL_OPENSPEC=false
INSTALL_VSCODE=false
SKIP_GGA=false
SKIP_OPENSPEC=false
SKIP_VSCODE=false
PROVIDER=""
TARGET_DIR=""
UPDATE_ALL=false
FORCE=false
SILENT=false
DRY_RUN=false
SHOW_HELP=false
INSTALL_HOOKS=false
INSTALL_BIOME=false

# ============================================================================
# Helper Functions
# ============================================================================

print_banner() {
    if [[ "$SILENT" == true ]]; then
        return
    fi
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  GGA + OpenSpec Bootstrap - Automated Setup${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_step() {
    if [[ "$SILENT" == true ]]; then
        return
    fi
    echo ""
    echo -e "${GREEN}▶ $1${NC}"
}

print_success() {
    if [[ "$SILENT" == true ]]; then
        return
    fi
    echo -e "${GREEN}  ✓ $1${NC}"
}

print_info() {
    if [[ "$SILENT" == true ]]; then
        return
    fi
    echo -e "${CYAN}  ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}  ⚠ $1${NC}" >&2
}

print_error() {
    echo -e "${RED}  ✗ $1${NC}" >&2
}

command_exists() {
    command -v "$1" &> /dev/null
}

# ============================================================================
# Help Message
# ============================================================================

show_help() {
    cat << 'EOF'
GGA + OpenSpec Bootstrap - Automated Setup

USAGE:
    bootstrap.sh [OPTIONS] [target-directory]

INSTALLATION OPTIONS:
    --all                    Install everything (non-interactive mode)
    --install-gga           Install only GGA
    --install-openspec      Install only OpenSpec
    --install-vscode        Install only VS Code extensions
    --hooks                 Install OpenCode command hooks plugin
    --biome                 Install optional Biome baseline (minimal rules)

SKIP OPTIONS:
    --skip-gga              Skip GGA installation
    --skip-openspec         Skip OpenSpec installation
    --skip-vscode           Skip VS Code extensions

CONFIGURATION:
    --provider=<name>       Set AI provider (opencode/claude/gemini/ollama)
    --target=<path>         Target directory (default: current directory)

ADVANCED:
    --update-all            Update all installed components
    --force                 Force reinstall/overwrite
    --silent                Minimal output
    --dry-run               Show what would be done without executing

HELP:
    -h, --help              Show this help message

EXAMPLES:
    # Interactive mode (guided TUI)
    ./bootstrap.sh

    # Install everything automatically
    ./bootstrap.sh --all

    # Install only GGA and OpenSpec, skip VS Code
    ./bootstrap.sh --install-gga --install-openspec

    # Install with specific provider
    ./bootstrap.sh --all --provider=claude

    # Update all components in a specific directory
    ./bootstrap.sh --update-all --target=/path/to/project

    # Dry run to see what would happen
    ./bootstrap.sh --all --dry-run

PROVIDERS:
    opencode                OpenCode AI Coding Agent (default)
    claude                  Anthropic Claude
    gemini                  Google Gemini
    ollama                  Ollama (local models)

For more information, visit:
    https://github.com/Yoizen/gga-copilot
EOF
}

# ============================================================================
# Parse Arguments
# ============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --all)
                INTERACTIVE_MODE=false
                INSTALL_GGA=true
                INSTALL_OPENSPEC=true
                INSTALL_VSCODE=true
                shift
                ;;
            --install-gga)
                INTERACTIVE_MODE=false
                INSTALL_GGA=true
                shift
                ;;
            --install-openspec)
                INTERACTIVE_MODE=false
                INSTALL_OPENSPEC=true
                shift
                ;;
            --install-vscode)
                INTERACTIVE_MODE=false
                INSTALL_VSCODE=true
                shift
                ;;
            --skip-gga)
                SKIP_GGA=true
                shift
                ;;
            --skip-openspec)
                SKIP_OPENSPEC=true
                shift
                ;;
            --skip-vscode)
                SKIP_VSCODE=true
                shift
                ;;
            --provider=*)
                PROVIDER="${1#*=}"
                shift
                ;;
            --target=*)
                TARGET_DIR="${1#*=}"
                shift
                ;;
            --update-all)
                INTERACTIVE_MODE=false
                UPDATE_ALL=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --silent)
                SILENT=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                SHOW_HELP=true
                shift
                ;;
            --hooks|--install-hooks)
                INTERACTIVE_MODE=false
                INSTALL_HOOKS=true
                shift
                ;;
            --biome|--install-biome)
                INTERACTIVE_MODE=false
                INSTALL_BIOME=true
                shift
                ;;
            -*)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                TARGET_DIR="$1"
                shift
                ;;
        esac
    done
}

# ============================================================================
# Automated Installation (Non-Interactive)
# ============================================================================

run_automated_installation() {
    print_banner
    
    if [[ "$DRY_RUN" == true ]]; then
        print_warning "DRY RUN MODE - No changes will be made"
        echo ""
    fi
    
    if [[ -z "$TARGET_DIR" ]]; then
        TARGET_DIR="$(pwd)"
    fi
    
    if [[ ! -d "$TARGET_DIR" ]]; then
        print_error "Directory not found: $TARGET_DIR"
        exit 1
    fi
    
    TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
    print_info "Target directory: $TARGET_DIR"
    
    if [[ ! -d "$TARGET_DIR/.git" ]] && [[ "$DRY_RUN" == false ]]; then
        print_info "Initializing git repository..."
        (cd "$TARGET_DIR" && git init >/dev/null 2>&1)
        print_success "Git repository initialized"
    fi
    
    print_step "Checking prerequisites..."
    local prereq_status
    prereq_status=$(detect_prerequisites)
    
    local git_version node_version npm_version vscode_status
    IFS='|' read -r git_version node_version npm_version vscode_status <<< "$prereq_status"
    
    if [[ "$git_version" == "NOT_FOUND" ]] || [[ "$node_version" == "NOT_FOUND" ]] || [[ "$npm_version" == "NOT_FOUND" ]]; then
        print_error "Missing prerequisites. Please install Git, Node.js, and npm."
        exit 1
    fi
    
    print_success "Git $git_version"
    print_success "Node.js $node_version"
    print_success "npm $npm_version"
    
    if [[ "$vscode_status" == "available" ]]; then
        print_success "VS Code CLI available"
    else
        print_warning "VS Code CLI not found (extensions will be skipped)"
        SKIP_VSCODE=true
    fi
    
    if [[ "$UPDATE_ALL" == true ]]; then
        print_step "Updating all components..."
        if [[ "$DRY_RUN" == false ]]; then
            update_all_components "$TARGET_DIR"
        else
            print_info "[DRY RUN] Would update all components"
        fi
        return
    fi
    
    if [[ "$SKIP_GGA" == false ]] && [[ "$INSTALL_GGA" == true ]]; then
        print_step "Installing GGA..."
        if [[ "$DRY_RUN" == false ]]; then
            # Pass true for force if non-interactive mode
            local force_update="false"
            [[ "$INTERACTIVE_MODE" == false ]] && force_update="true"
            install_gga "install" "$force_update"
        else
            print_info "[DRY RUN] Would install GGA to $GGA_DIR"
        fi
    fi
    
    if [[ "$SKIP_OPENSPEC" == false ]] && [[ "$INSTALL_OPENSPEC" == true ]]; then
        print_step "Installing OpenSpec..."
        if [[ "$DRY_RUN" == false ]]; then
            install_openspec "install" "$TARGET_DIR"
        else
            print_info "[DRY RUN] Would install OpenSpec in $TARGET_DIR"
        fi
    fi
    
    if [[ "$SKIP_VSCODE" == false ]] && [[ "$INSTALL_VSCODE" == true ]] && [[ "$vscode_status" == "available" ]]; then
        print_step "Installing VS Code extensions..."
        if [[ "$DRY_RUN" == false ]]; then
            install_vscode_extensions "install"
        else
            print_info "[DRY RUN] Would install VS Code extensions: ${VSCODE_EXTENSIONS[*]}"
        fi
    fi
    
    if [[ "$INSTALL_HOOKS" == true ]]; then
        print_step "Installing OpenCode command hooks..."
        if [[ "$DRY_RUN" == false ]]; then
            install_hooks "install" "$TARGET_DIR"
        else
            print_info "[DRY RUN] Would install OpenCode command hooks"
        fi
    fi
    
    if [[ "$INSTALL_GGA" == true ]] || [[ "$INSTALL_OPENSPEC" == true ]] || [[ "$INSTALL_HOOKS" == true ]] || [[ "$INSTALL_BIOME" == true ]]; then
        print_step "Configuring project..."
        if [[ "$DRY_RUN" == false ]]; then
            local skip_gga_flag="false"
            [[ "$SKIP_GGA" == true ]] && skip_gga_flag="true"
            configure_project "$PROVIDER" "$TARGET_DIR" "$skip_gga_flag" "$INSTALL_BIOME"
        else
            print_info "[DRY RUN] Would configure project in $TARGET_DIR"
            [[ -n "$PROVIDER" ]] && print_info "[DRY RUN] Would set provider to: $PROVIDER"
            [[ "$INSTALL_BIOME" == true ]] && print_info "[DRY RUN] Would apply optional Biome baseline"
        fi
    fi
    
    if [[ "$DRY_RUN" == false ]]; then
        show_next_steps "$TARGET_DIR"
    else
        print_warning "DRY RUN completed - no changes made"
    fi
}

# ============================================================================
# Interactive Installation (Simple y/n prompts)
# ============================================================================

ask_yes_no() {
    local prompt="$1"
    local default="${2:-y}"
    local reply
    
    if [[ "$default" == "y" ]]; then
        read -p "$prompt [Y/n]: " reply
        reply="${reply:-y}"
    else
        read -p "$prompt [y/N]: " reply
        reply="${reply:-n}"
    fi
    
    [[ "$reply" =~ ^[Yy]$ ]]
}

run_interactive_installation() {
    print_banner
    
    echo ""
    echo -e "${WHITE}This will install GGA + OpenSpec in your project.${NC}"
    echo ""
    
    # Check prerequisites
    print_step "Checking prerequisites..."
    local prereq_status
    prereq_status=$(detect_prerequisites)
    
    local git_version node_version npm_version vscode_status
    IFS='|' read -r git_version node_version npm_version vscode_status <<< "$prereq_status"
    
    if [[ "$git_version" == "NOT_FOUND" ]] || [[ "$node_version" == "NOT_FOUND" ]] || [[ "$npm_version" == "NOT_FOUND" ]]; then
        print_error "Missing prerequisites. Please install Git, Node.js, and npm."
        exit 1
    fi
    
    print_success "Git $git_version"
    print_success "Node.js $node_version"
    print_success "npm $npm_version"
    [[ "$vscode_status" == "available" ]] && print_success "VS Code CLI available" || print_warning "VS Code CLI not found"
    echo ""
    
    # Target directory
    if [[ -z "$TARGET_DIR" ]]; then
        read -p "Target directory [$(pwd)]: " TARGET_DIR
        TARGET_DIR="${TARGET_DIR:-$(pwd)}"
    fi
    
    if [[ ! -d "$TARGET_DIR" ]]; then
        print_error "Directory not found: $TARGET_DIR"
        exit 1
    fi
    
    TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
    echo ""
    
    # Simple y/n questions
    INSTALL_GGA=false
    INSTALL_OPENSPEC=false
    INSTALL_VSCODE=false
    INSTALL_BIOME=false
    
    ask_yes_no "Install GGA (AI code review)?" "y" && INSTALL_GGA=true
    ask_yes_no "Install OpenSpec (spec-first dev)?" "y" && INSTALL_OPENSPEC=true
    [[ "$vscode_status" == "available" ]] && ask_yes_no "Install VS Code extensions?" "y" && INSTALL_VSCODE=true
    ask_yes_no "Install optional Biome baseline (minimal lint/format rules)?" "n" && INSTALL_BIOME=true
    
    echo ""
    
    # Confirm
    echo -e "${WHITE}Will install:${NC}"
    [[ "$INSTALL_GGA" == true ]] && echo "  • GGA"
    [[ "$INSTALL_OPENSPEC" == true ]] && echo "  • OpenSpec"
    [[ "$INSTALL_VSCODE" == true ]] && echo "  • VS Code Extensions"
    [[ "$INSTALL_BIOME" == true ]] && echo "  • Biome Baseline (optional)"
    echo "  → Target: $TARGET_DIR"
    echo ""
    
    if ! ask_yes_no "Proceed?" "y"; then
        print_warning "Cancelled"
        exit 0
    fi
    
    echo ""
    
    # Initialize git if needed
    if [[ ! -d "$TARGET_DIR/.git" ]]; then
        print_info "Initializing git repository..."
        (cd "$TARGET_DIR" && git init >/dev/null 2>&1)
        print_success "Git repository initialized"
    fi
    
    # Install components
    if [[ "$INSTALL_GGA" == true ]]; then
        print_step "Installing GGA..."
        # Pass true for force if non-interactive mode
        local force_update="false"
        [[ "$INTERACTIVE_MODE" == false ]] && force_update="true"
        install_gga "install" "$force_update"
    fi
    
    if [[ "$INSTALL_OPENSPEC" == true ]]; then
        print_step "Installing OpenSpec..."
        install_openspec "install" "$TARGET_DIR"
    fi
    
    if [[ "$INSTALL_VSCODE" == true ]]; then
        print_step "Installing VS Code extensions..."
        install_vscode_extensions "install"
    fi
    
    if [[ "$INSTALL_HOOKS" == true ]]; then
        print_step "Installing OpenCode command hooks..."
        install_hooks "install" "$TARGET_DIR"
    fi
    
    # Configure project
    print_step "Configuring project..."
    local skip_gga_flag="false"
    [[ "$INSTALL_GGA" == false ]] && skip_gga_flag="true"
    configure_project "$PROVIDER" "$TARGET_DIR" "$skip_gga_flag" "$INSTALL_BIOME"
    
    show_next_steps "$TARGET_DIR"
}

# ============================================================================
# Next Steps Display
# ============================================================================

show_next_steps() {
    local repo_path="$1"
    
    if [[ "$SILENT" == true ]]; then
        return
    fi
    
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Setup Complete! 🎉${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}Your repository is now configured with:${NC}"
    [[ "$INSTALL_GGA" == true ]] && echo -e "${CYAN}  • GGA (Guardian Agent)${NC}"
    [[ "$INSTALL_OPENSPEC" == true ]] && echo -e "${CYAN}  • OpenSpec (Spec-First methodology)${NC}"
    [[ "$INSTALL_VSCODE" == true ]] && echo -e "${CYAN}  • VS Code Extensions${NC}"
    [[ "$INSTALL_HOOKS" == true ]] && echo -e "${CYAN}  • OpenCode Command Hooks${NC}"
    [[ "$INSTALL_BIOME" == true ]] && echo -e "${CYAN}  • Biome Baseline (optional)${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    [[ "$INSTALL_GGA" == true ]] && [[ -n "$PROVIDER" ]] && echo -e "${WHITE}  1. Review .gga config (provider: $PROVIDER)${NC}"
    echo -e "${WHITE}  2. Customize AGENTS.MD for your project${NC}"
    [[ "$INSTALL_OPENSPEC" == true ]] && echo -e "${WHITE}  3. Use OpenSpec to create specifications${NC}"
    [[ "$INSTALL_GGA" == true ]] && echo -e "${WHITE}  4. Run 'gga review' before committing code${NC}"
    echo ""
    echo -e "${CYAN}Repository path: $repo_path${NC}"
    echo ""
}

# ============================================================================
# Main Execution
# ============================================================================

parse_arguments "$@"

if [[ "$SHOW_HELP" == true ]]; then
    show_help
    exit 0
fi

if [[ "$INTERACTIVE_MODE" == true ]]; then
    if ! is_interactive_environment; then
        print_warning "Non-interactive environment detected, using automated mode with --all"
        INTERACTIVE_MODE=false
        INSTALL_GGA=true
        INSTALL_OPENSPEC=true
        INSTALL_VSCODE=true
    fi
fi

if [[ "$INTERACTIVE_MODE" == true ]]; then
    run_interactive_installation
else
    run_automated_installation
fi
