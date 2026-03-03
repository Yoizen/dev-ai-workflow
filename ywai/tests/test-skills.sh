#!/bin/bash
# Test Skills Installation

set -e

IMAGE="ywai-test"
CYAN='\033[0;36m' GREEN='\033[0;32m' RED='\033[0;31m' NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Test: Skills Installation${NC}"
echo -e "${CYAN}============================================${NC}\n"

docker image inspect "$IMAGE" >/dev/null 2>&1 || {
  echo -e "${YELLOW}Building Docker image...${NC}"
  docker build -t "$IMAGE" -f ywai/tests/Dockerfile.test . 2>/dev/null | tail -2
}

echo -e "${GREEN}✅ Image ready${NC}\n"

# Test in Docker
docker run --rm -v "$(pwd):/src" "$IMAGE" bash -c '
set -e
echo "Testing skills installation..."

# Create test repo
mkdir -p /tmp/test-repo
cd /tmp/test-repo
git init >/dev/null 2>&1

# Copy setup assets
cp -r /src/ywai/setup /tmp/test-repo/
cp -r /src/ywai/skills /tmp/test-repo/
cp -r /src/ywai/commands /tmp/test-repo/
cp -r /src/ywai/config /tmp/test-repo/

# Run setup for different types
for type in nest nest-angular nest-react python dotnet generic; do
  echo "Testing $type skills..."
  
  # Clean and recreate
  rm -rf /tmp/test-repo-$type
  mkdir -p /tmp/test-repo-$type
  cd /tmp/test-repo-$type
  git init >/dev/null 2>&1
  
  # Copy assets
  cp -r /src/ywai/setup /tmp/test-repo-$type/
  cp -r /src/ywai/skills /tmp/test-repo-$type/
  cp -r /src/ywai/commands /tmp/test-repo-$type/
  cp -r /src/ywai/config /tmp/test-repo-$type/
  
  # Run setup
  bash setup/setup.sh --all --type=$type --target=. >/tmp/setup-$type.log 2>&1
  
  # Check skills directory exists
  test -d skills || { echo "❌ $type: skills directory missing"; exit 1; }
  
  case $type in
    nest)
      test -d skills/biome || { echo "❌ $type: biome skill missing"; exit 1; }
      test -d skills/typescript || { echo "❌ $type: typescript skill missing"; exit 1; }
      test -f skills/biome/SKILL.md || { echo "❌ $type: biome SKILL.md missing"; exit 1; }
      ;;
    nest-angular)
      test -d skills/angular || { echo "❌ $type: angular skill missing"; exit 1; }
      test -d skills/tailwind-4 || { echo "❌ $type: tailwind-4 skill missing"; exit 1; }
      test -f skills/angular/core/SKILL.md || { echo "❌ $type: angular core SKILL.md missing"; exit 1; }
      ;;
    nest-react)
      test -d skills/react-19 || { echo "❌ $type: react-19 skill missing"; exit 1; }
      test -d skills/tailwind-4 || { echo "❌ $type: tailwind-4 skill missing"; exit 1; }
      test -f skills/react-19/SKILL.md || { echo "❌ $type: react-19 SKILL.md missing"; exit 1; }
      ;;
    python)
      test -d skills/git-commit || { echo "❌ $type: git-commit skill missing"; exit 1; }
      test -f skills/git-commit/SKILL.md || { echo "❌ $type: git-commit SKILL.md missing"; exit 1; }
      ;;
    dotnet)
      test -d skills/dotnet || { echo "❌ $type: dotnet skill missing"; exit 1; }
      test -f skills/dotnet/SKILL.md || { echo "❌ $type: dotnet SKILL.md missing"; exit 1; }
      ;;
    generic)
      test -d skills/git-commit || { echo "❌ $type: git-commit skill missing"; exit 1; }
      test -f skills/git-commit/SKILL.md || { echo "❌ $type: git-commit SKILL.md missing"; exit 1; }
      ;;
  esac
  
  echo "✅ $type skills OK"
done

echo "🎉 ALL SKILLS TESTS PASSED"
'

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Skills installation test PASSED${NC}"
  exit 0
else
  echo -e "${RED}❌ Skills installation test FAILED${NC}"
  exit 1
fi
