#!/usr/bin/env bash
# Installation module: GA, SDD, VS Code, Biome, Hooks, project configuration

_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=ui.sh
source "$_LIB_DIR/ui.sh"
# shellcheck source=config.sh
source "$_LIB_DIR/config.sh"
# shellcheck source=detector.sh
source "$_LIB_DIR/detector.sh"

# ── GA ────────────────────────────────────────────────────────────────────────

# Pull latest commits from origin using ff-only; stashes local changes first.
# Returns 0 on success, 1 on failure.
_ga_pull() {
  local path="$1"
  local ok=false
  (
    cd "$path"
    git fetch origin -q 2>/dev/null

    local stashed=false
    if [[ -n "$(git status --porcelain)" ]]; then
      git stash push -m "Auto-stash before GA update" --include-untracked -q \
        && stashed=true
    fi

    if git merge --ff-only origin/main 2>/dev/null \
        || git merge --ff-only origin/master 2>/dev/null; then
      [[ "$stashed" == true ]] && git stash pop -q || true
      exit 0
    else
      [[ "$stashed" == true ]] && git stash pop -q 2>/dev/null || true
      exit 1
    fi
  ) && ok=true
  [[ "$ok" == true ]]
}

# Checkout a specific tag in an existing GA git clone.
# $1: path to GA_DIR  $2: tag (e.g. v1.2.0)
_ga_checkout_tag() {
  local path="$1" tag="$2"
  local ok=false
  (
    cd "$path"
    git fetch origin --tags -q 2>/dev/null
    local stashed=false
    if [[ -n "$(git status --porcelain)" ]]; then
      git stash push -m "Auto-stash before GA tag checkout" --include-untracked -q \
        && stashed=true
    fi
    if git checkout -q "$tag" 2>/dev/null; then
      [[ "$stashed" == true ]] && git stash pop -q || true
      exit 0
    else
      [[ "$stashed" == true ]] && git stash pop -q 2>/dev/null || true
      exit 1
    fi
  ) && ok=true
  [[ "$ok" == true ]]
}

# Clone the GA repo at a specific ref (tag or branch).
# $1: destination dir  $2: ref
_ga_clone_at_ref() {
  local dest="$1" ref="$2"
  mkdir -p "$(dirname "$dest")"
  git clone --depth 1 --branch "$ref" "$GA_REPO" "$dest" 2>/dev/null
}

# Resolve GA source dir inside the cloned repository.
# Supports both modern layout (ywai/ga) and legacy layout (repo root).
_ga_source_dir() {
  if [[ -d "$GA_DIR/ywai/ga/bin" && -d "$GA_DIR/ywai/ga/lib" ]]; then
    echo "$GA_DIR/ywai/ga"
    return 0
  fi

  if [[ -d "$GA_DIR/bin" && -d "$GA_DIR/lib" ]]; then
    echo "$GA_DIR"
    return 0
  fi

  return 1
}

_ga_package_json() {
  local source_dir
  source_dir="$(_ga_source_dir)" || return 1
  [[ -f "$source_dir/package.json" ]] || return 1
  echo "$source_dir/package.json"
}

_ga_version_from_ref() {
  local ref="${1:-}"
  case "$ref" in
    ""|stable|latest|main|master)
      return 1
      ;;
    v*)
      echo "${ref#v}"
      ;;
    *)
      echo "$ref"
      ;;
  esac
}

_ga_apply_installed_version_override() {
  local version="${1:-}"
  local pkg="$HOME/.local/share/ga/package.json"
  [[ -n "$version" && -f "$pkg" ]] || return 0

  local tmp
  tmp="$(mktemp)"
  sed -E "s/(\"version\"[[:space:]]*:[[:space:]]*\")[^\"]*(\")/\1${version}\2/" "$pkg" > "$tmp" \
    && mv "$tmp" "$pkg" || {
      rm -f "$tmp"
      return 1
    }
}

_ga_install_systemwide() {
  local ref="${1:-}"
  local version_override=""
  version_override="$(_ga_version_from_ref "$ref" 2>/dev/null || true)"

  # Legacy layout still ships an install.sh at repo root.
  if [[ -f "$GA_DIR/install.sh" ]]; then
    (cd "$GA_DIR" && bash install.sh >/dev/null 2>&1)
    local status=$?
    [[ $status -eq 0 ]] && _ga_apply_installed_version_override "$version_override"
    return $status
  fi

  local source_dir
  source_dir="$(_ga_source_dir)" || return 1

  mkdir -p "$HOME/.local/bin" "$HOME/.local/share/ga/lib"
  cp "$source_dir/bin/ga" "$HOME/.local/bin/ga" || return 1
  chmod +x "$HOME/.local/bin/ga" || return 1

  rm -rf "$HOME/.local/share/ga/lib"
  mkdir -p "$HOME/.local/share/ga/lib"
  cp -R "$source_dir/lib/." "$HOME/.local/share/ga/lib/" || return 1

  if [[ -f "$source_dir/package.json" ]]; then
    cp "$source_dir/package.json" "$HOME/.local/share/ga/package.json" || return 1
  fi

  _ga_apply_installed_version_override "$version_override" || return 1

  return 0
}

