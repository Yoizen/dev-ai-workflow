#!/bin/bash
# Simple E2E Test for Commands Installation

set -e

IMAGE="ywai-test"
CYAN='\033[0;36m' GREEN='\033[0;32m' RED='\033[0;31m' YELLOW='\033[1;33m' NC='\033[0m'

TMP_OUT="/tmp/ywai-e2e-simple.txt"
rm -f "$TMP_OUT"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Simple E2E Test: Commands Installation${NC}"
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
# TEST: Commands Installation
# ============================================================================

run "Commands installation verification" "$DOCKER_BASE 'echo \"Testing setup...\" && mkdir -p /tmp/test-repo && cd /tmp/test-repo && git init >/dev/null 2>&1 && cp -r /src/ywai/setup /tmp/test-repo/ && cp -r /src/ywai/config /tmp/test-repo/ && cp -r /src/ywai/extensions /tmp/test-repo/ && YWAI_SKIP_MCPS=true bash setup/setup.sh --install-sdd --type=generic --target=. >/tmp/setup.log 2>&1 && (grep -q \"Project configured\" /tmp/test-repo/setup.log && echo \"SETUP_OK\" || (echo \"SETUP_FAILED\" && cat /tmp/test-repo/setup.log && exit 1))'"

check "Setup verified" 'grep -q "SETUP_OK" "$TMP_OUT"'

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  SUMMARY${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "${GREEN}Passed: $PASS${NC}"
echo -e "${RED}Failed: $FAIL${NC}"
echo ""

if [[ $FAIL -eq 0 ]]; then
  echo -e "${GREEN}🎉 ALL TESTS PASSED${NC}"
  exit 0
else
  echo -e "${YELLOW}⚠️  Some tests need review${NC}"
  exit 1
fi
