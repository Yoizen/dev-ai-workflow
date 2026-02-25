#!/bin/bash
# Installation Module for GA Components

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GA_REPO="https://github.com/Yoizen/dev-ai-workflow.git"
GA_DIR="$HOME/.local/share/yoizen/dev-ai-workflow"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Get version from package.json
get_version() {
    local pkg_file="$1"
    if [ -f "$pkg_file" ]; then
        grep -o '"version": *"[^"]*"' "$pkg_file" | head -1 | cut -d'"' -f4
    fi
}

# Check if GA updates are available
check_ga_updates() {
    local ga_path="$1"
    
    if [ ! -d "$ga_path/.git" ]; then
        return 1
    fi
    
    # Fetch latest from origin quietly
    (cd "$ga_path" && git fetch origin -q 2>/dev/null) || return 1
    
    # Check if we're behind origin
    local behind=$(cd "$ga_path" && git rev-list HEAD..origin/main --count 2>/dev/null || git rev-list HEAD..origin/master --count 2>/dev/null)
    
    if [ -n "$behind" ] && [ "$behind" -gt 0 ]; then
        return 0  # Updates available
    fi
    
    return 1  # No updates
}

# Prompt user for update
prompt_ga_update() {
    local ga_path="$1"
    local current_version=$(get_version "$ga_path/package.json")
    
    echo ""
    print_info "GA update available!"
    [ -n "$current_version" ] && echo -e "  Current version: $current_version"
    echo ""
    
    # Use /dev/tty to read from terminal even when stdin is redirected
    if [ -t 0 ]; then
        # stdin is a terminal
        read -p "$(echo -e "${YELLOW}  Update GA now? [Y/n]: ${NC}")" response
    else
        # stdin is not a terminal (e.g., piped from curl)
        # Try to read from /dev/tty if available
        if [ -e /dev/tty ]; then
            read -p "$(echo -e "${YELLOW}  Update GA now? [Y/n]: ${NC}")" response < /dev/tty
        else
            # No way to get user input, default to yes
            response="y"
        fi
    fi
    
    case "$response" in
        [nN]|[nN][oO])
            print_info "Skipping GA update"
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

