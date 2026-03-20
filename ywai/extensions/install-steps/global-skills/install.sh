#!/usr/bin/env bash
# Global Skills Extension — Linux/macOS
# Instala skills en todas las rutas de Copilot/Claude/Agents
set -e

TARGET_DIR="${1:-.}"
EXT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$EXT_DIR/../../.." && pwd)"
SKILLS_SOURCE="$REPO_ROOT/ywai/skills"

echo "Installing global skills for AI assistants..."

HOME_DIR="${HOME}"

declare -A SKILL_LOCATIONS=(
    ["OpenCode"]="$HOME_DIR/.config/opencode/skills"
    ["Copilot"]="$HOME_DIR/.copilot/skills"
    ["Claude"]="$HOME_DIR/.claude/skills"
    ["Agents"]="$HOME_DIR/.agents/skills"
)

install_skill_to_location() {
    local source_skill_dir="$1"
    local dest_skills_dir="$2"
    local platform_name="$3"
    
    local skill_name
    skill_name=$(basename "$source_skill_dir")
    local skill_md="$source_skill_dir/SKILL.md"
    
    if [[ ! -f "$skill_md" ]]; then
        echo "  Skipping $skill_name (no SKILL.md found)"
        return 1
    fi
    
    local skill_dest_dir="$dest_skills_dir/$skill_name"
    mkdir -p "$skill_dest_dir"
    cp -f "$skill_md" "$skill_dest_dir/SKILL.md"
    
    if [[ -d "$source_skill_dir/assets" ]]; then
        cp -r "$source_skill_dir/assets" "$skill_dest_dir/"
    fi
    
    if [[ -d "$source_skill_dir/references" ]]; then
        cp -r "$source_skill_dir/references" "$skill_dest_dir/"
    fi
    
    echo "  [$platform_name] Installed: $skill_name"
    return 0
}

if [[ ! -d "$SKILLS_SOURCE" ]]; then
    echo "Skills source not found: $SKILLS_SOURCE"
    exit 1
fi

total=$(find "$SKILLS_SOURCE" -maxdepth 1 -type d | wc -l)
total=$((total - 1))

echo ""
echo "Found $total skills to install"
echo ""

copied_total=0
skipped_total=0

for platform_name in "${!SKILL_LOCATIONS[@]}"; do
    dest_dir="${SKILL_LOCATIONS[$platform_name]}"
    echo "Installing to $platform_name: $dest_dir"
    mkdir -p "$dest_dir"
    
    for skill_dir in "$SKILLS_SOURCE"/*/; do
        if [[ -d "$skill_dir" ]]; then
            if install_skill_to_location "$skill_dir" "$dest_dir" "$platform_name"; then
                ((copied_total++))
            else
                ((skipped_total++))
            fi
        fi
    done
    echo ""
done

echo "========================================"
echo "Global skills installation complete!"
echo "Installed: $copied_total skills"
echo "Skipped: $skipped_total (no SKILL.md)"
echo ""
echo "Locations:"
for platform_name in "${!SKILL_LOCATIONS[@]}"; do
    echo "  $platform_name: ${SKILL_LOCATIONS[$platform_name]}"
done
