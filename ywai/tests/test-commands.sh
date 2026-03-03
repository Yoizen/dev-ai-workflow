#!/bin/bash
# Test Commands Installation

set -e

IMAGE="ywai-test"
CYAN='\033[0;36m' GREEN='\033[0;32m' RED='\033[0;31m' NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Test: Commands Installation${NC}"
echo -e "${CYAN}============================================${NC}\n"

docker image inspect "$IMAGE" >/dev/null 2>&1 || {
  echo -e "${YELLOW}Building Docker image...${NC}"
  docker build -t "$IMAGE" -f ywai/tests/Dockerfile.test . 2>/dev/null | tail -2
}

echo -e "${GREEN}✅ Image ready${NC}\n"

# Test in Docker
docker run --rm -v "$(pwd):/src" "$IMAGE" bash -c '
set -e
echo "Testing commands installation..."

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

# Check commands directory exists
echo "Checking commands directory..."
test -d ~/.config/opencode/commands || { echo "❌ Commands directory missing"; exit 1; }
echo "✅ Commands directory exists"

# Check SDD commands exist
echo "Checking SDD commands..."
test -f ~/.config/opencode/commands/sdd-init.md || { echo "❌ sdd-init.md missing"; exit 1; }
test -f ~/.config/opencode/commands/sdd-new.md || { echo "❌ sdd-new.md missing"; exit 1; }
test -f ~/.config/opencode/commands/sdd-ff.md || { echo "❌ sdd-ff.md missing"; exit 1; }
test -f ~/.config/opencode/commands/sdd-apply.md || { echo "❌ sdd-apply.md missing"; exit 1; }
test -f ~/.config/opencode/commands/sdd-verify.md || { echo "❌ sdd-verify.md missing"; exit 1; }
test -f ~/.config/opencode/commands/sdd-archive.md || { echo "❌ sdd-archive.md missing"; exit 1; }
test -f ~/.config/opencode/commands/sdd-continue.md || { echo "❌ sdd-continue.md missing"; exit 1; }
test -f ~/.config/opencode/commands/sdd-explore.md || { echo "❌ sdd-explore.md missing"; exit 1; }
echo "✅ All SDD commands exist"

# Check command content structure
echo "Checking command content..."
grep -q "description:" ~/.config/opencode/commands/sdd-init.md || { echo "❌ sdd-init.md missing description"; exit 1; }
grep -q "agent: sdd-orchestrator" ~/.config/opencode/commands/sdd-init.md || { echo "❌ sdd-init.md missing agent"; exit 1; }
grep -q "WORKFLOW:" ~/.config/opencode/commands/sdd-apply.md || { echo "❌ sdd-apply.md missing workflow"; exit 1; }
echo "✅ Command content structure valid"

echo "🎉 ALL COMMANDS TESTS PASSED"
'

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Commands installation test PASSED${NC}"
  exit 0
else
  echo -e "${RED}❌ Commands installation test FAILED${NC}"
  exit 1
fi