install_ga() {
    local action="${1:-install}"
    local force="${2:-false}"
    
    case "$action" in
        install)
            print_info "Installing GA..."
            
            if [[ -d "$GA_DIR" ]]; then
                print_warning "GA directory already exists"
                
                # Check for updates
                if check_ga_updates "$GA_DIR"; then
                    local should_update=false
                    
                    if [[ "$force" == "true" ]]; then
                        # Force mode: update without asking
                        should_update=true
                    else
                        # Interactive mode: ask user
                        if prompt_ga_update "$GA_DIR"; then
                            should_update=true
                        fi
                    fi
                    
                    if [[ "$should_update" == "true" ]]; then
                        print_info "Pulling latest changes..."
                        # Safely handle local changes: stash if needed, ff-only update, then pop
                        local _ga_update_ok=false
                        (
                            cd "$GA_DIR"
                            git fetch origin -q 2>/dev/null

                            # Stash local changes if any exist
                            local _stash_created=false
                            if [[ -n "$(git status --porcelain)" ]]; then
                                git stash push -m "Auto-stash before GA update" --include-untracked -q && _stash_created=true
                            fi

                            # Fast-forward merge
                            if git merge --ff-only origin/main 2>/dev/null || git merge --ff-only origin/master 2>/dev/null; then
                                # Restore stash if we created one
                                if [[ "$_stash_created" == "true" ]]; then
                                    git stash pop -q || true
                                fi
                                exit 0
                            else
                                # Merge failed, restore stash
                                if [[ "$_stash_created" == "true" ]]; then
                                    git stash pop -q 2>/dev/null || true
                                fi
                                exit 1
                            fi
                        ) && _ga_update_ok=true

                        if [[ "$_ga_update_ok" == "true" ]]; then
                            # Update npm dependencies if package.json exists
                            if [ -f "$GA_DIR/package.json" ]; then
                                (cd "$GA_DIR" && npm install >/dev/null 2>&1)
                            fi
                            
                            new_version=$(get_version "$GA_DIR/package.json")
                            print_success "GA updated to version ${new_version:-latest}"
                        else
                            print_warning "Could not update GA automatically, you may need to update manually"
                        fi
                    else
                        print_info "Continuing with current version"
                    fi
                else
                    print_success "GA is already up to date"
                fi
            else
                print_info "Cloning GA repository..."
                mkdir -p "$(dirname "$GA_DIR")"
                git clone "$GA_REPO" "$GA_DIR" 2>/dev/null || {
                    print_error "Failed to clone GA repository"
                    return 1
                }
                
                version=$(get_version "$GA_DIR/package.json")
                [ -n "$version" ] && print_success "GA version $version cloned"
            fi
            
            print_info "Installing GA system-wide..."
            if (cd "$GA_DIR" && bash install.sh >/dev/null 2>&1); then
                print_success "GA installed successfully"
                return 0
            else
                print_warning "GA installation completed with warnings"
                return 0
            fi
            ;;
            
        update)
            if [[ ! -d "$GA_DIR" ]]; then
                print_error "GA not installed. Use 'install' action first."
                return 1
            fi
            
            print_info "Checking for updates..."
            if check_ga_updates "$GA_DIR"; then
                current_version=$(get_version "$GA_DIR/package.json")
                [ -n "$current_version" ] && print_info "Current version: $current_version"
                
                print_info "Updating GA..."
                # Safely handle local changes: stash if needed, ff-only update, then pop
                local _ga_update_ok=false
                (
                    cd "$GA_DIR"
                    git fetch origin -q 2>/dev/null

                    # Stash local changes if any exist
                    local _stash_created=false
                    if [[ -n "$(git status --porcelain)" ]]; then
                        git stash push -m "Auto-stash before GA update" --include-untracked -q && _stash_created=true
                    fi

                    # Fast-forward merge
                    if git merge --ff-only origin/main 2>/dev/null || git merge --ff-only origin/master 2>/dev/null; then
                        # Restore stash if we created one
                        if [[ "$_stash_created" == "true" ]]; then
                            git stash pop -q || true
                        fi
                        exit 0
                    else
                        # Merge failed, restore stash
                        if [[ "$_stash_created" == "true" ]]; then
                            git stash pop -q 2>/dev/null || true
                        fi
                        exit 1
                    fi
                ) && _ga_update_ok=true

                if [[ "$_ga_update_ok" == "true" ]]; then
                    # Update npm dependencies
                    if [ -f "$GA_DIR/package.json" ]; then
                        (cd "$GA_DIR" && npm install >/dev/null 2>&1)
                    fi
                    
                    new_version=$(get_version "$GA_DIR/package.json")
                    
                    print_info "Reinstalling GA..."
                    if (cd "$GA_DIR" && bash install.sh >/dev/null 2>&1); then
                        print_success "GA updated to version ${new_version:-latest}"
                        return 0
                    else
                        print_error "Failed to update GA"
                        return 1
                    fi
                else
                    print_warning "Could not update GA automatically, you may need to update manually"
                    return 1
                fi
            else
                print_success "GA is already up to date"
                return 0
            fi
            ;;
            
        skip)
            print_info "Skipping GA installation"
            return 0
            ;;
            
        *)
            print_error "Unknown action: $action"
            return 1
            ;;
    esac
}

