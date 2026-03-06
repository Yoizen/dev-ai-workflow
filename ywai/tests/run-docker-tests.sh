#!/bin/bash
# Docker Test Runner - Ejecuta tests dentro de Docker

set -e

CYAN='\033[0;36m' GREEN='\033[0;32m' RED='\033[0;31m' YELLOW='\033[1;33m' NC='\033[0m'

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Running Tests in Docker${NC}"
echo -e "${CYAN}============================================${NC}\n"

# Build Docker image
echo -e "${YELLOW}Building Docker image...${NC}"
docker build -t ywai-test -f ywai/tests/Dockerfile.test .

# Run tests in Docker
echo -e "${CYAN}Running build tests...${NC}"
docker run --rm -i -v $(pwd):/src ywai-test bash -lc "export PATH=\"/usr/local/go/bin:\$PATH\" && cd /src/ywai/tests && go test -v ./build_test.go"

echo -e "${CYAN}Running syntax tests...${NC}"
docker run --rm -i -v $(pwd):/src ywai-test bash -lc "export PATH=\"/usr/local/go/bin:\$PATH\" && cd /src/ywai/tests && go test -v ./syntax_test.go"

echo -e "${CYAN}Running skills tests...${NC}"
docker run --rm -i -v $(pwd):/src ywai-test bash -lc "export PATH=\"/usr/local/go/bin:\$PATH\" && cd /src/ywai/tests && go test -v ./skills_test.go"

echo -e "${GREEN}✅ Docker tests completed!${NC}"
