#!/usr/bin/env bash
set -e

TARGET_DIR="${1:-.}"
EXT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$EXT_DIR/../../../skills/_shared"
TARGET_SKILLS_DIR="$TARGET_DIR/skills"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Shared skills source not found: $SOURCE_DIR"
  exit 1
fi

mkdir -p "$TARGET_SKILLS_DIR"

copied=0
for skill_dir in "$SOURCE_DIR"/*; do
  [[ -d "$skill_dir" ]] || continue
  skill_name="$(basename "$skill_dir)"
  if [[ ! -d "$TARGET_SKILLS_DIR/$skill_name" ]]; then
    cp -r "$skill_dir" "$TARGET_SKILLS_DIR/$skill_name"
    copied=$((copied + 1))
  fi
done

echo "Installed $copied shared skill(s) into skills/"