install_sdd() {
    local action="${1:-install}"
    local target_dir="${2:-.}"
    
    # Resolve source directory (local repo or GA install)
    local auto_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local repo_root="$(cd "$auto_lib_dir/../.." && pwd)"
    local source_dir="$repo_root/skills"
    
    # Fallback to GA install dir if local source not available
    if [[ ! -d "$source_dir" ]]; then
        source_dir="$GA_DIR/skills"
    fi
    
    case "$action" in
        install)
            print_info "Installing SDD Orchestrator..."
            
            # Copy sdd-* skills to the project's skills/ directory
            local skills_target="$target_dir/skills"
            mkdir -p "$skills_target"
            
            local copied=0
            for skill_dir in "$source_dir"/sdd-*; do
                if [[ -d "$skill_dir" ]]; then
                    local skill_name
                    skill_name=$(basename "$skill_dir")
                    # Skip if source and target are the same
                    if [[ "$skill_dir" -ef "$skills_target/$skill_name" ]]; then
                        ((copied++)) || true
                        continue
                    fi
                    cp -r "$skill_dir" "$skills_target/$skill_name"
                    ((copied++)) || true
                fi
            done
            
            if [[ $copied -gt 0 ]]; then
                print_success "Copied $copied SDD skills to skills/"
            else
                print_warning "No SDD skills found in $source_dir"
            fi
            
            # Copy setup.sh if present
            if [[ -f "$source_dir/setup.sh" ]] && [[ ! "$source_dir/setup.sh" -ef "$skills_target/setup.sh" ]]; then
                cp "$source_dir/setup.sh" "$skills_target/setup.sh"
                chmod +x "$skills_target/setup.sh"
                print_success "Copied skills/setup.sh"
            fi
            
            print_success "SDD Orchestrator installed successfully"
            return 0
            ;;
            
        update)
            print_info "Updating SDD Orchestrator..."
            # Re-install to get latest skills
            install_sdd "install" "$target_dir"
            return $?
            ;;
            
        skip)
            print_info "Skipping SDD Orchestrator installation"
            return 0
            ;;
            
        *)
            print_error "Unknown action: $action"
            return 1
            ;;
    esac
}

install_vscode_extensions() {
    local action="${1:-install}"
    
    if ! command -v code &> /dev/null; then
        print_warning "VS Code CLI not available, skipping extensions"
        return 0
    fi
    
    local extensions=("github.copilot" "github.copilot-chat")
    
    case "$action" in
        install)
            print_info "Installing VS Code extensions..."
            
            for ext in "${extensions[@]}"; do
                print_info "Installing $ext..."
                if code --install-extension "$ext" --force >/dev/null 2>&1; then
                    print_success "$ext installed"
                else
                    print_warning "Could not install $ext"
                fi
            done
            
            return 0
            ;;
            
        skip)
            print_info "Skipping VS Code extensions"
            return 0
            ;;
            
        *)
            print_error "Unknown action: $action"
            return 1
            ;;
    esac
}

# ============================================================================
# Project Type Configuration
# ============================================================================

apply_project_type() {
    local project_type="${1:-nest}"
    local target_dir="${2:-.}"

    local auto_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local types_dir="$auto_lib_dir/../types"

    # Fallback to GA install dir
    if [[ ! -d "$types_dir" ]]; then
        types_dir="$GA_DIR/auto/types"
    fi

    local type_dir="$types_dir/$project_type"

    # Validate type exists
    if [[ ! -d "$type_dir" ]]; then
        print_warning "Unknown project type '$project_type'. Available types:"
        for d in "$types_dir"/*/; do
            [[ -d "$d" ]] && echo "    - $(basename "$d")"
        done
        print_warning "Falling back to 'generic' type."
        type_dir="$types_dir/generic"
        [[ ! -d "$type_dir" ]] && return 1
    fi

    print_info "Applying project type: $project_type"

    # Copy AGENTS.md
    if [[ -f "$type_dir/AGENTS.md" ]]; then
        local agents_target="$target_dir/AGENTS.md"
        if [[ ! -f "$agents_target" ]] || [[ "$1" == "--force" ]]; then
            cp "$type_dir/AGENTS.md" "$agents_target"
            print_success "Copied AGENTS.md ($project_type)"
        else
            print_warning "AGENTS.md already exists, skipping (use --force to overwrite)"
        fi
    fi

    # Copy REVIEW.md
    if [[ -f "$type_dir/REVIEW.md" ]]; then
        local review_target="$target_dir/REVIEW.md"
        if [[ ! -f "$review_target" ]] || [[ "$1" == "--force" ]]; then
            cp "$type_dir/REVIEW.md" "$review_target"
            print_success "Copied REVIEW.md ($project_type)"
        else
            print_warning "REVIEW.md already exists, skipping (use --force to overwrite)"
        fi
    fi

    # Copy skills listed in types.json from the main skills/ directory
    local types_json="$types_dir/types.json"
    local main_skills_dir="$auto_lib_dir/../../skills"
    # Fallback to GA install dir
    if [[ ! -d "$main_skills_dir" ]]; then
        main_skills_dir="$GA_DIR/skills"
    fi

    if [[ -f "$types_json" ]] && command -v python3 &>/dev/null; then
        local type_skills
        type_skills=$(python3 -c "
import json
try:
    data = json.load(open('$types_json'))
    skills = data.get('types', {}).get('$project_type', {}).get('skills', [])
    print(' '.join(skills))
except: pass
" 2>/dev/null)
        local skills_target="$target_dir/skills"
        mkdir -p "$skills_target"
        local copied_skills=0
        for skill in $type_skills; do
            local skill_source="$main_skills_dir/$skill"
            if [[ -d "$skill_source" ]]; then
                if [[ ! -d "$skills_target/$skill" ]]; then
                    cp -r "$skill_source" "$skills_target/$skill"
                    ((copied_skills++)) || true
                fi
            fi
        done
        [[ $copied_skills -gt 0 ]] && print_success "Copied $copied_skills type skills (${type_skills// /, })"
    fi

    print_success "Project type '$project_type' applied"
}

list_project_types() {
    local auto_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local types_dir="$auto_lib_dir/../types"
    local types_json="$types_dir/types.json"

    echo "Available project types:"
    if [[ -f "$types_json" ]] && command -v python3 &>/dev/null; then
        python3 -c "
import json
data = json.load(open('$types_json'))
for name, cfg in data.get('types', {}).items():
    print(f'  {name:<12} - {cfg.get(\"description\", \"\")}')
print(f'\n  default: {data.get(\"default\", \"nest\")}')
"
    else
        for d in "$types_dir"/*/; do
            [[ -d "$d" ]] && echo "  - $(basename "$d")"
        done
    fi
}

