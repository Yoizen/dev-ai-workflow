#!/bin/bash
# ============================================================================
# GA Component Detector - Linux/macOS
# ============================================================================
# Detects installed components, versions, and available updates
# ============================================================================

set -e

# ============================================================================
# GitHub API Configuration
# ============================================================================

GA_REPO="Yoizen/dev-ai-workflow"
GA_API_URL="https://api.github.com/repos/${GA_REPO}"

# ============================================================================
# Component Detection Functions
# ============================================================================

# Get latest version from GitHub releases
get_latest_ga_version() {
    local version
    version=$(curl -fsSL "${GA_API_URL}/releases/latest" 2>/dev/null | \
        grep '"tag_name"' | \
        sed -E 's/.*"tag_name": *"v?([^"]+)".*/\1/' | \
        head -1)
    
    if [[ -z "$version" ]]; then
        # Fallback: get latest tag
        version=$(curl -fsSL "${GA_API_URL}/tags" 2>/dev/null | \
            grep '"name"' | \
            sed -E 's/.*"name": *"v?([^"]+)".*/\1/' | \
            head -1)
    fi
    
    echo "${version:-unknown}"
}

# Get installed GA version
get_installed_ga_version() {
    if command -v ga &> /dev/null; then
        local version_output
        version_output=$(ga version 2>/dev/null || echo "")
        
        # Extract version number (handles "v2.2.0" or "2.2.0" or "Guardian Agent v2.2.0")
        echo "$version_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9x]+' | head -1
    else
        echo ""
    fi
}

# Detect GA installation status
detect_ga() {
    local installed_version
    local latest_version
    local status
    
    installed_version=$(get_installed_ga_version)
    
    if [[ -z "$installed_version" ]]; then
        status="NOT_INSTALLED"
        installed_version="-"
        latest_version=$(get_latest_ga_version)
    else
        latest_version=$(get_latest_ga_version)
        
        if [[ "$installed_version" == "$latest_version" ]] || [[ "$latest_version" == "unknown" ]]; then
            status="UP_TO_DATE"
        else
            # Simple version comparison (works for semantic versioning)
            if [[ "$installed_version" < "$latest_version" ]]; then
                status="OUTDATED"
            else
                status="UP_TO_DATE"
            fi
        fi
    fi
    
    # Output format: STATUS|CURRENT|LATEST
    echo "${status}|${installed_version}|${latest_version}"
}

# Check if SDD Orchestrator skills are installed
detect_sdd_installed() {
    local skills_dir="${1:-.}/skills"
    local count=0
    
    if [[ -d "$skills_dir" ]]; then
        for d in "$skills_dir"/sdd-*; do
            [[ -d "$d" ]] && ((count++)) || true
        done
    fi
    
    echo "$count"
}

# Detect SDD Orchestrator installation status
detect_sdd() {
    local target_dir="${1:-.}"
    local installed_count
    installed_count=$(detect_sdd_installed "$target_dir")
    
    if [[ "$installed_count" -eq 0 ]]; then
        echo "NOT_INSTALLED|0|9"
    elif [[ "$installed_count" -ge 9 ]]; then
        echo "INSTALLED|$installed_count|9"
    else
        echo "PARTIAL|$installed_count|9"
    fi
}

# Detect VS Code extensions
detect_vscode_extensions() {
    local extensions=("github.copilot" "github.copilot-chat")
    local installed=0
    local total=${#extensions[@]}
    local missing_extensions=()
    
    if ! command -v code &> /dev/null; then
        echo "NOT_AVAILABLE|0|${total}|VS Code CLI not found"
        return
    fi
    
    local installed_list
    installed_list=$(code --list-extensions 2>/dev/null || echo "")
    
    for ext in "${extensions[@]}"; do
        if echo "$installed_list" | grep -qi "^${ext}$"; then
            ((installed++))
        else
            missing_extensions+=("$ext")
        fi
    done
    
    local status
    if [[ $installed -eq 0 ]]; then
        status="NOT_INSTALLED"
    elif [[ $installed -eq $total ]]; then
        status="INSTALLED"
    else
        status="PARTIAL"
    fi
    
    # Output format: STATUS|INSTALLED_COUNT|TOTAL_COUNT|MISSING_LIST
    echo "${status}|${installed}|${total}|${missing_extensions[*]}"
}

# Detect prerequisites
detect_prerequisites() {
    local git_version=""
    local node_version=""
    local npm_version=""
    local vscode_status=""
    
    # Git
    if command -v git &> /dev/null; then
        git_version=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    fi
    
    # Node.js
    if command -v node &> /dev/null; then
        node_version=$(node --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    fi
    
    # npm
    if command -v npm &> /dev/null; then
        npm_version=$(npm --version 2>/dev/null)
    fi
    
    # VS Code
    if command -v code &> /dev/null; then
        vscode_status="available"
    else
        vscode_status="not_found"
    fi
    
    # Output format: GIT_VERSION|NODE_VERSION|NPM_VERSION|VSCODE_STATUS
    echo "${git_version:-not_found}|${node_version:-not_found}|${npm_version:-not_found}|${vscode_status}"
}

# Detect all components at once
detect_all_components() {
    local ga_info
    local sdd_info
    local vscode_info
    local prereq_info
    
    ga_info=$(detect_ga)
    sdd_info=$(detect_sdd)
    vscode_info=$(detect_vscode_extensions)
    prereq_info=$(detect_prerequisites)
    
    # Output multi-line format for easy parsing
    cat << EOF
GA:${ga_info}
SDD:${sdd_info}
VSCODE:${vscode_info}
PREREQ:${prereq_info}
EOF
}

# ============================================================================
# Component Version Comparison
# ============================================================================

version_gt() {
    # Returns 0 (true) if $1 > $2
    local ver1="$1"
    local ver2="$2"
    
    # Handle 'x' in version (e.g., 2.2.x)
    ver1="${ver1//x/999}"
    ver2="${ver2//x/999}"
    
    # Simple string comparison works for semantic versioning
    [[ "$ver1" > "$ver2" ]]
}

version_eq() {
    # Returns 0 (true) if $1 == $2
    local ver1="$1"
    local ver2="$2"
    
    [[ "$ver1" == "$ver2" ]]
}

# ============================================================================
# Status Display Helpers
# ============================================================================

format_component_status() {
    local component="$1"
    local status="$2"
    local current="$3"
    local latest="$4"
    
    case "$status" in
        NOT_INSTALLED)
            echo "[$component] Not installed - Latest: $latest"
            ;;
        INSTALLED|UP_TO_DATE)
            echo "[$component] Installed: $current ✓"
            ;;
        OUTDATED)
            echo "[$component] Installed: $current → Update available: $latest"
            ;;
        PARTIAL)
            echo "[$component] Partially installed ($current/$latest components)"
            ;;
        NOT_AVAILABLE)
            echo "[$component] $latest"
            ;;
    esac
}

# ============================================================================
# Main Entry Point (if executed directly)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-all}" in
        ga)
            detect_ga
            ;;
        sdd)
            detect_sdd
            ;;
        vscode)
            detect_vscode_extensions
            ;;
        prereq|prerequisites)
            detect_prerequisites
            ;;
        all)
            detect_all_components
            ;;
        *)
            echo "Usage: $0 {ga|sdd|vscode|prereq|all}"
            exit 1
            ;;
    esac
fi
