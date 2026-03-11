#!/usr/bin/env bash
# ============================================================================
# Guardian Agent — Uninstaller
# ============================================================================
# Removes the ga CLI tool from your system
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=setup/lib/ui.sh
source "$SCRIPT_DIR/setup/lib/ui.sh"

print_banner "Guardian Agent — Uninstaller"

# ── Remove binary ─────────────────────────────────────────────────────────────

FOUND=false
for loc in "/usr/local/bin/ga" "$HOME/.local/bin/ga"; do
  if [[ -f "$loc" ]]; then
    rm "$loc"
    print_success "Removed: $loc"
    FOUND=true
  fi
done

# ── Remove lib directory ──────────────────────────────────────────────────────

LIB_DIR="$HOME/.local/share/ga"
if [[ -d "$LIB_DIR" ]]; then
  rm -rf "$LIB_DIR"
  print_success "Removed: $LIB_DIR"
  FOUND=true
fi

# ── Remove global config (optional) ──────────────────────────────────────────

GLOBAL_CONFIG="$HOME/.config/ga"
if [[ -d "$GLOBAL_CONFIG" ]]; then
  echo ""
  if ask_yes_no "Remove global config ($GLOBAL_CONFIG)?" "n"; then
    rm -rf "$GLOBAL_CONFIG"
    print_success "Removed: $GLOBAL_CONFIG"
  else
    print_warning "Kept global config"
  fi
fi

[[ "$FOUND" == false ]] && print_warning "ga was not found on this system"

echo ""
echo -e "${BOLD}Note:${NC} Project-specific configs (.ga) and git hooks"
echo "      were not removed. Remove them manually if needed."
echo ""
