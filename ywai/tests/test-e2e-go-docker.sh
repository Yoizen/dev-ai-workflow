#!/bin/bash
# Complete E2E Test for Go-based Setup Wizard in Docker

set -e

IMAGE="ywai-test"
CYAN='\033[0;36m' GREEN='\033[0;32m' RED='\033[0;31m' YELLOW='\033[1;33m' NC='\033[0m'

TMP_OUT="/tmp/ywai-e2e-go-docker.txt"
rm -f "$TMP_OUT"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  E2E Test: Go Setup Wizard (Docker)${NC}"
echo -e "${CYAN}============================================${NC}\n"

# Build Docker image
docker image inspect "$IMAGE" >/dev/null 2>&1 || {
  echo -e "${YELLOW}Building Docker image...${NC}"
  docker build -t "$IMAGE" -f Dockerfile.test . 2>/dev/null | tail -2
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
  sed -n '1,50p' "$TMP_OUT" | sed 's/^/    /'
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
# TEST 1: Go Build in Docker
# ============================================================================

run "Go build in Docker" "$DOCKER_BASE 'export PATH=\"/usr/local/go/bin:$PATH\" && cd /src/ywai/setup && make clean && make build && test -f setup-wizard && echo \"BUILD_OK\" || (echo \"BUILD_FAILED\" && exit 1)'"

check "Build verified" 'grep -q "BUILD_OK" "$TMP_OUT"'

# ============================================================================
# TEST 2: Go Binary Version
# ============================================================================

run "Binary version check" "$DOCKER_BASE 'cd /src/ywai/setup && ./setup-wizard --version 2>&1 | grep -q \"YWAI Setup Wizard v\" && echo \"VERSION_OK\" || (echo \"VERSION_FAILED\" && exit 1)'"

check "Version verified" 'grep -q "VERSION_OK" "$TMP_OUT"'

# ============================================================================
# TEST 3: Dry Run Mode
# ============================================================================

run "Dry run mode test" "$DOCKER_BASE 'cd /tmp && mkdir test-project && cd test-project && git init >/dev/null 2>&1 && cp -r /src/ywai/setup . && cp -r /src/ywai/config . && cp -r /src/ywai/extensions . && cp -r /src/ywai/types . && cp -r /src/ywai/templates . && cd setup && make build >/dev/null 2>&1 && cd .. && ./setup/setup-wizard --dry-run --all --type=generic 2>&1 | grep -q \"DRY RUN MODE\" && echo \"DRYRUN_OK\" || (echo \"DRYRUN_FAILED\" && exit 1)'"

check "Dry run verified" 'grep -q "DRYRUN_OK" "$TMP_OUT"'

# ============================================================================
# TEST 4: Install Script Wrapper
# ============================================================================

run "Install script wrapper test" "$DOCKER_BASE 'cd /tmp && mkdir test-project && cd test-project && git init >/dev/null 2>&1 && cp -r /src/ywai/setup . && cp -r /src/ywai/config . && cp -r /src/ywai/extensions . && cp -r /src/ywai/types . && cp -r /src/ywai/templates . && cd setup && make build >/dev/null 2>&1 && cd .. && YWAI_SKIP_MCPS=true bash setup/install.sh --dry-run --all --type=generic 2>&1 | grep -q \"DRY RUN MODE\" && echo \"WRAPPER_OK\" || (echo \"WRAPPER_FAILED\" && exit 1)'"

check "Wrapper verified" 'grep -q "WRAPPER_OK" "$TMP_OUT"'

# ============================================================================
# TEST 5: Full Setup Test (no dry-run)
# ============================================================================

run "Full setup test" "$DOCKER_BASE 'cd /tmp && mkdir test-full && cd test-full && git init >/dev/null 2>&1 && cp -r /src/ywai/setup . && cp -r /src/ywai/config . && cp -r /src/ywai/extensions . && cp -r /src/ywai/types . && cp -r /src/ywai/templates . && cd setup && make build >/dev/null 2>&1 && cd .. && YWAI_SKIP_MCPS=true ./setup/setup-wizard --all --type=generic 2>&1 | grep -q \"Setup Complete\" && echo \"FULL_OK\" || (echo \"FULL_FAILED\" && exit 1)'"

check "Full setup verified" 'grep -q "FULL_OK" "$TMP_OUT"'

# ============================================================================
# TEST 6: Project Files Created
# ============================================================================

run "Project files verification" "$DOCKER_BASE 'cd /tmp/test-full && test -f .ga && test -f AGENTS.md && test -f .gitignore && echo \"FILES_OK\" || (echo \"FILES_FAILED\" && exit 1)'"

check "Files verified" 'grep -q "FILES_OK" "$TMP_OUT"'

# ============================================================================
# TEST 7: Multiple Project Types
# ============================================================================

run "Nest project type" "$DOCKER_BASE 'cd /tmp && mkdir test-nest && cd test-nest && git init >/dev/null 2>&1 && cp -r /src/ywai/setup . && cp -r /src/ywai/config . && cp -r /src/ywai/extensions . && cp -r /src/ywai/types . && cp -r /src/ywai/templates . && cd setup && make build >/dev/null 2>&1 && cd .. && YWAI_SKIP_MCPS=true ./setup/setup-wizard --dry-run --all --type=nest 2>&1 | grep -q \"Applying project type: nest\" && echo \"NEST_OK\" || (echo \"NEST_FAILED\" && exit 1)'"

check "Nest type verified" 'grep -q "NEST_OK" "$TMP_OUT"'

run "Python project type" "$DOCKER_BASE 'cd /tmp && mkdir test-python && cd test-python && git init >/dev/null 2>&1 && cp -r /src/ywai/setup . && cp -r /src/ywai/config . && cp -r /src/ywai/extensions . && cp -r /src/ywai/types . && cp -r /src/ywai/templates . && cd setup && make build >/dev/null 2>&1 && cd .. && YWAI_SKIP_MCPS=true ./setup/setup-wizard --dry-run --all --type=python 2>&1 | grep -q \"Applying project type: python\" && echo \"PYTHON_OK\" || (echo \"PYTHON_FAILED\" && exit 1)'"

check "Python type verified" 'grep -q "PYTHON_OK" "$TMP_OUT"'

# ============================================================================
# TEST 8: Error Handling
# ============================================================================

run "Invalid project type" "$DOCKER_BASE 'cd /tmp && mkdir test-invalid && cd test-invalid && git init >/dev/null 2>&1 && cp -r /src/ywai/setup . && cp -r /src/ywai/config . && cp -r /src/ywai/extensions . && cp -r /src/ywai/types . && cp -r /src/ywai/templates . && cd setup && make build >/dev/null 2>&1 && cd .. && ./setup/setup-wizard --dry-run --all --type=invalid-type 2>&1 | grep -q \"Failed to apply project type\" && echo \"ERROR_OK\" || (echo \"ERROR_FAILED\" && exit 1)'"

check "Error handling verified" 'grep -q "ERROR_OK" "$TMP_OUT"'

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
  echo -e "${GREEN}🎉 All Docker E2E tests passed!${NC}"
  exit 0
else
  echo -e "${RED}💥 Some Docker E2E tests failed!${NC}"
  exit 1
fi
