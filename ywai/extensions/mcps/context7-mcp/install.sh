#!/usr/bin/env bash
set -e

TARGET_DIR="${1:-.}"
TARGET_MCP_DIR="$TARGET_DIR/.ywai/mcp"
TARGET_FILE="$TARGET_MCP_DIR/context7-mcp.example.json"

mkdir -p "$TARGET_MCP_DIR"

cat > "$TARGET_FILE" << 'EOF'
{
  "context7": {
    "type": "remote",
    "url": "https://mcp.context7.com/mcp",
    "enabled": true
  }
}
EOF

echo "Created example Context7 MCP config at $TARGET_FILE"
echo "Note: the primary global Context7 MCP is already provisioned by ywai/skills/setup.sh and ywai/config/opencode.json."