configure_project() {
    local provider="$1"
    local target_dir="$2"
    local skip_ga="${3:-false}"
    local install_biome="${4:-false}"
    local project_type="${5:-}"

    print_info "Configuring project at $target_dir..."
    
    # Source files from GA installation, preferring local source if running from repo
    local auto_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local ga_repo_root="$(cd "$auto_lib_dir/../.." && pwd)"
    local ga_install_dir="$GA_DIR"
    
    # Use local repo source if available and contains the files
    if [[ -f "$ga_repo_root/auto/AGENTS.MD" ]]; then
        ga_install_dir="$ga_repo_root"
    fi

    local auto_dir="$ga_install_dir/auto"
    
    # Apply project-type specific AGENTS.md and REVIEW.md
    if [[ -n "$project_type" ]]; then
        apply_project_type "$project_type" "$target_dir"
    else
        # Fall back to nest type
        apply_project_type "nest" "$target_dir"
    fi
    
    # Copy skills directory
    local skills_source="$ga_install_dir/skills"
    local skills_target="$target_dir/skills"
    
    # Skip if source and target are the same
    if [[ "$skills_source" -ef "$skills_target" ]]; then
        print_info "skills/ directory already in place"
    elif [[ -d "$skills_source" ]]; then
        if [[ -d "$skills_target" ]]; then
            print_warning "skills/ directory already exists in target, skipping copy"
        else
            cp -r "$skills_source" "$skills_target"
            print_success "Copied skills/ directory"
        fi
    else
        print_warning "skills/ directory not found in GA installation"
    fi

    # Copy .github/prompts directory
    local prompts_source="$ga_install_dir/.github/prompts"
    local prompts_target="$target_dir/.github/prompts"
    
    # Skip if source and target are the same
    if [[ "$prompts_source" -ef "$prompts_target" ]]; then
        print_info ".github/prompts directory already in place"
    elif [[ -d "$prompts_source" ]]; then
        if [[ -d "$prompts_target" ]]; then
            print_warning ".github/prompts directory already exists in target, skipping copy"
        else
            mkdir -p "$(dirname "$prompts_target")"
            cp -r "$prompts_source" "$prompts_target"
            print_success "Copied .github/prompts directory"
        fi
    else
        print_warning ".github/prompts directory not found in GA installation"
    fi

    # Configure AI skills for Copilot and OpenCode
    local skills_setup="$skills_target/setup.sh"
    if [[ -f "$skills_setup" ]]; then
        print_info "Configuring AI skills (Copilot + OpenCode)..."
        if (cd "$target_dir" && bash "$skills_setup" --copilot --opencode >/dev/null 2>&1); then
            print_success "AI skills configured for Copilot and OpenCode"
        else
            print_warning "AI skills setup had issues"
        fi
    else
        print_warning "skills/setup.sh not found, skipping AI skills setup"
    fi
    
    # Update .gitignore - only add missing patterns
    local gitignore_target="$target_dir/.gitignore"
    
    # Essential patterns that should be in every .gitignore
    local essential_patterns=(
        "# Dependencies"
        "node_modules/"
        ""
        "# Environment"
        ".env"
        ".env.local"
        ".env.*.local"
        ""
        "# AI Assistants"
        "CLAUDE.md"
        "CURSOR.md"
        "GEMINI.md"
        ".cursorrules"
        ".ga"
        ".gga"
        ""
        "# OpenCode"
        ".opencode/plugins/**/node_modules/"
        ".opencode/plugins/**/dist/"
        ".opencode/**/cache/"
        ""
        "# System"
        ".DS_Store"
        "Thumbs.db"
        ""
        "# Logs"
        "*.log"
        "logs/"
        ""
        "# IDE"
        ".idea/"
        "*.iml"
        ".vscode/"
    )
    
    # Create .gitignore if doesn't exist
    if [[ ! -f "$gitignore_target" ]]; then
        print_info "Creating .gitignore..."
        touch "$gitignore_target"
    fi
    
    # Add only missing patterns
    local added_count=0
    for pattern in "${essential_patterns[@]}"; do
        # Skip empty lines (they are section separators)
        if [[ -z "$pattern" ]]; then
            # Only add blank line if last line wasn't blank
            if [[ -s "$gitignore_target" ]]; then
                local last_line
                last_line=$(tail -1 "$gitignore_target")
                if [[ -n "$last_line" ]]; then
                    echo "" >> "$gitignore_target"
                fi
            fi
            continue
        fi
        
        # Check if pattern already exists - grep returns 1 if not found, so we need || true
        local pattern_exists=false
        grep -qF "$pattern" "$gitignore_target" 2>/dev/null && pattern_exists=true || true
        
        if [[ "$pattern_exists" == false ]]; then
            echo "$pattern" >> "$gitignore_target"
            ((added_count++)) || true
        fi
    done
    
    if [[ $added_count -gt 0 ]]; then
        print_success "Added $added_count patterns to .gitignore"
    else
        print_info ".gitignore already up to date"
    fi
    

    
    # Initialize GA in the target repository (creates .ga config only)
    if [[ "$skip_ga" != "true" ]]; then
        if command -v ga &> /dev/null; then
            print_info "Initializing GA in repository..."
            if (cd "$target_dir" && ga init >/dev/null 2>&1); then
                print_success "GA initialized"
                
                # Apply template if available
                local ga_config="$target_dir/.ga"
                local ga_template="$ga_install_dir/.ga.opencode-template"
                
                if [[ -f "$ga_template" && -f "$ga_config" ]]; then
                    cp "$ga_template" "$ga_config"
                    print_success "Applied OpenCode template to .ga"
                fi
                
                # Set provider if specified
                if [[ -n "$provider" && "$provider" != "opencode" ]]; then
                    if [[ -f "$ga_config" ]]; then
                        sed -i.bak "s|PROVIDER=\"opencode:github-copilot/claude-haiku-4.5\"|PROVIDER=\"$provider\"|" "$ga_config"
                        rm -f "$ga_config.bak"
                        print_success "Provider set to: $provider"
                    fi
                fi
                
                print_info "Installing GA hooks..."
                if (cd "$target_dir" && ga install >/dev/null 2>&1); then
                    print_success "GA hooks installed"
                else
                    print_warning "GA hook installation had issues"
                fi
            else
                print_warning "Failed to initialize GA"
            fi
        else
            print_warning "GA command not available, skipping initialization"
        fi
    fi
    
    # Setup Lefthook if available
    if command -v lefthook &> /dev/null; then
        local lefthook_config="$target_dir/lefthook.yml"
        if [[ ! -f "$lefthook_config" ]]; then
            local effective_type="${project_type:-nest}"
            local type_lefthook_template="$auto_dir/types/$effective_type/lefthook.yml"
            local lefthook_template="$auto_dir/lefthook.yml.template"
            if [[ -f "$type_lefthook_template" ]]; then
                lefthook_template="$type_lefthook_template"
            fi
            if [[ -f "$lefthook_template" ]]; then
                cp "$lefthook_template" "$lefthook_config"
                print_success "Created lefthook.yml ($effective_type)"
                
                print_info "Installing Lefthook hooks..."
                if (cd "$target_dir" && lefthook install >/dev/null 2>&1); then
                    print_success "Lefthook hooks installed"
                else
                    print_warning "Lefthook installation had issues"
                fi
            else
                print_warning "Lefthook template not found"
            fi
        else
            print_info "lefthook.yml already exists"
        fi
    else
        print_info "Lefthook not installed, skipping hook configuration"
    fi

    local auto_biome_for_type="false"
    if [[ "$project_type" == "nest" ]]; then
        auto_biome_for_type="true"
        if [[ "$install_biome" != "true" ]]; then
            print_info "Auto-enabling Biome baseline for project type: nest"
        fi
    fi

    if [[ "$install_biome" == "true" ]] || [[ "$auto_biome_for_type" == "true" ]]; then
        configure_biome_baseline "$target_dir"
    fi
    
    # Create VS Code settings (minimal configuration)
    local vscode_dir="$target_dir/.vscode"
    mkdir -p "$vscode_dir"
    
    local settings_file="$vscode_dir/settings.json"
    if [[ ! -f "$settings_file" ]]; then
        cat > "$settings_file" << 'EOF'
{
    "github.copilot.chat.useAgentsMdFile": true
}
EOF
        print_success "Created VS Code settings"
    fi
    
    print_success "Project configured successfully"
    return 0
}

