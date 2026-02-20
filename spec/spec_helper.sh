# shellcheck shell=bash

# Spec helper - Common setup for all tests

# Set strict mode
set -eu

# Get the project root directory
PROJECT_ROOT="$(cd "$(dirname "$SHELLSPEC_SPECDIR")" && pwd)"

# Source the library files
export LIB_DIR="$PROJECT_ROOT/lib"

# Create a temporary directory for tests
setup_temp_dir() {
  TEMP_DIR=$(mktemp -d)
  export TEMP_DIR
  cd "$TEMP_DIR" || exit 1
}

# Cleanup temporary directory
cleanup_temp_dir() {
  if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
    rm -rf "$TEMP_DIR"
  fi
}

# Initialize a git repo in temp directory
init_git_repo() {
  git init --quiet
  git config user.email "test@test.com"
  git config user.name "Test User"
}

# Create a test file and stage it
create_and_stage_file() {
  local filename="$1"
  local content="${2:-test content}"
  echo "$content" > "$filename"
  git add "$filename"
}

# Create a minimal .gga config
create_test_config() {
  cat > .gga << 'EOF'
PROVIDER="mock"
FILE_PATTERNS="*.ts,*.tsx,*.js"
EXCLUDE_PATTERNS="*.test.ts"
RULES_FILE="REVIEW.md"
STRICT_MODE="true"
EOF
}

# Create a minimal REVIEW.md
create_test_rules() {
  cat > REVIEW.md << 'EOF'
# Test Rules
- No console.log
- Use const over let
EOF
}

# Mock the provider execution
mock_provider_pass() {
  echo "STATUS: PASSED"
  echo "All files comply with standards."
}

mock_provider_fail() {
  echo "STATUS: FAILED"
  echo "Violations found:"
  echo "- test.ts:1 - Rule violated"
}

# Export functions
export -f setup_temp_dir
export -f cleanup_temp_dir
export -f init_git_repo
export -f create_and_stage_file
export -f create_test_config
export -f create_test_rules
export -f mock_provider_pass
export -f mock_provider_fail
