#!/bin/bash
# E2E Test for Go-based Setup Wizard

set -e

IMAGE="ywai-test"
CYAN='\033[0;36m' GREEN='\033[0;32m' RED='\033[0;31m' YELLOW='\033[1;33m' NC='\033[0m'

TMP_OUT="/tmp/ywai-e2e-go.txt"
rm -f "$TMP_OUT"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  E2E Test: Go Setup Wizard${NC}"
echo -e "${CYAN}============================================${NC}\n"

docker image inspect "$IMAGE" >/dev/null 2>&1 || {
  echo -e "${YELLOW}Building Docker image...${NC}"
  docker build -t "$IMAGE" -f ywai/tests/Dockerfile.test . 2>/dev/null | tail -2
}

echo -e "${GREEN}✅ Image ready${NC}\n"

PASS=0
FAIL=0

run() {
  local name="$1"
  local cmd="$2"
  echo -e "${YELLOW}▶ $name${NC}"
  if eval "$cmd" > "$TMP_OUT" 2>&1; then
    echo -e "  ${GREEN}✅ PASS${NC}"
    ((PASS++)) || true
    return 0
  fi
  echo -e "  ${RED}❌ FAIL${NC}"
  sed -n '1,80p' "$TMP_OUT" | sed 's/^/    /'
  ((FAIL++)) || true
  return 1
}

check() {
  local name="$1"
  local cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    echo -e "  ${GREEN}  ✅ $name${NC}"
    ((PASS++)) || true
  else
    echo -e "  ${RED}  ❌ $name${NC}"
    ((FAIL++)) || true
  fi
}

DOCKER_BASE="docker run --rm -i -v $(pwd):/src $IMAGE bash -lc"

# ============================================================================
# TEST: Go Build
# ============================================================================

run "Go build verification" "$DOCKER_BASE 'cd /src/ywai/setup && make clean && make build && test -f setup-wizard && echo \"BUILD_OK\" || (echo \"BUILD_FAILED\" && exit 1)'"

check "Build verified" 'grep -q "BUILD_OK" "$TMP_OUT"'

# ============================================================================
# TEST: Go Binary Execution
# ============================================================================

run "Go binary execution" "$DOCKER_BASE 'cd /src/ywai/setup && ./setup-wizard --version >/dev/null 2>&1 && echo \"BINARY_OK\" || (echo \"BINARY_FAILED\" && exit 1)'"

check "Binary execution verified" 'grep -q "BINARY_OK" "$TMP_OUT"'

# ============================================================================
# TEST: Go Setup Wizard Dry Run
# ============================================================================

run "Setup wizard dry run" "$DOCKER_BASE 'echo \"Testing setup wizard...\" && mkdir -p /tmp/test-repo && cd /tmp/test-repo && git init >/dev/null 2>&1 && cp -r /src/ywai/setup /tmp/test-repo/ && cp -r /src/ywai/config /tmp/test-repo/ && cp -r /src/ywai/extensions /tmp/test-repo/ && cp -r /src/ywai/types /tmp/test-repo/ && cp -r /src/ywai/templates /tmp/test-repo/ && cd setup && make build >/dev/null 2>&1 && cd /tmp/test-repo && YWAI_SKIP_MCPS=true ./setup/setup-wizard --dry-run --install-sdd --type=generic --target=. >/tmp/setup.log 2>&1 && (grep -q \"DRY RUN MODE\" /tmp/test-repo/setup.log && grep -q \"Setup Complete\" /tmp/test-repo/setup.log && echo \"DRYRUN_OK\" || (echo \"DRYRUN_FAILED\" && cat /tmp/test-repo/setup.log && exit 1))'"

check "Dry run verified" 'grep -q "DRYRUN_OK" "$TMP_OUT"'

# ============================================================================
# TEST: Install Script Wrapper
# ============================================================================

run "Install script wrapper" "$DOCKER_BASE 'echo \"Testing install script...\" && mkdir -p /tmp/test-repo && cd /tmp/test-repo && git init >/dev/null 2>&1 && cp -r /src/ywai/setup /tmp/test-repo/ && cp -r /src/ywai/config /tmp/test-repo/ && cp -r /src/ywai/extensions /tmp/test-repo/ && cp -r /src/ywai/types /tmp/test-repo/ && cp -r /src/ywai/templates /tmp/test-repo/ && cd setup && make build >/dev/null 2>&1 && cd /tmp/test-repo && YWAI_SKIP_MCPS=true bash setup/install.sh --dry-run --install-sdd --type=generic --target=. >/tmp/setup.log 2>&1 && (grep -q \"DRY RUN MODE\" /tmp/test-repo/setup.log && echo \"WRAPPER_OK\" || (echo \"WRAPPER_FAILED\" && cat /tmp/test-repo/setup.log && exit 1))'"

check "Install script verified" 'grep -q "WRAPPER_OK" "$TMP_OUT"'

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
