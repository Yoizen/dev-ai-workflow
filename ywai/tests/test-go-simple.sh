#!/bin/bash
# Simple Test for Go-based Setup Wizard (no Docker)

set -e

CYAN='\033[0;36m' GREEN='\033[0;32m' RED='\033[0;31m' YELLOW='\033[1;33m' NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Simple Test: Go Setup Wizard${NC}"
echo -e "${CYAN}============================================${NC}\n"

PASS=0
FAIL=0

run() {
  local name="$1"
  local cmd="$2"
  echo -e "${YELLOW}▶ $name${NC}"
  if eval "$cmd" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅ PASS${NC}"
    ((PASS++)) || true
    return 0
  fi
  echo -e "  ${RED}❌ FAIL${NC}"
  eval "$cmd"
  ((FAIL++)) || true
  return 1
}

# ============================================================================
# TEST: Go Build
# ============================================================================

cd "$(dirname "$0")/../setup"

run "Clean build artifacts" "make clean"
run "Build Go binary" "make build"
run "Verify binary exists" "test -f setup-wizard"

# ============================================================================
# TEST: Go Binary Execution
# ============================================================================

run "Test binary version" "./setup-wizard --version"
run "Test binary help" "./setup-wizard --help"

# ============================================================================
# TEST: Go Setup Wizard Dry Run
# ============================================================================

run "Test dry run mode" "./setup-wizard --dry-run --all"

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  SUMMARY${NC}"
echo -e "${CYAN}============================================${NC}"
echo -e "  ${GREEN}✅ Passed: $PASS${NC}"
echo -e "  ${RED}❌ Failed: $FAIL${NC}"
echo ""

if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}🎉 All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}💥 Some tests failed!${NC}"
  exit 1
fi
