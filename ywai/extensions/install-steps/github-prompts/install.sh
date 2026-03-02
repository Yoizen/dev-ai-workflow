#!/usr/bin/env bash
set -e

TARGET_DIR="${1:-.}"
EXT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$EXT_DIR/prompts"
TARGET_PROMPTS_DIR="$TARGET_DIR/.github/prompts"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Prompts source not found: $SOURCE_DIR"
  exit 1
fi

mkdir -p "$TARGET_PROMPTS_DIR"

copied=0
for file in "$SOURCE_DIR"/*.md; do
  [[ -f "$file" ]] || continue
  name="$(basename "$file")"
  if [[ ! -f "$TARGET_PROMPTS_DIR/$name" ]]; then
    cp "$file" "$TARGET_PROMPTS_DIR/$name"
    copied=$((copied + 1))
  fi
done

echo "Installed $copied GitHub prompt file(s) into .github/prompts"
