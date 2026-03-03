#!/bin/bash
# Test GA Installation

set -e

IMAGE="ywai-test"
CYAN='\033[0;36m' GREEN='\033[0;32m' RED='\033[0;31m' NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Test: GA Installation${NC}"
echo -e "${CYAN}============================================${NC}\n"

docker image inspect "$IMAGE" >/dev/null 2>&1 || {
  echo -e "${YELLOW}Building Docker image...${NC}"
  docker build -t "$IMAGE" -f ywai/tests/Dockerfile.test . 2>/dev/null | tail -2
}

echo -e "${GREEN}✅ Image ready${NC}\n"

# Test in Docker
docker run --rm -v $(pwd):/src $IMAGE bash -c '
set -e
echo "Testing GA installation..."

# Create test repo
mkdir -p /tmp/test-repo
cd /tmp/test-repo
git init >/dev/null 2>&1

# Copy setup assets
cp -r /src/ywai/setup /tmp/test-repo/
cp -r /src/ywai/skills /tmp/test-repo/
cp -r /src/ywai/commands /tmp/test-repo/
cp -r /src/ywai/config /tmp/test-repo/

# Run setup
cd /tmp/test-repo
bash setup/setup.sh --all --type=nest --target=. >/tmp/setup.log 2>&1

# Check GA configuration
echo "Checking GA config..."
test -f .ga || { echo "❌ .ga config missing"; exit 1; }
grep -q "PROVIDER=" .ga || { echo "❌ PROVIDER missing"; exit 1; }
grep -q "FILE_PATTERNS=" .ga || { echo "❌ FILE_PATTERNS missing"; exit 1; }
echo "✅ GA configuration exists"

# Check git hooks directory
echo "Checking git hooks..."
test -d .git/hooks || { echo "❌ git hooks directory missing"; exit 1; }
test -f .git/hooks/pre-commit || { echo "❌ pre-commit hook missing"; exit 1; }
test -x .git/hooks/pre-commit || { echo "❌ pre-commit hook not executable"; exit 1; }
echo "✅ Git hooks installed"

# Check GA hook content
echo "Checking GA hook content..."
grep -q "Guardian Agent" .git/hooks/pre-commit || { echo "❌ GA hook content missing"; exit 1; }
grep -q "ga run" .git/hooks/pre-commit || { echo "❌ ga run command missing"; exit 1; }
echo "✅ GA hook content valid"

echo "🎉 ALL GA TESTS PASSED"
'

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ GA installation test PASSED${NC}"
  exit 0
else
  echo -e "${RED}❌ GA installation test FAILED${NC}"
  exit 1
fi
