#!/bin/bash
# Test MCP Configuration

set -e

IMAGE="ywai-test"
CYAN='\033[0;36m' GREEN='\033[0;32m' RED='\033[0;31m' NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Test: MCP Configuration${NC}"
echo -e "${CYAN}============================================${NC}\n"

docker image inspect "$IMAGE" >/dev/null 2>&1 || {
  echo -e "${YELLOW}Building Docker image...${NC}"
  docker build -t "$IMAGE" -f ywai/tests/Dockerfile.test . 2>/dev/null | tail -2
}

echo -e "${GREEN}✅ Image ready${NC}\n"

# Test in Docker
docker run --rm -v "$(pwd):/src" "$IMAGE" bash -c '
set -e
echo "Testing MCP configuration..."

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
bash setup/setup.sh --all --type=generic --target=. >/tmp/setup.log 2>&1

# Check MCP configuration exists
echo "Checking opencode.json..."
test -f ~/.config/opencode/opencode.json || { echo "❌ opencode.json missing"; exit 1; }
echo "✅ opencode.json exists"

echo "Checking MCP example..."
test -f .ywai/mcp/context7-mcp.example.json || { echo "❌ context7-mcp.example.json missing"; exit 1; }
echo "✅ MCP example exists"

# Check MCP servers in opencode.json
echo "Checking MCP servers..."
grep -q "engram" ~/.config/opencode/opencode.json || { echo "❌ engram server missing"; exit 1; }
grep -q "context7" ~/.config/opencode/opencode.json || { echo "❌ context7 server missing"; exit 1; }
grep -q "enabled.*true" ~/.config/opencode/opencode.json || { echo "❌ servers not enabled"; exit 1; }
echo "✅ MCP servers configured"

# Check Engram local command
echo "Checking Engram command..."
grep -q "command.*engram.*mcp" ~/.config/opencode/opencode.json || { echo "❌ engram command missing"; exit 1; }
echo "✅ Engram command configured"

# Check Context7 remote URL
echo "Checking Context7 URL..."
grep -q "https://mcp.context7.com/mcp" ~/.config/opencode/opencode.json || { echo "❌ context7 URL missing"; exit 1; }
echo "✅ Context7 URL configured"

echo "🎉 ALL MCP TESTS PASSED"
'

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ MCP configuration test PASSED${NC}"
  exit 0
else
  echo -e "${RED}❌ MCP configuration test FAILED${NC}"
  exit 1
fi
