#!/bin/bash
# Installation Module for GGA Components

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GGA_REPO="https://github.com/Yoizen/gga-copilot.git"
GGA_DIR="$HOME/.local/share/yoizen/gga-copilot"

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

# Check if GGA updates are available
check_gga_updates() {
    local gga_path="$1"
    
    if [ ! -d "$gga_path/.git" ]; then
        return 1
    fi
    
    # Fetch latest from origin quietly
    (cd "$gga_path" && git fetch origin -q 2>/dev/null) || return 1
    
    # Check if we're behind origin
    local behind=$(cd "$gga_path" && git rev-list HEAD..origin/main --count 2>/dev/null || git rev-list HEAD..origin/master --count 2>/dev/null)
    
    if [ -n "$behind" ] && [ "$behind" -gt 0 ]; then
        return 0  # Updates available
    fi
    
    return 1  # No updates
}

# Prompt user for update
prompt_gga_update() {
    local gga_path="$1"
    local current_version=$(get_version "$gga_path/package.json")
    
    echo ""
    print_info "GGA update available!"
    [ -n "$current_version" ] && echo -e "  Current version: $current_version"
    echo ""
    
    # Use /dev/tty to read from terminal even when stdin is redirected
    if [ -t 0 ]; then
        # stdin is a terminal
        read -p "$(echo -e "${YELLOW}  Update GGA now? [Y/n]: ${NC}")" response
    else
        # stdin is not a terminal (e.g., piped from curl)
        # Try to read from /dev/tty if available
        if [ -e /dev/tty ]; then
            read -p "$(echo -e "${YELLOW}  Update GGA now? [Y/n]: ${NC}")" response < /dev/tty
        else
            # No way to get user input, default to yes
            response="y"
        fi
    fi
    
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

install_gga() {
    local action="${1:-install}"
    local force="${2:-false}"
    
    case "$action" in
        install)
            print_info "Installing GGA..."
            
            if [[ -d "$GGA_DIR" ]]; then
                print_warning "GGA directory already exists"
                
                # Check for updates
                if check_gga_updates "$GGA_DIR"; then
                    local should_update=false
                    
                    if [[ "$force" == "true" ]]; then
                        # Force mode: update without asking
                        should_update=true
                    else
                        # Interactive mode: ask user
                        if prompt_gga_update "$GGA_DIR"; then
                            should_update=true
                        fi
                    fi
                    
                    if [[ "$should_update" == "true" ]]; then
                        print_info "Pulling latest changes..."
                        # Safely handle local changes: stash if needed, ff-only update, then pop
                        if (cd "$GGA_DIR" && \
                            git fetch origin -q 2>/dev/null && \
                            stash_created=false && \
                            [[ -n "$(git status --porcelain)" ]] && stash_created=true && \
                            ([[ "$stash_created" == "false" ]] || git stash push -m "Auto-stash before GGA update" --include-untracked -q) && \
                            (git merge --ff-only origin/main 2>/dev/null || git merge --ff-only origin/master 2>/dev/null) && \
                            ([[ "$stash_created" == "false" ]] || git stash pop -q)); then
                            # Update npm dependencies if package.json exists
                            if [ -f "$GGA_DIR/package.json" ]; then
                                (cd "$GGA_DIR" && npm install >/dev/null 2>&1)
                            fi
                            
                            new_version=$(get_version "$GGA_DIR/package.json")
                            print_success "GGA updated to version ${new_version:-latest}"
                        else
                            # Attempt to restore stash if update failed
                            (cd "$GGA_DIR" && git stash pop -q 2>/dev/null) || true
                            print_warning "Could not update GGA automatically, you may need to update manually"
                        fi
                    else
                        print_info "Continuing with current version"
                    fi
                else
                    print_success "GGA is already up to date"
                fi
            else
                print_info "Cloning GGA repository..."
                mkdir -p "$(dirname "$GGA_DIR")"
                git clone "$GGA_REPO" "$GGA_DIR" 2>/dev/null || {
                    print_error "Failed to clone GGA repository"
                    return 1
                }
                
                version=$(get_version "$GGA_DIR/package.json")
                [ -n "$version" ] && print_success "GGA version $version cloned"
            fi
            
            print_info "Installing GGA system-wide..."
            if (cd "$GGA_DIR" && bash install.sh >/dev/null 2>&1); then
                print_success "GGA installed successfully"
                return 0
            else
                print_warning "GGA installation completed with warnings"
                return 0
            fi
            ;;
            
        update)
            if [[ ! -d "$GGA_DIR" ]]; then
                print_error "GGA not installed. Use 'install' action first."
                return 1
            fi
            
            print_info "Checking for updates..."
            if check_gga_updates "$GGA_DIR"; then
                current_version=$(get_version "$GGA_DIR/package.json")
                [ -n "$current_version" ] && print_info "Current version: $current_version"
                
                print_info "Updating GGA..."
                # Safely handle local changes: stash if needed, ff-only update, then pop
                if (cd "$GGA_DIR" && \
                    git fetch origin -q 2>/dev/null && \
                    stash_created=false && \
                    [[ -n "$(git status --porcelain)" ]] && stash_created=true && \
                    ([[ "$stash_created" == "false" ]] || git stash push -m "Auto-stash before GGA update" --include-untracked -q) && \
                    (git merge --ff-only origin/main 2>/dev/null || git merge --ff-only origin/master 2>/dev/null) && \
                    ([[ "$stash_created" == "false" ]] || git stash pop -q)); then
                    # Update npm dependencies
                    if [ -f "$GGA_DIR/package.json" ]; then
                        (cd "$GGA_DIR" && npm install >/dev/null 2>&1)
                    fi
                    
                    new_version=$(get_version "$GGA_DIR/package.json")
                    
                    print_info "Reinstalling GGA..."
                    if (cd "$GGA_DIR" && bash install.sh >/dev/null 2>&1); then
                        print_success "GGA updated to version ${new_version:-latest}"
                        return 0
                    else
                        print_error "Failed to update GGA"
                        return 1
                    fi
                else
                    # Attempt to restore stash if update failed
                    (cd "$GGA_DIR" && git stash pop -q 2>/dev/null) || true
                    print_warning "Could not update GGA automatically, you may need to update manually"
                    return 1
                fi
            else
                print_success "GGA is already up to date"
                return 0
            fi
            ;;
            
        skip)
            print_info "Skipping GGA installation"
            return 0
            ;;
            
        *)
            print_error "Unknown action: $action"
            return 1
            ;;
    esac
}