# After a successful pull, re-run npm install and ga install.
_ga_post_update() {
  local ref="${1:-}"
  local pkg_file=""
  pkg_file="$(_ga_package_json 2>/dev/null || true)"
  [[ -n "$pkg_file" ]] && (cd "$(dirname "$pkg_file")" && npm install >/dev/null 2>&1) || true

  local v=""
  [[ -n "$pkg_file" ]] && v=$(get_version "$pkg_file")
  local version_override=""
  version_override="$(_ga_version_from_ref "$ref" 2>/dev/null || true)"
  [[ -n "$version_override" ]] && v="$version_override"

  _ga_install_systemwide "$ref" \
    && print_success "GA updated to version ${v:-latest}" \
    || print_warning "GA installation completed with warnings"
}

# Install or update GA CLI.
# $1: action  — install (default) | update
# $2: force   — true skips interactive update prompt
install_ga() {
  local action="${1:-install}" force="${2:-false}"

  local ref; ref="$(ywai_resolve_ref)"
  local ref_desc; ref_desc="$(ywai_ref_description)"

  if [[ "$action" == "update" ]]; then
    if [[ ! -d "$GA_DIR" ]]; then
      print_error "GA not installed. Run install first."; return 1
    fi
    print_info "Checking for GA updates... (${ref_desc})"
    if ! ga_updates_available "$GA_DIR"; then
      print_success "GA is already up to date"; return 0
    fi
    print_info "Updating GA to ${ref}..."
    _ga_update_to_ref "$ref" && _ga_post_update "$ref" \
      || print_warning "Could not update GA automatically"
    return 0
  fi

  # action == install
  if [[ -d "$GA_DIR" ]]; then
    if ga_updates_available "$GA_DIR"; then
      local do_update=false
      if [[ "$force" == "true" ]]; then
        do_update=true
      elif ask_yes_no "  GA update available (${ref_desc}). Update now?" "y"; then
        do_update=true
      fi

      if [[ "$do_update" == true ]]; then
        print_info "Updating GA to ${ref}..."
        _ga_update_to_ref "$ref" && _ga_post_update "$ref" \
          || print_warning "Could not update GA automatically"
      else
        print_info "Continuing with current version"
      fi
    else
      print_success "GA is already up to date"
    fi
  else
    print_info "Cloning GA repository (${ref_desc})..."
    if ! _ga_clone_at_ref "$GA_DIR" "$ref"; then
      print_error "Failed to clone GA repository at ref '${ref}'"; return 1
    fi

    local pkg_file="" v=""
    pkg_file="$(_ga_package_json 2>/dev/null || true)"
    [[ -n "$pkg_file" ]] && v=$(get_version "$pkg_file")
    [[ -n "$v" ]] && print_success "GA $v cloned" || print_success "GA cloned (${ref})"
  fi

  print_info "Installing GA system-wide..."
  _ga_install_systemwide "$ref" \
    && print_success "GA installed successfully" \
    || print_warning "GA installation completed with warnings"
}

# Update an existing GA clone to a given ref (tag or branch).
_ga_update_to_ref() {
  local ref="$1"
  if [[ "$ref" == "$YWAI_FALLBACK_BRANCH" || "$ref" == main || "$ref" == master ]]; then
    _ga_pull "$GA_DIR"
  else
    _ga_checkout_tag "$GA_DIR" "$ref"
  fi
}

# ── SDD ───────────────────────────────────────────────────────────────────────

