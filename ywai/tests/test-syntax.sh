#!/bin/bash
# Syntax Test for Setup Scripts

set -e

GREEN='\033[0;32m' RED='\033[0;31m' YELLOW='\033[1;33m' NC='\033[0m'

echo -e "${YELLOW}Testing setup script syntax...${NC}"

# Test setup script syntax
if bash -n ywai/setup/setup.sh 2>/dev/null; then
  echo -e "${GREEN}✅ setup.sh syntax OK${NC}"
else
  echo -e "${RED}❌ setup.sh syntax ERROR${NC}"
  bash -n ywai/setup/setup.sh
  exit 1
fi

# Test library scripts syntax
for script in ywai/setup/lib/*.sh; do
  if bash -n "$script" 2>/dev/null; then
    echo -e "${GREEN}✅ $(basename "$script") syntax OK${NC}"
  else
    echo -e "${RED}❌ $(basename "$script") syntax ERROR${NC}"
    bash -n "$script"
    exit 1
  fi
done

# Test extension scripts syntax
for script in ywai/extensions/install-steps/*/*.sh; do
  if [[ -f "$script" ]]; then
    if bash -n "$script" 2>/dev/null; then
      echo -e "${GREEN}✅ $(basename "$script") syntax OK${NC}"
    else
      echo -e "${RED}❌ $(basename "$script") syntax ERROR${NC}"
      bash -n "$script"
      exit 1
    fi
  fi
done

echo -e "${GREEN}🎉 ALL SYNTAX TESTS PASSED${NC}"