install_openspec() {
    local action="${1:-install}"
    local target_dir="${2:-.}"
    
    case "$action" in
        install)
            print_info "Installing OpenSpec..."

            if command -v npm >/dev/null 2>&1; then
                print_info "Installing OpenSpec globally..."
                if npm install -g @fission-ai/openspec@latest >/dev/null 2>&1; then
                    print_success "OpenSpec global install completed"
                else
                    print_warning "Global OpenSpec install failed (continuing with local install)"
                fi
            else
                print_warning "npm not found; skipping global OpenSpec install"
            fi
            
            if [[ ! -f "$target_dir/package.json" ]]; then
                print_info "Initializing package.json..."
                (cd "$target_dir" && npm init -y >/dev/null 2>&1)
            fi
            
            print_info "Installing @fission-ai/openspec..."
            if (cd "$target_dir" && npm install @fission-ai/openspec --save-dev >/dev/null 2>&1); then
                print_success "OpenSpec installed successfully"
                
                mkdir -p "$target_dir/bin"
                local openspec_wrapper="$target_dir/bin/openspec"
                
                if [[ ! -f "$openspec_wrapper" ]]; then
                    cat > "$openspec_wrapper" << 'EOF'
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"
exec npm exec openspec -- "$@"
EOF
                    chmod +x "$openspec_wrapper"
                    print_success "Created openspec wrapper"
                fi
                
                print_info "Initializing OpenSpec structure..."
                if (cd "$target_dir" && npm exec openspec init -- --tools opencode,github-copilot >/dev/null 2>&1); then
                    print_success "OpenSpec initialized"
                else
                    print_warning "OpenSpec init had issues (may need manual configuration)"
                fi
                
                return 0
            else
                print_error "Failed to install OpenSpec"
                return 1
            fi
            ;;
            
        update)
            print_info "Updating OpenSpec..."
            if (cd "$target_dir" && npm update @fission-ai/openspec >/dev/null 2>&1); then
                print_success "OpenSpec updated successfully"
                return 0
            else
                print_error "Failed to update OpenSpec"
                return 1
            fi
            ;;
            
        skip)
            print_info "Skipping OpenSpec installation"
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