install_sdd() {
  local target_dir="${1:-.}"
  local repo_root; repo_root="$(cd "$_LIB_DIR/../.." && pwd)"
  local source_dir="$repo_root/skills"
  [[ -d "$source_dir" ]] || source_dir="$GA_DIR/skills"

  print_info "Installing SDD Orchestrator..."
  local skills_target="$target_dir/skills"
  mkdir -p "$skills_target"

  local found=0 copied=0 replaced=0 skipped_same_path=0
  for skill_dir in "$source_dir"/sdd-*; do
    [[ -d "$skill_dir" ]] || continue
    ((found++)) || true
    local skill_name; skill_name=$(basename "$skill_dir")
    local target_skill_dir="$skills_target/$skill_name"

    # Source and target are the same directory (e.g. running setup in this repo).
    if [[ "$skill_dir" -ef "$target_skill_dir" ]]; then
      ((skipped_same_path++)) || true
      continue
    fi

    # Replace existing target skill to avoid nested copies and keep updated content.
    if [[ -d "$target_skill_dir" ]]; then
      rm -rf "$target_skill_dir"
      ((replaced++)) || true
    fi

    cp -r "$skill_dir" "$target_skill_dir"

    # Normalize legacy-bug layout: skill-name/skill-name/SKILL.md
    if [[ -d "$target_skill_dir/$skill_name" ]]; then
      if [[ ! -f "$target_skill_dir/SKILL.md" && -f "$target_skill_dir/$skill_name/SKILL.md" ]]; then
        cp -R "$target_skill_dir/$skill_name/." "$target_skill_dir/"
      fi
      rm -rf "$target_skill_dir/$skill_name"
    fi

    ((copied++)) || true
  done

  if [[ $copied -gt 0 ]]; then
    if [[ $replaced -gt 0 ]]; then
      print_success "Synced $copied SDD skills to skills/ ($replaced replaced)"
    else
      print_success "Copied $copied SDD skills to skills/"
    fi
  elif [[ $found -gt 0 && $skipped_same_path -gt 0 ]]; then
    print_info "SDD skills already in place"
  else
    print_warning "No SDD skills found in $source_dir"
  fi

  if [[ -f "$source_dir/setup.sh" ]] \
      && [[ ! "$source_dir/setup.sh" -ef "$skills_target/setup.sh" ]]; then
    cp "$source_dir/setup.sh" "$skills_target/setup.sh"
    chmod +x "$skills_target/setup.sh"
    print_success "Copied skills/setup.sh"
  fi

  print_success "SDD Orchestrator installed"
}

# ── OpenCode CLI ──────────────────────────────────────────────────────────────

install_opencode() {
  if command_exists opencode; then
    print_info "OpenCode CLI already installed"; return 0
  fi

  if ! command_exists npm; then
    print_warning "npm not available, skipping OpenCode CLI install"; return 0
  fi

  print_info "Installing OpenCode CLI..."
  npm install -g opencode-ai >/dev/null 2>&1 \
    && print_success "OpenCode CLI installed" \
    || print_warning "Could not install OpenCode CLI"
}

# ── VS Code extensions ────────────────────────────────────────────────────────

install_vscode_extensions() {
  if ! command_exists code; then
    print_warning "VS Code CLI not available, skipping extensions"; return 0
  fi

  print_info "Installing VS Code extensions..."
  for ext in "github.copilot" "github.copilot-chat"; do
    if code --install-extension "$ext" --force >/dev/null 2>&1; then
      print_success "$ext installed"
    else
      print_warning "Could not install $ext"
    fi
  done
}

# ── Biome ─────────────────────────────────────────────────────────────────────

