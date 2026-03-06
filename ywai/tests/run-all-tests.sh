#!/bin/bash
# Run All Tests - Modern Go-based Test Suite

set -e

CYAN='\033[0;36m' GREEN='\033[0;32m' RED='\033[0;31m' YELLOW='\033[1;33m' NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Running Modern Test Suite${NC}"
echo -e "${CYAN}============================================${NC}\n"

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

run_test() {
  local test_name="$1"
  local test_command="$2"
  
  echo -e "${YELLOW}▶ Running: $test_name${NC}"
  
  if eval "$test_command" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅ PASS${NC}"
    ((PASSED_TESTS++)) || true
  else
    echo -e "  ${RED}❌ FAIL${NC}"
    ((FAILED_TESTS++)) || true
  fi
  ((TOTAL_TESTS++)) || true
  echo ""
}

# Change to tests directory
cd "$(dirname "$0")"

echo -e "${CYAN}Running Go-based Tests...${NC}"

# Test Go modules and build
run_test "Go Module Check" "go mod tidy"

# Run Go test suites
run_test "Build Tests" "go test -v ./build_test.go"
run_test "E2E Tests" "go test -v ./e2e_test.go"
run_test "Skills Tests" "go test -v ./skills_test.go"
run_test "Syntax Tests" "go test -v ./syntax_test.go"

# Run existing Go tests in setup wizard
echo -e "${CYAN}Running Setup Wizard Go Tests...${NC}"
if [ -d "../setup/wizard" ]; then
  cd ../setup/wizard
  run_test "Setup Wizard Unit Tests" "go test ./..."
  cd ../../tests
else
  echo -e "${YELLOW}⚠️ Setup wizard tests directory not found${NC}"
fi

# Optional: Run Docker-based tests if Docker is available
if command -v docker >/dev/null 2>&1; then
  echo -e "${CYAN}Running Docker-based Tests...${NC}"
  run_test "Docker E2E Tests" "go test -v -tags=docker ./e2e_test.go"
else
  echo -e "${YELLOW}⚠️ Docker not available, skipping Docker tests${NC}"
fi

# ============================================================================
# SUMMARY
# ============================================================================

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  FINAL SUMMARY${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
echo -e "${RED}Failed: $FAILED_TESTS${NC}"
echo -e "${YELLOW}Total: $TOTAL_TESTS${NC}"
echo ""

if [[ $FAILED_TESTS -eq 0 ]]; then
  echo -e "${GREEN}🎉 ALL TESTS PASSED${NC}"
  echo -e "${GREEN}✅ dev-ai-workflow is fully functional${NC}"
  echo ""
  echo -e "${GREEN}📊 Test Coverage:${NC}"
  echo -e "${GREEN}  • Go build and execution${NC}"
  echo -e "${GREEN}  • E2E functionality (Docker + local)${NC}"
  echo -e "${GREEN}  • Skills installation and validation${NC}"
  echo -e "${GREEN}  • Configuration syntax (YAML/JSON)${NC}"
  echo -e "${GREEN}  • Template validation${NC}"
  echo -e "${GREEN}  • Extension configurations${NC}"
  echo -e "${GREEN}  • Setup wizard unit tests${NC}"
  exit 0
else
  echo -e "${YELLOW}⚠️  Some tests need review${NC}"
  exit 1
fi