configure_project() {
    local provider="$1"
    local target_dir="$2"
    local skip_gga="${3:-false}"
    local install_biome="${4:-false}"
    
    print_info "Configuring project at $target_dir..."
    
    # Source files from GGA installation, not from current directory
    local gga_install_dir="$GGA_DIR"
    local auto_dir="$gga_install_dir/auto"
    
    # Only copy configuration files, NOT GGA code itself
    for file in "AGENTS.MD" "REVIEW.md"; do
        local source="$auto_dir/$file"
        local target="$target_dir/$file"
        
        # Skip if source and target are the same (we're in gga-copilot repo itself)
        if [[ "$source" -ef "$target" ]]; then
            print_info "$file already in place"
            continue
        fi
        
        if [[ -f "$source" ]]; then
            cp "$source" "$target"
            print_success "Copied $file"
        else
            print_warning "Source file $file not found"
        fi
    done
    
    # Copy skills directory
    local skills_source="$gga_install_dir/skills"
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
        print_warning "skills/ directory not found in GGA installation"
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
    
    # Update openspec/project.md if it exists
    if [[ -d "$target_dir/openspec" && -f "$auto_dir/AGENTS.MD" ]]; then
        local project_md="$target_dir/openspec/project.md"
        if [[ -f "$project_md" ]]; then
            cp "$auto_dir/AGENTS.MD" "$project_md"
            print_success "Updated openspec/project.md with AGENTS.MD"
        fi
    fi
    
    # Initialize GGA in the target repository (creates .gga config only)
    if [[ "$skip_gga" != "true" ]]; then
        if command -v gga &> /dev/null; then
            print_info "Initializing GGA in repository..."
            if (cd "$target_dir" && gga init >/dev/null 2>&1); then
                print_success "GGA initialized"
                
                # Apply template if available
                local gga_config="$target_dir/.gga"
                local gga_template="$gga_install_dir/.gga.opencode-template"
                
                if [[ -f "$gga_template" && -f "$gga_config" ]]; then
                    cp "$gga_template" "$gga_config"
                    print_success "Applied OpenCode template to .gga"
                fi
                
                # Set provider if specified
                if [[ -n "$provider" && "$provider" != "opencode" ]]; then
                    if [[ -f "$gga_config" ]]; then
                        sed -i.bak "s|PROVIDER=\"opencode:github-copilot/claude-haiku-4.5\"|PROVIDER=\"$provider\"|" "$gga_config"
                        rm -f "$gga_config.bak"
                        print_success "Provider set to: $provider"
                    fi
                fi
                
                print_info "Installing GGA hooks..."
                if (cd "$target_dir" && gga install >/dev/null 2>&1); then
                    print_success "GGA hooks installed"
                else
                    print_warning "GGA hook installation had issues"
                fi
            else
                print_warning "Failed to initialize GGA"
            fi
        else
            print_warning "GGA command not available, skipping initialization"
        fi
    fi
    
    # Setup Lefthook if available
    if command -v lefthook &> /dev/null; then
        local lefthook_config="$target_dir/lefthook.yml"
        if [[ ! -f "$lefthook_config" ]]; then
            local lefthook_template="$auto_dir/lefthook.yml.template"
            if [[ -f "$lefthook_template" ]]; then
                cp "$lefthook_template" "$lefthook_config"
                print_success "Created lefthook.yml"
                
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

    if [[ "$install_biome" == "true" ]]; then
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
    "formatter": {
        "enabled": true,
        "indentStyle": "space",
        "indentWidth": 2,
        "lineWidth": 100
    },
    "linter": {
        "enabled": true,
        "rules": {
            "recommended": true,
            "correctness": {
                "noUnusedImports": "error",
                "noUnusedVariables": "error",
                "useParseIntRadix": "warn"
            },
            "style": {
                "useConst": "error",
                "useImportType": "warn"
            },
            "suspicious": {
                "noDoubleEquals": "warn",
                "noGlobalIsNan": "error"
            }
        }
    },
    "organizeImports": {
        "enabled": true
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
            local installed_source="$GGA_DIR/hooks/opencodehooks"
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
    
    local gga_info=$(detect_gga)
    IFS='|' read -r gga_status gga_current gga_latest <<< "$gga_info"
    
    if [[ "$gga_status" == "OUTDATED" ]]; then
        if install_gga "update"; then
            ((updated++))
        else
            ((failed++))
        fi
    elif [[ "$gga_status" == "UP_TO_DATE" ]]; then
        print_info "GGA is up to date ($gga_current)"
    fi
    
    local openspec_info=$(detect_openspec)
    IFS='|' read -r openspec_status openspec_current openspec_latest <<< "$openspec_info"
    
    if [[ "$openspec_status" == "OUTDATED" ]]; then
        if install_openspec "update" "$target_dir"; then
            ((updated++))
        else
            ((failed++))
        fi
    elif [[ "$openspec_status" == "UP_TO_DATE" ]]; then
        print_info "OpenSpec is up to date ($openspec_current)"
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
        install-gga)
            install_gga "install"
            ;;
        install-openspec)
            install_openspec "install" "${2:-.}"
            ;;
        install-vscode)
            install_vscode_extensions "install"
            ;;
        configure)
            configure_project "${2:-opencode}" "${3:-.}" "${4:-false}" "${5:-false}"
            ;;
        update-all)
            update_all_components "${2:-.}"
            ;;
        *)
            echo "Usage: $0 {install-gga|install-openspec|install-vscode|configure|update-all}"
            exit 1
            ;;
    esac
fi
