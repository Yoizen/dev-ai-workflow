#!/bin/bash
# ==========================================================================
# E2E Test Suite for ywai/setup/setup.sh
# ==========================================================================

set -u

IMAGE="ywai-test"
CYAN='\033[0;36m' GREEN='\033[0;32m' RED='\033[0;31m' YELLOW='\033[1;33m' NC='\033[0m'

TMP_OUT="/tmp/ywai-e2e-out.txt"
TMP_CHECK="/tmp/ywai-e2e-check.txt"

rm -f "$TMP_OUT" "$TMP_CHECK"

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  E2E Test Suite: ywai/setup/setup.sh${NC}"
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

CONTAINER_HELPERS='
set -e

prepare_assets() {
  local dir="/workspace/assets"
  rm -rf "$dir"
  mkdir -p "$dir"
  cp -r /src/ywai/setup "$dir/"
  cp -r /src/ywai/extensions "$dir/"
  cp -r /src/ywai/skills "$dir/"
  cp -r /src/ywai/commands "$dir/"
  cp -r /src/ywai/config "$dir/"
  printf "%s" "$dir"
}

create_repo() {
  local name="$1"
  local dir="/workspace/repos/${name}"
  rm -rf "$dir"
  mkdir -p "$dir"
  git init "$dir" >/dev/null 2>&1
  printf "%s" "$dir"
}
'

# ============================================================================
# TEST 1: Help
# ============================================================================

run "Help --help" "
$DOCKER_BASE '
$CONTAINER_HELPERS
assets=\$(prepare_assets)
cd "\$assets"
bash setup/setup.sh --help
'"

check "Has USAGE section" 'grep -q "USAGE:" "$TMP_OUT"'
check "Has INSTALLATION OPTIONS" 'grep -q "INSTALLATION OPTIONS" "$TMP_OUT"'
check "Has --extensions" 'grep -q -- "--extensions" "$TMP_OUT"'

# ============================================================================
# TEST 2: List types
# ============================================================================

run "List types --list-types" "
$DOCKER_BASE '
$CONTAINER_HELPERS
assets=\$(prepare_assets)
cd "\$assets"
bash setup/setup.sh --list-types
'"

check "Lists nest" 'grep -q "nest" "$TMP_OUT"'
check "Lists nest-angular" 'grep -q "nest-angular" "$TMP_OUT"'
check "Lists nest-react" 'grep -q "nest-react" "$TMP_OUT"'
check "Lists python" 'grep -q "python" "$TMP_OUT"'
check "Lists dotnet" 'grep -q "dotnet" "$TMP_OUT"'
check "Lists generic" 'grep -q "generic" "$TMP_OUT"'

# ============================================================================
# TEST 3: List extensions
# ============================================================================

run "List extensions --list-extensions" "
$DOCKER_BASE '
$CONTAINER_HELPERS
assets=\$(prepare_assets)
cd "\$assets"
bash setup/setup.sh --list-extensions
'"

check "Lists opencode-command-hooks" 'grep -q "opencode-command-hooks" "$TMP_OUT"'
check "Lists context7-mcp" 'grep -q "context7-mcp" "$TMP_OUT"'
check "Lists github-prompts" 'grep -q "github-prompts" "$TMP_OUT"'
check "Lists engram-setup" 'grep -q "engram-setup" "$TMP_OUT"'

# ============================================================================
# TEST 4: Dry-run
# ============================================================================

run "Dry-run --dry-run --all" "
$DOCKER_BASE '
$CONTAINER_HELPERS
assets=\$(prepare_assets)
repo=\$(create_repo dryrun-repo)
cd "\$assets"
bash setup/setup.sh --dry-run --all --type=generic --target="\$repo"
'"

check "Dry-run mode works" 'grep -q "DRY RUN" "$TMP_OUT"'
check "Would install OpenCode CLI" 'grep -q "Would install OpenCode CLI" "$TMP_OUT"'
check "Would install extensions" 'grep -q "Would install extensions for type" "$TMP_OUT"'

# ============================================================================
# TEST 5: Full installs by type in isolated repos
# ============================================================================

run "Install all supported types" "
$DOCKER_BASE '
$CONTAINER_HELPERS
assets=\$(prepare_assets)

validate_type() {
  local type="\$1"
  local dir
  dir=\$(create_repo "repo-\${type}")
  cd "\$assets"
  bash setup/setup.sh --all --type="\$type" --target="\$dir" >/tmp/install-"\$type".log 2>&1
  cd "\$dir"

  test -f AGENTS.md
  test -f REVIEW.md
  test -f .ga
  test -f .github/prompts/compare-specs.prompt.md
  test -f .github/prompts/reverse-engineer.prompt.md
  test -f .ywai/mcp/context7-mcp.example.json
  test -f .ywai/engram/status.txt
  command -v opencode >/dev/null 2>&1

  case "\$type" in
    nest)
      test -f biome.json
      test -d skills/typescript
      test -d skills/git-commit
      ;;
    nest-angular)
      test -f biome.json
      test -d skills/typescript
      test -d skills/angular
      test -d skills/tailwind-4
      ;;
    nest-react)
      test -f biome.json
      test -d skills/typescript
      test -d skills/react-19
      test -d skills/tailwind-4
      ;;
    python)
      test ! -f biome.json
      ;;
    dotnet)
      test ! -f biome.json
      test -d skills/dotnet
      ;;
    generic)
      test ! -f biome.json
      ;;
  esac

  echo "TYPE_OK:\$type"
}

validate_type nest
validate_type nest-angular
validate_type nest-react
validate_type python
validate_type dotnet
validate_type generic
'"

check "Nest install ok" 'grep -q "TYPE_OK:nest" "$TMP_OUT"'
check "Nest Angular install ok" 'grep -q "TYPE_OK:nest-angular" "$TMP_OUT"'
check "Nest React install ok" 'grep -q "TYPE_OK:nest-react" "$TMP_OUT"'
check "Python install ok" 'grep -q "TYPE_OK:python" "$TMP_OUT"'
check "Dotnet install ok" 'grep -q "TYPE_OK:dotnet" "$TMP_OUT"'
check "Generic install ok" 'grep -q "TYPE_OK:generic" "$TMP_OUT"'

# ============================================================================
# TEST 6: Provider selection
# ============================================================================

run "Provider --provider=claude" "
$DOCKER_BASE '
$CONTAINER_HELPERS
assets=\$(prepare_assets)
repo=\$(create_repo provider-repo)
cd "\$assets"
bash setup/setup.sh --skip-sdd --skip-vscode --provider=claude --target="\$repo"
'"

check "Provider claude applied" 'grep -q "Provider set to: claude" "$TMP_OUT"'

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