configure_biome_baseline() {
        local target_dir="$1"
        local biome_config="$target_dir/biome.json"
        local package_json="$target_dir/package.json"

        print_info "Configuring optional Biome baseline..."

        if [[ -f "$biome_config" ]]; then
                print_info "biome.json already exists, skipping baseline config file"
        else
                cat > "$biome_config" << 'EOF'
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
EOF
                print_success "Created biome.json baseline"
        fi

        if [[ ! -f "$package_json" ]]; then
                print_warning "package.json not found, skipping Biome package/scripts setup"
                return 0
        fi

        if grep -q '"@biomejs/biome"' "$package_json" 2>/dev/null; then
                print_info "@biomejs/biome already present in package.json"
        else
                print_info "Installing @biomejs/biome..."
                if (cd "$target_dir" && npm install --save-dev @biomejs/biome >/dev/null 2>&1); then
                        print_success "Installed @biomejs/biome"
                else
                        print_warning "Failed to install @biomejs/biome automatically"
                fi
        fi

        if command -v node >/dev/null 2>&1; then
                if (cd "$target_dir" && node <<'EOF'
const fs = require('fs');
const path = require('path');

const packagePath = path.resolve('package.json');
if (!fs.existsSync(packagePath)) {
    process.exit(0);
}

const pkg = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
pkg.scripts = pkg.scripts || {};

const desiredScripts = {
    lint: 'biome check .',
    'lint:fix': 'biome check --write .',
    format: 'biome format --write .',
    'format:check': 'biome format .'
};

let changed = false;
for (const [name, command] of Object.entries(desiredScripts)) {
    if (!pkg.scripts[name]) {
        pkg.scripts[name] = command;
        changed = true;
    }
}

if (changed) {
    fs.writeFileSync(packagePath, JSON.stringify(pkg, null, 2) + '\n');
}
EOF
                ); then
                        print_success "Applied Biome scripts (without overriding existing scripts)"
                else
                        print_warning "Failed to update package.json scripts for Biome"
                fi
        fi

        return 0
}

