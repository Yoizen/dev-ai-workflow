#!/bin/bash
# ============================================================================
# Update All - Actualiza GGA y configs en todos los repositorios
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# Functions
print_step() { echo -e "\n${GREEN}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}  ✓ $1${NC}"; }
print_info() { echo -e "${CYAN}  ℹ $1${NC}"; }
print_warning() { echo -e "${YELLOW}  ⚠ $1${NC}"; }
print_error() { echo -e "${RED}  ✗ $1${NC}"; }

# Parse arguments
DRY_RUN=false
FORCE=false
UPDATE_TOOLS_ONLY=false
UPDATE_CONFIGS_ONLY=false
REPOSITORIES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true; shift ;;
        --force) FORCE=true; shift ;;
        --update-tools-only) UPDATE_TOOLS_ONLY=true; shift ;;
        --update-configs-only) UPDATE_CONFIGS_ONLY=true; shift ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS] repository1 [repository2 ...]"
            echo ""
            echo "Options:"
            echo "  --dry-run              Show what would be done without making changes"
            echo "  --force                Force update configs even if they exist"
            echo "  --update-tools-only    Only update tools (not repository configs)"
            echo "  --update-configs-only  Only update repository configs (not tools)"
            echo "  -h, --help             Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 /home/user/repo1 /home/user/repo2"
            echo "  $0 --dry-run /home/user/repo1"
            echo "  $0 --force /home/user/repo1"
            exit 0
            ;;
        *) REPOSITORIES+=("$1"); shift ;;
    esac
done

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  GGA Bulk Update${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
    print_warning "DRY RUN MODE - No changes will be made"
    echo ""
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_SCRIPT="$SCRIPT_DIR/bootstrap.sh"
GGA_ROOT="$(dirname "$SCRIPT_DIR")"

if [ ! -f "$BOOTSTRAP_SCRIPT" ]; then
    print_error "bootstrap.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Function to get version from package.json
get_version() {
    local pkg_file="$1"
    if [ -f "$pkg_file" ]; then
        grep -o '"version": *"[^"]*"' "$pkg_file" | head -1 | cut -d'"' -f4
    fi
}

# Function to check for GGA updates
check_gga_updates() {
    local gga_path="$1"
    
    if [ ! -d "$gga_path/.git" ]; then
        return 1
    fi
    
    local current_version=$(get_version "$gga_path/package.json")
    
    # Fetch latest from origin quietly
    (cd "$gga_path" && git fetch origin -q 2>/dev/null) || return 1
    
    # Check if we're behind origin
    local behind=$(cd "$gga_path" && git rev-list HEAD..origin/main --count 2>/dev/null || git rev-list HEAD..origin/master --count 2>/dev/null)
    
    if [ -n "$behind" ] && [ "$behind" -gt 0 ]; then
        return 0  # Updates available
    fi
    
    return 1  # No updates
}

# Function to prompt for update
prompt_update() {
    local gga_path="$1"
    local current_version=$(get_version "$gga_path/package.json")
    
    echo ""
    print_info "GGA update available!"
    [ -n "$current_version" ] && echo -e "${GRAY}  Current version: $current_version${NC}"
    echo ""
    
    read -p "$(echo -e "${YELLOW}  Update GGA now? [Y/n]: ${NC}")" response
    
    case "$response" in
        [nN]|[nN][oO])
            print_info "Skipping GGA update"
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

# Stats
TOTAL=0
SUCCESS=0
FAILED=0
SKIPPED=0

# Update tools globally
if [ "$UPDATE_CONFIGS_ONLY" != true ]; then
    print_step "Checking for GGA updates..."
    
    GGA_INSTALL_PATH="$HOME/.local/share/yoizen/gga-copilot"
    
    # Check if GGA update is available
    if check_gga_updates "$GGA_INSTALL_PATH"; then
        if [ "$FORCE" = true ] || prompt_update "$GGA_INSTALL_PATH"; then
            print_info "Updating GGA..."
            
            if [ "$DRY_RUN" != true ]; then
                (
                    cd "$GGA_INSTALL_PATH"
                    # Use --ff-only to avoid merge conflicts, redirect stdin to prevent interactive prompts
                    git pull --ff-only origin main < /dev/null 2>/dev/null || \
                    git pull --ff-only origin master < /dev/null 2>/dev/null || \
                    { print_warning "Could not fast-forward, manual update may be needed"; exit 1; }
                    
                    # Update npm dependencies if package.json exists
                    if [ -f "package.json" ]; then
                        npm install 2>/dev/null
                    fi
                    
                    new_version=$(get_version "package.json")
                    print_success "GGA updated to version ${new_version:-latest}"
                )
            else
                print_info "[DRY RUN] Would update GGA"
            fi
        fi
    else
        print_success "GGA is up to date"
    fi
    
    echo ""
fi

# Update each repository
if [ "$UPDATE_TOOLS_ONLY" != true ]; then
    if [ ${#REPOSITORIES[@]} -eq 0 ]; then
        print_warning "No repositories specified"
        echo ""
        echo -e "${YELLOW}Usage examples:${NC}"
        echo ""
        echo -e "${WHITE}  # Update specific repositories${NC}"
        echo -e "${CYAN}  $0 /home/user/repo1 /home/user/repo2${NC}"
        echo ""
        echo -e "${WHITE}  # Dry run first${NC}"
        echo -e "${CYAN}  $0 --dry-run /home/user/repo1${NC}"
        echo ""
        echo -e "${WHITE}  # Force update configs${NC}"
        echo -e "${CYAN}  $0 --force /home/user/repo1${NC}"
        echo ""
        exit 0
    fi
    
    print_step "Updating repositories..."
    
    for repo in "${REPOSITORIES[@]}"; do
        ((TOTAL++))
        
        echo ""
        echo -e "${GRAY}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        print_info "Processing: $repo"
        
        if [ ! -d "$repo" ]; then
            print_error "Repository not found: $repo"
            ((FAILED++))
            continue
        fi
        
        if [ ! -d "$repo/.git" ]; then
            print_warning "Not a git repository: $repo"
            ((SKIPPED++))
            continue
        fi
        
        if [ ! -f "$repo/.gga" ]; then
            print_warning "GGA not configured (no .gga file)"
            ((SKIPPED++))
            continue
        fi
        
        if [ "$DRY_RUN" != true ]; then
            flags=("--skip-openspec" "--skip-gga" "--skip-vscode")
            [ "$FORCE" = true ] && flags+=("--force")
            
            if bash "$BOOTSTRAP_SCRIPT" "${flags[@]}" "$repo" 2>/dev/null; then
                print_success "Updated successfully"
                ((SUCCESS++))
            else
                print_error "Failed to update"
                ((FAILED++))
            fi
        else
            print_info "[DRY RUN] Would update repository"
            ((SUCCESS++))
        fi
    done
fi

# Summary
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Summary${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${WHITE}  Total repositories: $TOTAL${NC}"
echo -e "${GREEN}  Successfully updated: $SUCCESS${NC}"
echo -e "${RED}  Failed: $FAILED${NC}"
echo -e "${YELLOW}  Skipped: $SKIPPED${NC}"
echo ""

if [ $FAILED -gt 0 ]; then
    print_warning "Some repositories failed to update"
    echo "  Review the output above for details"
    echo ""
    exit 1
fi

if [ $TOTAL -gt 0 ]; then
    print_success "All repositories updated!"
fi

echo ""
