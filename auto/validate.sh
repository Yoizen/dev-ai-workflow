#!/bin/bash
# ============================================================================
# Validation Script - Verifica que el setup fue exitoso
# ============================================================================

REPO_PATH="${1:-$(pwd)}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  GGA Setup Validation${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

REPO_PATH="$(cd "$REPO_PATH" && pwd)"
echo -e "${WHITE}Validating: $REPO_PATH${NC}"
echo ""

issues=()
warnings=()
success=()

# Check commands
echo -e "${YELLOW}Checking installed tools...${NC}"

commands=("git" "node" "npm" "gga" "code")
for cmd in "${commands[@]}"; do
    if command -v "$cmd" &> /dev/null; then
        if [ "$cmd" = "code" ]; then
            success+=("✓ $cmd is available")
        else
            version=$($cmd --version 2>/dev/null | head -n1)
            success+=("✓ $cmd is available ($version)")
        fi
    else
        if [ "$cmd" = "code" ]; then
            warnings+=("⚠ $cmd not found (VS Code CLI)")
        else
            issues+=("✗ $cmd is NOT installed")
        fi
    fi
done

echo ""
echo -e "${YELLOW}Checking repository structure...${NC}"

# Check directories
required_dirs=(
    ".specify/memory"
    "specs"
)

for dir in "${required_dirs[@]}"; do
    if [ -d "$REPO_PATH/$dir" ]; then
        success+=("✓ $dir/ exists")
    else
        issues+=("✗ $dir/ is missing")
    fi
done

# Check files
required_files=(
    "AGENTS.MD"
    "REVIEW.md"
    ".specify/memory/constitution.md"
    ".gga"
)

for file in "${required_files[@]}"; do
    if [ -f "$REPO_PATH/$file" ]; then
        success+=("✓ $file exists")
    else
        if [ "$file" = ".gga" ]; then
            warnings+=("⚠ $file is missing (run 'gga init')")
        else
            issues+=("✗ $file is missing")
        fi
    fi
done

echo ""
echo -e "${YELLOW}Checking GGA configuration...${NC}"

if [ -f "$REPO_PATH/.gga" ]; then
    content=$(cat "$REPO_PATH/.gga")
    
    if echo "$content" | grep -q "PROVIDER="; then
        success+=("✓ .gga has PROVIDER configured")
    else
        warnings+=("⚠ .gga is missing PROVIDER")
    fi
    
    if echo "$content" | grep -q "API_KEY="; then
        success+=("✓ .gga has API_KEY configured")
    else
        warnings+=("⚠ .gga is missing API_KEY")
    fi
fi

# Check VS Code extensions
echo ""
echo -e "${YELLOW}Checking VS Code extensions...${NC}"

if command -v code &> /dev/null; then
    extensions=$(code --list-extensions 2>/dev/null)
    
    required_exts=(
        "github.copilot"
        "ultracite.ultracite-vscode"
    )
    
    for ext in "${required_exts[@]}"; do
        if echo "$extensions" | grep -q "$ext"; then
            success+=("✓ Extension $ext is installed")
        else
            warnings+=("⚠ Extension $ext not found")
        fi
    done
fi

# Report
echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Results${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ ${#success[@]} -gt 0 ]; then
    echo -e "${GREEN}Success (${#success[@]}):${NC}"
    for item in "${success[@]}"; do
        echo -e "${GREEN}  $item${NC}"
    done
    echo ""
fi

if [ ${#warnings[@]} -gt 0 ]; then
    echo -e "${YELLOW}Warnings (${#warnings[@]}):${NC}"
    for item in "${warnings[@]}"; do
        echo -e "${YELLOW}  $item${NC}"
    done
    echo ""
fi

if [ ${#issues[@]} -gt 0 ]; then
    echo -e "${RED}Issues (${#issues[@]}):${NC}"
    for item in "${issues[@]}"; do
        echo -e "${RED}  $item${NC}"
    done
    echo ""
    echo -e "${YELLOW}Run bootstrap script to fix issues:${NC}"
    echo -e "${WHITE}  ./bootstrap.sh $REPO_PATH${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ All checks passed!${NC}"
echo ""
echo -e "${CYAN}Your repository is ready to use!${NC}"
echo ""