install_biome() {
    local action="${1:-install}"
    local target_dir="${2:-.}"

    case "$action" in
        install)
            configure_biome_baseline "$target_dir"
            return $?
            ;;

        skip)
            print_info "Skipping Biome baseline installation"
            return 0
            ;;

        *)
            print_error "Unknown action: $action"
            return 1
            ;;
    esac
}

# Install OpenCode command hooks plugin
install_hooks() {
    local action="${1:-install}"
    local target_dir="${2:-.}"
    
    case "$action" in
        install)
            print_info "Installing OpenCode command hooks..."

            local abs_target
            abs_target="$(cd "$target_dir" && pwd)"
            local opencode_dir="$abs_target/.opencode"
            local plugins_dir="$opencode_dir/plugins"
            local plugin_file="$plugins_dir/command-hooks.js"
            # Determine source directory (prefer local source if running from repo/temp)
            local repo_root="$(cd "$BOOTSTRAP_DIR/.." && pwd)"
            local local_source="$repo_root/hooks/opencodehooks"
            local installed_source="$GA_DIR/hooks/opencodehooks"
            local hooks_source=""

            if [[ -d "$local_source" ]]; then
                hooks_source="$local_source"
            elif [[ -d "$installed_source" ]]; then
                hooks_source="$installed_source"
            else
                print_error "Hooks plugin source not found."
                print_info "Checked: $local_source"
                print_info "Checked: $installed_source"
                return 1
            fi

            print_info "Using hooks source: $hooks_source"

            # Check for bun (required by OpenCode for bundling)
            if ! command -v bun &>/dev/null; then
                print_error "Bun is required to build hooks plugin (OpenCode uses Bun internally)"
                print_info "Install Bun: curl -fsSL https://bun.sh/install | bash"
                return 1
            fi

            # Create plugins directory
            mkdir -p "$plugins_dir"

            # Remove old directory-based plugin if it exists (legacy format)
            local old_hooks_dir="$plugins_dir/opencode-command-hooks"
            if [[ -d "$old_hooks_dir" ]]; then
                print_info "Removing legacy plugin directory..."
                rm -rf "$old_hooks_dir"
            fi

            # Build and bundle the plugin into a single file
            # OpenCode local plugins are single .js/.ts files in .opencode/plugins/
            # We use bun build to bundle all source + deps into one file
            local build_dir
            build_dir="$(mktemp -d)"

            # Copy source files to temp build dir
            cp "$hooks_source/package.json" "$build_dir/"
            cp "$hooks_source/tsconfig.json" "$build_dir/" 2>/dev/null || true
            if [[ -d "$hooks_source/src" ]]; then
                cp -r "$hooks_source/src" "$build_dir/"
            fi

            print_info "Installing dependencies..."
            (cd "$build_dir" && bun install --frozen-lockfile 2>/dev/null || bun install) >/dev/null 2>&1
            print_success "Dependencies installed"

            print_info "Bundling plugin..."
            if (cd "$build_dir" && bun build src/index.ts \
                --target=bun \
                --outfile="$plugin_file" \
                --external @opencode-ai/plugin \
                --external @opencode-ai/sdk) >/dev/null 2>&1; then
                print_success "Plugin bundled to $plugin_file"
            else
                print_error "Plugin bundle failed"
                rm -rf "$build_dir"
                return 1
            fi

            # Clean up temp build dir
            rm -rf "$build_dir"

            # Remove stale opencode.json plugin references from previous installs
            # Local plugins in .opencode/plugins/ auto-load; no opencode.json entry needed
            local opencode_json="$opencode_dir/opencode.json"
            if [[ -f "$opencode_json" ]] && grep -q "file:.*opencode-command-hooks" "$opencode_json" 2>/dev/null; then
                print_info "Removing legacy file: plugin reference from opencode.json..."
                node -e "
                    const fs = require('fs');
                    const p = '$opencode_json';
                    const cfg = JSON.parse(fs.readFileSync(p, 'utf8'));
                    if (Array.isArray(cfg.plugin)) {
                        cfg.plugin = cfg.plugin.filter(p => !p.includes('opencode-command-hooks'));
                        if (cfg.plugin.length === 0) delete cfg.plugin;
                    }
                    fs.writeFileSync(p, JSON.stringify(cfg, null, 2) + '\n');
                " 2>/dev/null && print_success "Cleaned up opencode.json" || true
            fi

            # Also clean stale OpenCode-managed state that may cache the broken reference
            rm -f "$opencode_dir/bun.lock" 2>/dev/null
            if [[ -f "$opencode_dir/package.json" ]] && grep -q "opencode-command-hooks" "$opencode_dir/package.json" 2>/dev/null; then
                rm -f "$opencode_dir/package.json" 2>/dev/null
                rm -rf "$opencode_dir/node_modules" 2>/dev/null
                print_info "Cleared stale OpenCode package cache"
            fi

            # Create default command-hooks.jsonc if it doesn't exist
            local hooks_config="$opencode_dir/command-hooks.jsonc"
            if [[ ! -f "$hooks_config" ]]; then
                cat > "$hooks_config" << 'HOOKS_CONFIG'
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
HOOKS_CONFIG
                print_success "Created default command-hooks.jsonc"
            else
                print_info "command-hooks.jsonc already exists"
            fi
            
            # Create Engineer agent with hooks
            local agent_dir="$opencode_dir/agent"
            mkdir -p "$agent_dir"
            
            local agent_source="$hooks_source/agents/engineer.md"
            local agent_target="$agent_dir/engineer.md"
            
            if [[ -f "$agent_source" ]]; then
                if [[ ! -f "$agent_target" ]]; then
                    cp "$agent_source" "$agent_target"
                    print_success "Created Engineer agent with validation hooks"
                else
                    print_info "Engineer agent already exists"
                fi
            else
                # Create default Engineer agent if source not found
                if [[ ! -f "$agent_target" ]]; then
                    cat > "$agent_target" << 'ENGINEER_AGENT'
