#!/bin/bash
# Quick setup - One command installation
# Usage: curl -sSL https://raw.githubusercontent.com/Yoizen/gga-copilot/main/auto/quick-setup.sh | bash
#    or: curl -sSL https://raw.githubusercontent.com/Yoizen/gga-copilot/main/auto/quick-setup.sh | bash -s -- --all
#    or: ./quick-setup.sh [OPTIONS]

set -e

REPO_URL="https://github.com/Yoizen/gga-copilot.git"
INSTALL_DIR="/tmp/gga-bootstrap-$$"

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🚀 GGA + OpenSpec Quick Setup${NC}"
echo ""

cleanup() {
    rm -rf "$INSTALL_DIR" 2>/dev/null || true
}

trap cleanup EXIT

echo "Downloading bootstrap scripts..."
git clone --quiet --depth 1 "$REPO_URL" "$INSTALL_DIR" 2>/dev/null

if [ ! -f "$INSTALL_DIR/auto/bootstrap.sh" ]; then
    echo -e "${RED}✗ Failed to download bootstrap script${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Downloaded${NC}"
echo ""

echo "Running setup..."
bash "$INSTALL_DIR/auto/bootstrap.sh" "$@"

echo ""
echo -e "${GREEN}✓ Quick setup complete!${NC}"
