#!/usr/bin/env bash
# Global Agents Extension — Linux/macOS
# Instala agents en todas las rutas de Copilot/Claude/Agents
set -e

TARGET_DIR="${1:-.}"
PROJECT_TYPE="${YWAI_PROJECT_TYPE:-generic}"
EXT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$EXT_DIR/../../.." && pwd)"
AGENTS_SOURCE="$EXT_DIR/templates"

echo "Configuring global agents for project type: $PROJECT_TYPE"

HOME_DIR="${HOME}"

declare -A AGENT_LOCATIONS=(
    ["OpenCode"]="$HOME_DIR/.config/opencode/agents"
    ["Copilot"]="$HOME_DIR/.copilot/agents"
    ["Claude"]="$HOME_DIR/.claude/agents"
    ["Agents"]="$HOME_DIR/.agents/agents"
)

if [[ ! -d "$AGENTS_SOURCE" ]]; then
    echo "Agent templates not found: $AGENTS_SOURCE"
    exit 1
fi

copied_total=0

for platform_name in "${!AGENT_LOCATIONS[@]}"; do
    dest_dir="${AGENT_LOCATIONS[$platform_name]}"
    mkdir -p "$dest_dir"
    
    rm -f "$dest_dir"/*.md
    
    for agent_file in "$AGENTS_SOURCE"/*.md; do
        if [[ -f "$agent_file" ]]; then
            agent_name=$(basename "$agent_file")
            cp -f "$agent_file" "$dest_dir/"
            echo "  [$platform_name] Installed agent: $agent_name"
            ((copied_total++))
        fi
    done
done

echo ""
echo "Global agents configured ($copied_total templates copied)"
echo ""
echo "Locations:"
for platform_name in "${!AGENT_LOCATIONS[@]}"; do
    echo "  $platform_name: ${AGENT_LOCATIONS[$platform_name]}"
done