---
description: Senior Software Engineer - Writes clean, tested, and maintainable code
mode: subagent
hooks:
  after:
    - run: ["npm run lint"]
      inject: "Lint Results (exit {exitCode}):\n```\n{stdout}\n{stderr}\n```"
      toast:
        title: "Lint Check"
        message: "Lint finished with exit code {exitCode}"
        variant: "info"
    - run: ["npm run typecheck"]
      inject: "Type Check Results (exit {exitCode}):\n```\n{stdout}\n{stderr}\n```"
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
ENGINEER_AGENT
                    print_success "Created Engineer agent with validation hooks"
                else
                    print_info "Engineer agent already exists"
                fi
            fi
            
            print_success "OpenCode command hooks installed successfully"
            return 0
            ;;
            
        skip)
            print_info "Skipping hooks installation"
            return 0
            ;;
            
        *)
            print_error "Unknown action: $action"
            return 1
            ;;
    esac
}

update_all_components() {
    local target_dir="${1:-.}"
    local updated=0
    local failed=0
    
    print_info "Checking for updates..."
    
    source "$SCRIPT_DIR/detector.sh"
    
    local ga_info=$(detect_ga)
    IFS='|' read -r ga_status ga_current ga_latest <<< "$ga_info"
    
    if [[ "$ga_status" == "OUTDATED" ]]; then
        if install_ga "update"; then
            ((updated++))
        else
            ((failed++))
        fi
    elif [[ "$ga_status" == "UP_TO_DATE" ]]; then
        print_info "GA is up to date ($ga_current)"
    fi
    
    local sdd_info=$(detect_sdd "$target_dir")
    IFS='|' read -r sdd_status sdd_current sdd_total <<< "$sdd_info"
    
    if [[ "$sdd_status" == "NOT_INSTALLED" ]] || [[ "$sdd_status" == "PARTIAL" ]]; then
        if install_sdd "update" "$target_dir"; then
            ((updated++))
        else
            ((failed++))
        fi
    elif [[ "$sdd_status" == "INSTALLED" ]]; then
        print_info "SDD Orchestrator is up to date ($sdd_current skills)"
    fi
    
    if [[ $updated -gt 0 ]]; then
        print_success "Updated $updated component(s)"
    fi
    
    if [[ $failed -gt 0 ]]; then
        print_warning "Failed to update $failed component(s)"
        return 1
    fi
    
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-help}" in
        install-ga)
            install_ga "install"
            ;;
        install-sdd)
            install_sdd "install" "${2:-.}"
            ;;
        install-vscode)
            install_vscode_extensions "install"
            ;;
        install-biome)
            install_biome "install" "${2:-.}"
            ;;
        configure)
            configure_project "${2:-opencode}" "${3:-.}" "${4:-false}" "${5:-false}"
            ;;
        update-all)
            update_all_components "${2:-.}"
            ;;
        *)
            echo "Usage: $0 {install-ga|install-sdd|install-vscode|install-biome|configure|update-all}"
            exit 1
            ;;
    esac
fi
