#!/usr/bin/env bash
# Test suite for sync.sh registry extractor

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"
SYNC_SCRIPT="$REPO_ROOT/skills/skill-sync/assets/sync.sh"
TEST_DIR="$REPO_ROOT/.test_sync_registry"

# Cleanup function
cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Test helper
test_extract_rules() {
    local name="$1"
    local content="$2"
    local expected_lines="$3"
    
    local test_file="$TEST_DIR/$name.md"
    mkdir -p "$TEST_DIR"
    echo "$content" > "$test_file"
    
    local result
    result=$(bash -c "source '$SYNC_SCRIPT'; extract_rules '$test_file'")
    local line_count=$(echo "$result" | grep -c "^-" || true)
    
    if [ "$line_count" -ne "$expected_lines" ]; then
        echo "FAIL: $name - expected $expected_lines lines, got $line_count"
        echo "Content:"
        echo "$result"
        return 1
    fi
    
    echo "PASS: $name"
    return 0
}

echo "Testing sync.sh registry extractor..."
echo ""

# Test 1: Extract from Critical Patterns section
test_extract_rules "critical_patterns" '
---
name: test-skill
version: 1.0.0
---

## Critical Patterns
- Always use TypeScript strict mode
- Never use any type
- Prefer const over let
- Use async/await instead of promises
' 4

# Test 2: Extract from Rules section
test_extract_rules "rules_section" '
---
name: test-skill
---

## Rules
- Rule 1
- Rule 2
- Rule 3
' 3

# Test 3: Extract from first bullet list if no named section
test_extract_rules "fallback_bullets" '
---
name: test-skill
---

Some description

- Bullet 1
- Bullet 2
' 2

# Test 4: Truncate long lines
test_extract_rules "truncate_long" '
---
name: test-skill
---

## Critical Patterns
- This is a very long line that should be truncated to 160 characters to prevent the skill registry from becoming too large and consuming too many tokens in the prompt context
' 1

# Test 5: Max 15 bullets
test_extract_rules "max_bullets" '
---
name: test-skill
---

## Critical Patterns
- Bullet 1
- Bullet 2
- Bullet 3
- Bullet 4
- Bullet 5
- Bullet 6
- Bullet 7
- Bullet 8
- Bullet 9
- Bullet 10
- Bullet 11
- Bullet 12
- Bullet 13
- Bullet 14
- Bullet 15
- Bullet 16
- Bullet 17
- Bullet 18
- Bullet 19
- Bullet 20
' 15

# Test 6: Extract triggers
test_extract_triggers() {
    echo "Testing extract_triggers..."
    local test_file="$TEST_DIR/triggers.md"
    cat > "$test_file" << 'EOF'
---
name: test-skill
description: Test skill with triggers: "*.ts", "*.tsx", "refactor TypeScript"
version: 1.0.0
---
EOF

    local result
    result=$(bash -c "source '$SYNC_SCRIPT'; extract_triggers '$test_file'")
    if [[ "$result" == *"*.ts"* ]] && [[ "$result" == *"*.tsx"* ]]; then
        echo "PASS: extract_triggers"
    else
        echo "FAIL: extract_triggers - got: $result"
    fi
}
test_extract_triggers

# Test 7: Extract name
test_get_name() {
    echo "Testing get_name..."
    local test_file="$TEST_DIR/name.md"
    cat > "$test_file" << 'EOF'
---
name: my-test-skill
version: 1.0.0
---
EOF

    local result
    result=$(bash -c "source '$SYNC_SCRIPT'; get_name '$test_file'")
    if [ "$result" = "my-test-skill" ]; then
        echo "PASS: get_name"
    else
        echo "FAIL: get_name - expected 'my-test-skill', got '$result'"
    fi
}
test_get_name

# Test 8: Extract scopes
test_get_scopes() {
    echo "Testing get_scopes..."
    local test_file="$TEST_DIR/scopes.md"
    cat > "$test_file" << 'EOF'
---
scope: [root, subagent]
version: 1.0.0
---
EOF

    local result
    result=$(bash -c "source '$SYNC_SCRIPT'; get_scopes '$test_file'")
    if [[ "$result" == *"root"* ]] && [[ "$result" == *"subagent"* ]]; then
        echo "PASS: get_scopes"
    else
        echo "FAIL: get_scopes - got: $result"
    fi
}
test_get_scopes

echo ""
echo "All tests passed!"
