#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

# --- Project init mode --------------------------------------------------------
INIT_TYPE=""
if [ "${1:-}" = "--init" ] && [ -n "${2:-}" ]; then
    INIT_TYPE="$2"
    TYPE_DIR="$REPO_ROOT/project-types/$INIT_TYPE"
    if [ ! -d "$TYPE_DIR" ]; then
        echo "Unknown project type '$INIT_TYPE'. Available:"
        ls -1 "$REPO_ROOT/project-types/"
        exit 1
    fi
    copied=0
    for file in AGENTS.md REVIEW.md; do
        src="$TYPE_DIR/$file"
        dst="./$file"
        if [ -f "$src" ]; then
            cp "$src" "$dst"
            echo "Copied $file -> $dst"
            copied=$((copied + 1))
        fi
    done
    if [ "$copied" -eq 0 ]; then
        echo "WARNING: No AGENTS.md or REVIEW.md found in $TYPE_DIR"
    else
        echo "Project initialized as '$INIT_TYPE'."
    fi
    exit 0
fi

# 1. Check gentle-ai
if ! command -v gentle-ai &>/dev/null; then
    if ! command -v go &>/dev/null; then
        echo "Go is not installed. Install Go first: https://go.dev/dl/"
        exit 1
    fi
    echo "Installing gentle-ai..."
    go install github.com/Gentleman-Programming/gentle-ai@latest
    export PATH="$PATH:$(go env GOPATH)/bin"
else
    echo "gentle-ai already installed: $(which gentle-ai)"
fi

# 2. Prompt for base install
echo ""
echo "Run the following to install the base Gentleman Stack:"
echo "   gentle-ai install --agent <your-agent> --preset ecosystem-only"
echo ""
echo "Supported agents: claude-code, opencode, gemini-cli, cursor, vscode-copilot, codex, windsurf, antigravity"
echo ""

# 3. Detect installed agents and link extra skills
get_skills_dir() {
    local agent="$1"
    case "$agent" in
        windsurf)
            dir="${HOME}/.windsurf/skills"
            [ -d "$dir" ] && { echo "$dir"; return; }
            command -v windsurf &>/dev/null && mkdir -p "$dir" && echo "$dir"
            ;;
        opencode)
            dir="${HOME}/.config/opencode/skills"
            [ -d "$dir" ] && { echo "$dir"; return; }
            (command -v opencode &>/dev/null || [ -d "${HOME}/.config/opencode" ]) && mkdir -p "$dir" && echo "$dir"
            ;;
        claude-code)
            dir="${HOME}/.claude/skills"
            [ -d "$dir" ] && { echo "$dir"; return; }
            command -v claude &>/dev/null && mkdir -p "$dir" && echo "$dir"
            ;;
        cursor)
            dir="${HOME}/.cursor/skills"
            [ -d "$dir" ] && { echo "$dir"; return; }
            dir2="${HOME}/Library/Application Support/Cursor/skills"
            [ -d "$dir2" ] && { echo "$dir2"; return; }
            command -v cursor &>/dev/null && mkdir -p "$dir" && echo "$dir"
            ;;
        gemini-cli)
            dir="${HOME}/.gemini/skills"
            [ -d "$dir" ] && { echo "$dir"; return; }
            command -v gemini &>/dev/null && mkdir -p "$dir" && echo "$dir"
            ;;
        vscode-copilot)
            dir="${HOME}/.config/Code/skills"
            [ -d "$dir" ] && { echo "$dir"; return; }
            dir2="${HOME}/Library/Application Support/Code/User/skills"
            [ -d "$dir2" ] && { echo "$dir2"; return; }
            command -v code &>/dev/null && mkdir -p "$dir" && echo "$dir"
            ;;
        codex)
            dir="${HOME}/.codex/skills"
            [ -d "$dir" ] && { echo "$dir"; return; }
            command -v codex &>/dev/null && mkdir -p "$dir" && echo "$dir"
            ;;
    esac
}

install_skills() {
    local skills_dir="$1"
    for skill_dir in "$REPO_ROOT"/skills/*/; do
        name=$(basename "$skill_dir")
        target="$skills_dir/$name"
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$skill_dir" ]; then
            continue
        fi
        rm -rf "$target"
        ln -s "$skill_dir" "$target"
        echo "  Linked skill: $name"
    done
}

installed=()
for agent in opencode windsurf claude-code cursor gemini-cli vscode-copilot codex; do
    dir=$(get_skills_dir "$agent" || true)
    if [ -n "$dir" ]; then
        echo "[$agent] -> $dir"
        install_skills "$dir"
        installed+=("$agent")
    fi
done

if [ ${#installed[@]} -eq 0 ]; then
    echo ""
    echo "WARNING: No supported agents detected. Install one first, then re-run this script."
    echo ""
    echo "Example:"
    echo "   npm install -g @anthropic-ai/claude-code   # claude-code"
    echo "   npm install -g opencode                     # opencode"
    echo "   # or install Windsurf/Cursor from their websites"
else
    echo ""
    echo "Done. Extra skills linked for: ${installed[*]}"
fi
