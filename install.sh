#!/usr/bin/env bash

# ============================================================================
# Guardian Agent - Installer
# ============================================================================
# Installs the ga CLI tool to your system
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}${BOLD}  Guardian Agent - Installer${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Determine install location
if [[ -w "/usr/local/bin" ]]; then
    INSTALL_DIR="/usr/local/bin"
elif [[ -d "$HOME/.local/bin" && -w "$HOME/.local/bin" ]]; then
    INSTALL_DIR="$HOME/.local/bin"
else
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
fi

echo -e "${BLUE}ℹ️  Install directory: $INSTALL_DIR${NC}"
echo ""

if [[ ! -w "$INSTALL_DIR" ]]; then
    echo -e "${RED}❌ No write permission to $INSTALL_DIR${NC}"
    echo -e "${YELLOW}Fix ownership or permissions, e.g.:${NC}"
    echo "  sudo chown -R $USER:$USER $INSTALL_DIR"
    exit 1
fi

# Check if already installed
if [[ -f "$INSTALL_DIR/ga" ]]; then
    echo -e "${YELLOW}⚠️  Existing ga found at $INSTALL_DIR/ga${NC}"
    echo -e "${BLUE}ℹ️  Removing old version for update...${NC}"
    rm -f "$INSTALL_DIR/ga"
fi

# Create lib directory
SHARE_INSTALL_DIR="$HOME/.local/share/ga"
LIB_INSTALL_DIR="$SHARE_INSTALL_DIR/lib"
mkdir -p "$LIB_INSTALL_DIR"

# Copy files
cp "$SCRIPT_DIR/bin/ga" "$INSTALL_DIR/ga"
cp "$SCRIPT_DIR/package.json" "$SHARE_INSTALL_DIR/package.json"
cp "$SCRIPT_DIR/lib/providers.sh" "$LIB_INSTALL_DIR/providers.sh"
cp "$SCRIPT_DIR/lib/cache.sh" "$LIB_INSTALL_DIR/cache.sh"
cp "$SCRIPT_DIR/lib/pr_mode.sh" "$LIB_INSTALL_DIR/pr_mode.sh"

# Update LIB_DIR path in installed script
if [[ "$(uname)" == "Darwin" ]]; then
  sed -i '' "s|LIB_DIR=.*|LIB_DIR=\"$LIB_INSTALL_DIR\"|" "$INSTALL_DIR/ga"
else
  sed -i "s|LIB_DIR=.*|LIB_DIR=\"$LIB_INSTALL_DIR\"|" "$INSTALL_DIR/ga"
fi

# Make executable
chmod +x "$INSTALL_DIR/ga"
chmod +x "$LIB_INSTALL_DIR/providers.sh"
chmod +x "$LIB_INSTALL_DIR/cache.sh"
chmod +x "$LIB_INSTALL_DIR/pr_mode.sh"

echo -e "${GREEN}✅ Installed ga to $INSTALL_DIR${NC}"
echo ""

# Check if install dir is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  echo -e "${YELLOW}⚠️  $INSTALL_DIR is not in your PATH${NC}"
  echo ""
  echo "Add this line to your ~/.bashrc or ~/.zshrc:"
  echo ""
  echo -e "  ${CYAN}export PATH=\"$INSTALL_DIR:\$PATH\"${NC}"
  echo ""
fi

# Check for ga alias conflict (common in oh-my-zsh)
echo -e "${BOLD}Checking for command conflicts...${NC}"

# Determine the shell RC file
RC_FILE=""
if [[ -n "$ZSH_VERSION" ]] || [[ "$SHELL" == */zsh ]]; then
  RC_FILE="$HOME/.zshrc"
elif [[ -n "$BASH_VERSION" ]] || [[ "$SHELL" == */bash ]]; then
  RC_FILE="$HOME/.bashrc"
fi

# Detect alias conflict: either live alias or oh-my-zsh git plugin loaded in RC
HAS_ALIAS_CONFLICT=false

# Check 1: live alias in current shell (only works in interactive shells)
if type ga 2>/dev/null | grep -q 'alias' 2>/dev/null; then
  HAS_ALIAS_CONFLICT=true
fi

# Check 2: oh-my-zsh git plugin in .zshrc (works even in non-interactive shells)
if [[ -f "$HOME/.zshrc" ]]; then
  if grep -qE 'plugins=.*\bgit\b' "$HOME/.zshrc" 2>/dev/null; then
    HAS_ALIAS_CONFLICT=true
    RC_FILE="$HOME/.zshrc"
  fi
fi

if [[ "$HAS_ALIAS_CONFLICT" == "true" && -n "$RC_FILE" && -f "$RC_FILE" ]]; then
  echo -e "${YELLOW}⚠️  Detected 'ga' alias conflict (oh-my-zsh git plugin aliases ga='git add')${NC}"

  # Add unalias only if not already present
  if ! grep -qF 'unalias ga' "$RC_FILE" 2>/dev/null; then
    echo "" >> "$RC_FILE"
    echo "# Guardian Agent: remove oh-my-zsh 'ga' alias (git add) so 'ga' CLI works" >> "$RC_FILE"
    echo "unalias ga 2>/dev/null" >> "$RC_FILE"
    echo -e "${GREEN}✅ Added 'unalias ga' to $RC_FILE${NC}"
    echo -e "   ${CYAN}Run 'source $RC_FILE' or open a new terminal for changes to take effect.${NC}"
  else
    echo -e "${GREEN}✅ 'unalias ga' already present in $RC_FILE${NC}"
  fi
  echo ""
fi

echo -e "${BOLD}Getting started:${NC}"
echo ""
echo "  1. Navigate to your project:"
echo "     cd /path/to/your/project"
echo ""
echo "  2. Initialize config:"
echo "     ga init"
echo ""
echo "  3. Create your AGENTS.md with coding standards"
echo ""
echo "  4. Install the git hook:"
echo "     ga install"
echo ""
echo "  5. You're ready! The hook will run on each commit."
echo ""