install_biome() {
  local target_dir="${1:-.}"
  local biome_config="$target_dir/biome.json"
  local package_json="$target_dir/package.json"

  print_info "Configuring Biome baseline..."

  if [[ ! -f "$biome_config" ]]; then
    _write_biome_json "$biome_config"
    print_success "Created biome.json baseline"
  else
    print_info "biome.json already exists, skipping"
  fi

  [[ -f "$package_json" ]] || { print_warning "package.json not found, skipping Biome package setup"; return 0; }

  if grep -q '"@biomejs/biome"' "$package_json" 2>/dev/null; then
    print_info "@biomejs/biome already present"
  else
    print_info "Installing @biomejs/biome..."
    (cd "$target_dir" && npm install --save-dev @biomejs/biome >/dev/null 2>&1) \
      && print_success "Installed @biomejs/biome" \
      || print_warning "Failed to install @biomejs/biome"
  fi

  if command_exists node; then
    (cd "$target_dir" && node -e "
      const fs=require('fs'),p='package.json';
      const pkg=JSON.parse(fs.readFileSync(p,'utf8'));
      pkg.scripts=pkg.scripts||{};
      const s={'lint':'biome check .','lint:fix':'biome check --write .','format':'biome format --write .','format:check':'biome format .'};
      let changed=false;
      for(const[k,v] of Object.entries(s)){if(!pkg.scripts[k]){pkg.scripts[k]=v;changed=true;}}
      if(changed)fs.writeFileSync(p,JSON.stringify(pkg,null,2)+'\n');
    " 2>/dev/null) \
      && print_success "Applied Biome scripts to package.json" \
      || print_warning "Failed to update package.json scripts"
  fi
}

# Write the canonical biome.json content
_write_biome_json() {
  cat > "$1" << 'EOF'
{
  "$schema": "https://biomejs.dev/schemas/2.3.2/schema.json",
  "files": {
    "ignoreUnknown": true,
    "includes": [
      "**",
      "!!**/node_modules", "!!**/dist", "!!**/build",
      "!!**/coverage", "!!**/.next", "!!**/.nuxt",
      "!!**/.svelte-kit", "!!**/.turbo", "!!**/.vercel",
      "!!**/.cache", "!!**/__generated__",
      "!!**/*.generated.*", "!!**/*.gen.*",
      "!!**/generated", "!!**/codegen"
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
        "noUnusedImports": { "fix": "safe", "level": "error" },
        "noUnusedVariables": "error",
        "noUnusedFunctionParameters": "error",
        "noUndeclaredVariables": "error",
        "useParseIntRadix": "warn",
        "useValidTypeof": "error",
        "noUnreachable": "error"
      },
      "style": {
        "useBlockStatements": { "fix": "safe", "level": "error" },
        "useConst": "error",
        "useImportType": "warn",
        "noNonNullAssertion": "error",
        "useTemplate": "warn"
      },
      "security": { "noGlobalEval": "error" },
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
            "functions": ["clsx","cva","tw","twMerge","cn","twJoin","tv"]
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
  "organizeImports": { "enabled": true },
  "vcs": {
    "enabled": true,
    "clientKind": "git",
    "useIgnoreFile": true,
    "defaultBranch": "main"
  }
}
EOF
}

# ── OpenCode Hooks ────────────────────────────────────────────────────────────

install_hooks() {
  local target_dir="${1:-.}"
  print_warning "'install_hooks' is deprecated; using extensions/hooks/opencode-command-hooks"
  install_extension "hooks" "opencode-command-hooks" "$target_dir"
}

_cleanup_stale_opencode_refs() {
  local opencode_dir="$1"
  local opencode_json="$opencode_dir/opencode.json"

  if [[ -f "$opencode_json" ]] && grep -q "file:.*opencode-command-hooks" "$opencode_json" 2>/dev/null; then
    node -e "
      const fs=require('fs'),p='$opencode_json';
      const cfg=JSON.parse(fs.readFileSync(p,'utf8'));
      if(Array.isArray(cfg.plugin)){
        cfg.plugin=cfg.plugin.filter(p=>!p.includes('opencode-command-hooks'));
        if(!cfg.plugin.length)delete cfg.plugin;
      }
      fs.writeFileSync(p,JSON.stringify(cfg,null,2)+'\n');
    " 2>/dev/null && print_info "Cleaned stale opencode.json reference" || true
  fi

  rm -f "$opencode_dir/bun.lock" 2>/dev/null
  if [[ -f "$opencode_dir/package.json" ]] \
      && grep -q "opencode-command-hooks" "$opencode_dir/package.json" 2>/dev/null; then
    rm -f "$opencode_dir/package.json"
    rm -rf "$opencode_dir/node_modules"
    print_info "Cleared stale OpenCode package cache"
  fi
}

_write_hooks_config() {
  local hooks_config="$1/command-hooks.jsonc"
  [[ -f "$hooks_config" ]] && { print_info "command-hooks.jsonc already exists"; return; }
  cat > "$hooks_config" << 'HOOKS_CONFIG'
{
  // OpenCode Command Hooks Configuration
  "truncationLimit": 30000,
  "tool": [
    {
      "id": "post-edit-lint",
      "when": { "phase": "after", "tool": ["edit", "write"] },
      "run": ["npm run lint --silent 2>&1 || true"],
      "inject": "Lint Results (exit {exitCode}):\n```\n{stdout}\n{stderr}\n```",
      "toast": { "title": "Lint Check", "message": "exit {exitCode}", "variant": "info" }
    },
    {
      "id": "post-edit-typecheck",
      "when": { "phase": "after", "tool": ["edit", "write"] },
      "run": ["npx tsc --noEmit 2>&1 || true"],
      "inject": "Type Check Results (exit {exitCode}):\n```\n{stdout}\n{stderr}\n```",
      "toast": { "title": "Type Check", "message": "exit {exitCode}", "variant": "info" }
    }
  ],
  "session": []
}
HOOKS_CONFIG
  print_success "Created command-hooks.jsonc"
}

_write_engineer_agent() {
  local opencode_dir="$1" hooks_source="$2"
  local agent_dir="$opencode_dir/agent"
  local agent_target="$agent_dir/engineer.md"
  mkdir -p "$agent_dir"

  [[ -f "$agent_target" ]] && { print_info "Engineer agent already exists"; return; }

  local agent_source="$hooks_source/agents/engineer.md"
  if [[ -f "$agent_source" ]]; then
    cp "$agent_source" "$agent_target"
  else
    cat > "$agent_target" << 'AGENT'
---
description: Senior Software Engineer - Writes clean, tested, and maintainable code
mode: subagent
hooks:
  after:
    - run: ["npm run lint"]
      inject: "Lint Results (exit {exitCode}):\n```\n{stdout}\n{stderr}\n```"
    - run: ["npm run typecheck"]
      inject: "Type Check Results (exit {exitCode}):\n```\n{stdout}\n{stderr}\n```"
---

You are a senior software engineer. Follow best practices, ensure type safety,
write tests, and fix any lint or type errors before considering a task complete.
AGENT
  fi
  print_success "Created Engineer agent"
}

# ── Project type ──────────────────────────────────────────────────────────────

_types_dir() {
  local types_dir="$_LIB_DIR/../types"
  [[ -d "$types_dir" ]] || types_dir="$GA_DIR/setup/types"
  echo "$types_dir"
}

_type_config_value() {
  local project_type="$1" key="$2"
  local types_dir; types_dir="$(_types_dir)"
  local types_json="$types_dir/types.json"

  if [[ -f "$types_json" ]] && command_exists python3; then
    python3 -c "
import json
try:
  data=json.load(open('$types_json'))
  value=data.get('types',{}).get('$project_type',{}).get('$key','')
  print(value if isinstance(value, str) else '')
except: pass
" 2>/dev/null
  fi
}

_type_extensions() {
  local project_type="$1" ext_type="$2"
  local types_dir; types_dir="$(_types_dir)"
  local types_json="$types_dir/types.json"

  if [[ -f "$types_json" ]] && command_exists python3; then
    python3 -c "
import json
import os
try:
  data=json.load(open('$types_json'))
  base_values=data.get('base_config',{}).get('extensions',{}).get('$ext_type',[])
  type_values=data.get('types',{}).get('$project_type',{}).get('extensions',{}).get('$ext_type',[])
  merged=[]
  for group in (base_values, type_values):
    if isinstance(group, list):
      for value in group:
        value=str(value)
        if value and value not in merged:
          # Skip MCPs if YWAI_SKIP_MCPS is set
          if '$ext_type' == 'mcps' and os.environ.get('YWAI_SKIP_MCPS') == 'true':
            continue
          merged.append(value)
  print(' '.join(merged))
except: pass
" 2>/dev/null
  fi
}

_resolve_type_file() {
  local project_type="$1" key="$2" fallback_name="$3"
  local types_dir; types_dir="$(_types_dir)"
  local rel_path
  rel_path="$(_type_config_value "$project_type" "$key")"

  if [[ -n "$rel_path" ]]; then
    local repo_root project_root
    repo_root="$(cd "$_LIB_DIR/../.." && pwd)"
    project_root="$(cd "$_LIB_DIR/../../.." && pwd)"
    local candidate="$project_root/ywai/${rel_path#setup/}"
    [[ -f "$candidate" ]] && { echo "$candidate"; return 0; }

    candidate="$repo_root/$rel_path"
    [[ -f "$candidate" ]] && { echo "$candidate"; return 0; }

    candidate="$GA_DIR/$rel_path"
    [[ -f "$candidate" ]] && { echo "$candidate"; return 0; }
  fi

  local fallback="$types_dir/$project_type/$fallback_name"
  [[ -f "$fallback" ]] && echo "$fallback"
}

list_project_types() {
  local types_dir; types_dir="$(_types_dir)"
  local types_json="$types_dir/types.json"
  echo "Available project types:"
  if [[ -f "$types_json" ]] && command_exists python3; then
    python3 -c "
import json
data=json.load(open('$types_json'))
for name,cfg in data.get('types',{}).items():
    print(f'  {name:<12} - {cfg.get(\"description\",\"\")}')
print(f'\n  default: {data.get(\"default\",\"nest\")}')
" 2>/dev/null
  else
    for d in "$types_dir"/*/; do [[ -d "$d" ]] && echo "  - $(basename "$d")"; done
  fi
}

apply_project_type() {
  local project_type="${1:-nest}" target_dir="${2:-.}" force="${3:-false}"
  local types_dir; types_dir="$(_types_dir)"
  local type_dir="$types_dir/$project_type"

  if [[ ! -d "$type_dir" ]]; then
    print_warning "Unknown project type '$project_type', falling back to 'generic'"
    type_dir="$types_dir/generic"
    [[ -d "$type_dir" ]] || return 1
  fi

  print_info "Applying project type: $project_type"

  local doc source_file config_key
  for doc in AGENTS.md REVIEW.md; do
    case "$doc" in
      AGENTS.md) config_key="agents_md" ;;
      REVIEW.md) config_key="review_md" ;;
      *) config_key="" ;;
    esac
    source_file="$(_resolve_type_file "$project_type" "$config_key" "$doc")"
    if [[ -f "$source_file" ]]; then
      local target="$target_dir/$doc"
      if [[ ! -f "$target" || "$force" == "true" ]]; then
        cp "$source_file" "$target"
        # Append optional template sections for AGENTS.md
        if [[ "$doc" == "AGENTS.md" ]]; then
          for tpl in "$_LIB_DIR/templates/sdd-orchestrator.md" "$_LIB_DIR/templates/engram-protocol.md"; do
            [[ -f "$tpl" ]] && { echo ""; cat "$tpl"; } >> "$target"
          done
        fi
        print_success "Copied $doc ($project_type)"
      else
        print_info "$doc already exists, skipping (pass force=true to overwrite)"
      fi
    fi
  done

  # Copy skills (type-specific + always-on SDD)
  local types_json="$types_dir/types.json"
  local main_skills="$_LIB_DIR/../../skills"
  [[ -d "$main_skills" ]] || main_skills="$GA_DIR/skills"
  local skills_target="$target_dir/skills"
  mkdir -p "$skills_target"

  if [[ -f "$types_json" ]] && command_exists python3; then
    local type_skills
    type_skills=$(python3 -c "
import json
try:
  data=json.load(open('$types_json'))
  print(' '.join(data.get('types',{}).get('$project_type',{}).get('skills',[])))
except: pass
" 2>/dev/null)

    local copied=0
    for skill in $type_skills; do
      [[ -d "$main_skills/$skill" && ! -d "$skills_target/$skill" ]] \
        && cp -r "$main_skills/$skill" "$skills_target/$skill" \
        && ((copied++)) || true
    done
    [[ $copied -gt 0 ]] && print_success "Copied $copied type skills"
  fi

  local copied_sdd=0
  local sdd_dir sdd_name
  for sdd_dir in "$main_skills"/sdd-*; do
    [[ -d "$sdd_dir" ]] || continue
    sdd_name="$(basename "$sdd_dir")"

    if [[ -d "$skills_target/$sdd_name" || "$sdd_dir" -ef "$skills_target/$sdd_name" ]]; then
      continue
    fi

    cp -r "$sdd_dir" "$skills_target/$sdd_name"
    ((copied_sdd++)) || true
  done
  [[ $copied_sdd -gt 0 ]] && print_success "Copied $copied_sdd SDD skill(s)"

  print_success "Project type '$project_type' applied"
}

# ── Full project configure ────────────────────────────────────────────────────

configure_project() {
  local provider="${1:-}" target_dir="${2:-.}" skip_ga="${3:-false}"
  local project_type="${4:-nest}"
  local force="${5:-false}"

  print_info "Configuring project at $target_dir..."

  # Resolve GA install dir (prefer local repo when running from source)
  local ga_install_dir="$GA_DIR"
  local repo_root; repo_root="$(cd "$_LIB_DIR/../.." && pwd)"
  [[ -f "$repo_root/setup/setup.sh" ]] && ga_install_dir="$repo_root"

  apply_project_type "$project_type" "$target_dir" "$force"

  # Copy skills/ assets that may still be missing after apply_project_type
  local types_dir; types_dir="$(_types_dir)"
  local types_json="$types_dir/types.json"
  local copy_shared_skills
  local skills_src="$ga_install_dir/skills"
  local skills_tgt="$target_dir/skills"

  copy_shared_skills=$(python3 -c "
import json
try:
  data=json.load(open('$types_json'))
  print(data.get('base_config',{}).get('copy_shared_skills', True))
except: print(True)
" 2>/dev/null)

  if [[ "$copy_shared_skills" == "true" ]]; then
    if [[ "$skills_src" -ef "$skills_tgt" ]]; then
      print_info "skills/ already in place"
    elif [[ -d "$skills_src" ]]; then
      mkdir -p "$skills_tgt"
      local copied_shared=0
      local item name
      for item in "$skills_src"/*; do
        [[ -e "$item" ]] || continue
        name="$(basename "$item")"
        [[ -e "$skills_tgt/$name" ]] && continue
        if [[ -d "$item" ]]; then
          cp -r "$item" "$skills_tgt/$name"
        else
          cp "$item" "$skills_tgt/$name"
        fi
        ((copied_shared++)) || true
      done
      [[ $copied_shared -gt 0 ]] \
        && print_success "Copied $copied_shared shared skill asset(s)" \
        || print_info "skills/ already up to date"
    fi
  fi

  # Ensure skills/_shared exists even when full shared copy is disabled.
  if [[ -d "$skills_src/_shared" ]]; then
    local shared_tgt="$skills_tgt/_shared"
    mkdir -p "$shared_tgt"
    local copied_shared_assets=0
    local shared_item shared_name
    for shared_item in "$skills_src/_shared"/*; do
      [[ -e "$shared_item" ]] || continue
      shared_name="$(basename "$shared_item")"
      [[ -e "$shared_tgt/$shared_name" ]] && continue
      if [[ -d "$shared_item" ]]; then
        cp -r "$shared_item" "$shared_tgt/$shared_name"
      else
        cp "$shared_item" "$shared_tgt/$shared_name"
      fi
      ((copied_shared_assets++)) || true
    done
    [[ $copied_shared_assets -gt 0 ]] && print_success "Copied $copied_shared_assets skills/_shared asset(s)"
  fi

  # Run AI skills setup
  local skills_setup="$skills_tgt/setup.sh"
  if [[ -f "$skills_setup" ]]; then
    (cd "$target_dir" && bash "$skills_setup" --copilot --opencode >/dev/null 2>&1) \
      && print_success "AI skills configured" || print_warning "AI skills setup had issues"
  fi

  _update_gitignore "$target_dir"
  _init_ga_in_project "$provider" "$target_dir" "$skip_ga" "$ga_install_dir"
  _setup_lefthook "$target_dir" "$project_type" "$ga_install_dir"

  # VS Code minimal settings
  local vscode_settings="$target_dir/.vscode/settings.json"
  if [[ ! -f "$vscode_settings" ]]; then
    mkdir -p "$(dirname "$vscode_settings")"
    printf '{\n    "github.copilot.chat.useAgentsMdFile": true\n}\n' > "$vscode_settings"
    print_success "Created VS Code settings"
  fi

  print_success "Project configured"
}

_update_gitignore() {
  local target_dir="$1"
  local gitignore="$target_dir/.gitignore"
  [[ -f "$gitignore" ]] || touch "$gitignore"

  local patterns=(
    "# Dependencies" "node_modules/" ""
    "# Environment" ".env" ".env.local" ".env.*.local" ""
    "# AI Assistants" "CLAUDE.md" "CURSOR.md" "GEMINI.md" ".cursorrules" ".ga" ".gga" ".claude/" ""
    "# OpenCode" ".opencode/plugins/**/node_modules/" ".opencode/plugins/**/dist/" ".opencode/**/cache/" ""
    "# System" ".DS_Store" "Thumbs.db" ""
    "# Logs" "*.log" "logs/" ""
    "# IDE" ".idea/" "*.iml" ".vscode/"
  )

  local added=0
  for p in "${patterns[@]}"; do
    if [[ -z "$p" ]]; then
      [[ -s "$gitignore" && -n "$(tail -1 "$gitignore")" ]] && echo "" >> "$gitignore"
      continue
    fi
    grep -qF "$p" "$gitignore" 2>/dev/null || { echo "$p" >> "$gitignore"; ((added++)) || true; }
  done

  [[ $added -gt 0 ]] \
    && print_success "Added $added patterns to .gitignore" \
    || print_info ".gitignore already up to date"
}

_init_ga_in_project() {
  local provider="$1" target_dir="$2" skip_ga="$3" ga_install_dir="$4"
  [[ "$skip_ga" == "true" ]] && return 0
  command_exists ga || { print_warning "ga not found, skipping project init"; return 0; }

  (cd "$target_dir" && ga init >/dev/null 2>&1) || { print_warning "Failed to initialize GA"; return 0; }
  print_success "GA initialized"

  local ga_config="$target_dir/.ga"
  local ga_template="$ga_install_dir/.ga.opencode-template"
  [[ -f "$ga_template" && -f "$ga_config" ]] && cp "$ga_template" "$ga_config" \
    && print_success "Applied OpenCode template to .ga"

  if [[ -n "$provider" && "$provider" != "opencode" && -f "$ga_config" ]]; then
    sed -i.bak "s|PROVIDER=\"opencode:github-copilot/claude-haiku-4.5\"|PROVIDER=\"$provider\"|" "$ga_config"
    rm -f "$ga_config.bak"
    print_success "Provider set to: $provider"
  fi

  (cd "$target_dir" && ga install >/dev/null 2>&1) \
    && print_success "GA hooks installed" || print_warning "GA hook installation had issues"
}

_setup_lefthook() {
  local target_dir="$1" project_type="$2" ga_install_dir="$3"
  command_exists lefthook || { print_info "Lefthook not installed, skipping"; return 0; }

  local lefthook_cfg="$target_dir/lefthook.yml"
  [[ -f "$lefthook_cfg" ]] && { print_info "lefthook.yml already exists"; return 0; }

  local auto_dir="$ga_install_dir/auto"
  local template
  template="$(_resolve_type_file "$project_type" "lefthook_yml" "lefthook.yml")"
  [[ -f "$template" ]] || template="$auto_dir/autohook.yml.template"
  [[ -f "$template" ]] || { print_warning "Lefthook template not found"; return 0; }

  cp "$template" "$lefthook_cfg"
  print_success "Created lefthook.yml ($project_type)"
  (cd "$target_dir" && lefthook install >/dev/null 2>&1) \
    && print_success "Lefthook hooks installed" || print_warning "Lefthook install had issues"
}

# ── Extensions ────────────────────────────────────────────────────────────────

list_extensions() {
  local extensions_dir="$_LIB_DIR/../../extensions"

  echo "Available extensions:"
  local ext_type dir
  for ext_type in hooks mcps install-steps; do
    echo ""
    case "$ext_type" in
      hooks) echo "Hooks:" ;;
      mcps) echo "MCPs:" ;;
      install-steps) echo "Install Steps:" ;;
    esac

    if [[ ! -d "$extensions_dir/$ext_type" ]]; then
      echo "  (none)"
      continue
    fi

    local found=0
    for dir in "$extensions_dir/$ext_type"/*; do
      [[ -d "$dir" ]] || continue
      echo "  - $(basename "$dir")"
      found=1
    done
    [[ $found -eq 0 ]] && echo "  (none)"
  done

  return 0
}

install_extension() {
  local ext_type="$1" ext_name="$2" target_dir="${3:-.}"
  local extensions_dir="$_LIB_DIR/../../extensions"
  local ext_dir="$extensions_dir/$ext_type/$ext_name"

  if [[ ! -d "$ext_dir" ]]; then
    print_warning "Extension not found: $ext_type/$ext_name"
    return 1
  fi

  if [[ ! -f "$ext_dir/install.sh" ]]; then
    print_warning "Skipping $ext_type/$ext_name: missing install.sh"
    return 1
  fi

  print_info "Installing extension: $ext_type/$ext_name..."
  (cd "$ext_dir" && bash "./install.sh" "$target_dir") \
    && print_success "Extension $ext_name installed" \
    || { print_warning "Extension $ext_name failed"; return 1; }
}

install_type_extensions() {
  local project_type="${1:-nest}" target_dir="${2:-.}"
  local ext_name failed=0

  for ext_name in $(_type_extensions "$project_type" "hooks"); do
    install_extension "hooks" "$ext_name" "$target_dir" || ((failed++)) || true
  done

  # Skip MCPs if requested (useful for testing/CI)
  if [[ "${YWAI_SKIP_MCPS:-false}" != "true" ]]; then
    for ext_name in $(_type_extensions "$project_type" "mcps"); do
      install_extension "mcps" "$ext_name" "$target_dir" || ((failed++)) || true
    done
  fi

  for ext_name in $(_type_extensions "$project_type" "install-steps"); do
    install_extension "install-steps" "$ext_name" "$target_dir" || ((failed++)) || true
  done

  for ext_name in $(_type_extensions "$project_type" "commands"); do
    install_extension "commands" "$ext_name" "$target_dir" || ((failed++)) || true
  done

  [[ $failed -eq 0 ]]
}

# ── Update all ────────────────────────────────────────────────────────────────

update_all_components() {
  local target_dir="${1:-.}"
  local updated=0 failed=0

  print_info "Checking for updates..."

  local ga_status ga_current
  IFS='|' read -r ga_status ga_current _ <<< "$(detect_ga)"
  if [[ "$ga_status" == "OUTDATED" ]]; then
    install_ga "update" && ((updated++)) || ((failed++))
  else
    print_info "GA is up to date ($ga_current)"
  fi

  local sdd_status sdd_current
  IFS='|' read -r sdd_status sdd_current _ <<< "$(detect_sdd "$target_dir")"
  if [[ "$sdd_status" == "NOT_INSTALLED" || "$sdd_status" == "PARTIAL" ]]; then
    install_sdd "$target_dir" && ((updated++)) || ((failed++))
  else
    print_info "SDD Orchestrator is up to date ($sdd_current skills)"
  fi

  [[ $updated -gt 0 ]] && print_success "Updated $updated component(s)"
  [[ $failed -gt 0 ]]  && { print_warning "Failed to update $failed component(s)"; return 1; }
  return 0
}

# ── Direct execution ──────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-help}" in
    install-ga)       install_ga "install" ;;
    update-ga)        install_ga "update" ;;
    install-sdd)      install_sdd "${2:-.}" ;;
    install-vscode)   install_vscode_extensions ;;
    install-extension) install_extension "${2:-}" "${3:-}" "${4:-.}" ;;
    install-type-extensions) install_type_extensions "${2:-nest}" "${3:-.}" ;;
    configure)        configure_project "${2:-}" "${3:-.}" "false" "${4:-nest}" ;;
    list-extensions)  list_extensions ;;
    list-types)       list_project_types ;;
    update-all)       update_all_components "${2:-.}" ;;
    *)
      echo "Usage: $0 {install-ga|update-ga|install-sdd|install-vscode|install-extension|install-type-extensions|configure|list-extensions|list-types|update-all}"
      exit 1
      ;;
  esac
fi
