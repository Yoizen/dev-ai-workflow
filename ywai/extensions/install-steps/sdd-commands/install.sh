#!/usr/bin/env bash
set -e

TARGET_DIR="${1:-.}"
EXT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$EXT_DIR"
TARGET_PROMPTS_DIR="$TARGET_DIR/prompts"
TARGET_OPENCODE_SKILLS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Commands source not found: $SOURCE_DIR"
  exit 1
fi

mkdir -p "$TARGET_PROMPTS_DIR" "$TARGET_OPENCODE_SKILLS_DIR"

copied=0
for file in "$SOURCE_DIR"/*.md; do
  [[ -f "$file" ]] || continue
  name="$(basename "$file" .md)"
  
  # Copy to GitHub Copilot prompts
  if [[ ! -f "$TARGET_PROMPTS_DIR/$name.md" ]]; then
    cp "$file" "$TARGET_PROMPTS_DIR/$name.md"
    copied=$((copied + 1))
  fi
  
  # Copy to OpenCode skills directory structure
  skill_dir="$TARGET_OPENCODE_SKILLS_DIR/$name"
  mkdir -p "$skill_dir"
  if [[ ! -f "$skill_dir/SKILL.md" ]]; then
    cp "$file" "$skill_dir/SKILL.md"
    copied=$((copied + 1))
  fi
done

echo "Installed SDD commands to prompts ($TARGET_PROMPTS_DIR) and OpenCode skills ($TARGET_OPENCODE_SKILLS_DIR)"
