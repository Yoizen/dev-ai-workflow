# YWAI Setup - Go Build System
# Compiles setup wizard for multiple platforms

.PHONY: build clean test release install help

# Configuration
BINARY_NAME=setup-wizard
VERSION=$(shell git describe --tags --always --dirty 2>/dev/null || echo "dev")
LDFLAGS=-ldflags "-X main.version=${VERSION}"

# Platforms
PLATFORMS=linux-amd64 linux-arm64 darwin-amd64 darwin-arm64 windows-amd64

# Default target
help:
	@echo "YWAI Setup - Build System"
	@echo "========================"
	@echo ""
	@echo "Available targets:"
	@echo "  build      - Build for current platform"
	@echo "  build-all  - Build for all platforms"
	@echo "  test       - Run tests"
	@echo "  clean      - Clean build artifacts"
	@echo "  release    - Build release binaries"
	@echo "  install    - Install locally"
	@echo "  help       - Show this help"

# Build for current platform
build:
	@echo "🔨 Building ${BINARY_NAME} for current platform..."
	cd wizard && go build ${LDFLAGS} -o ../${BINARY_NAME} ./cmd
	@echo "✅ Built ${BINARY_NAME}"

# Build for all platforms
build-all:
	@echo "🔨 Building ${BINARY_NAME} for all platforms..."
	@mkdir -p dist
	@$(foreach platform,$(PLATFORMS), \
		echo "Building for $(platform)..."; \
		( cd wizard && GOOS=$(word 1,$(subst -, ,$(platform))) GOARCH=$(word 2,$(subst -, ,$(platform))) \
		go build ${LDFLAGS} -o ../dist/${BINARY_NAME}-$(platform)$$( [ "$(word 1,$(subst -, ,$(platform)))" = "windows" ] && echo ".exe" ) ./cmd ); \
	)
	@echo "✅ All binaries built in dist/"

# Run tests
test:
	@echo "🧪 Running tests..."
	cd wizard && go test ./...
	@echo "✅ All tests passed"

# Clean build artifacts
clean:
	@echo "🧹 Cleaning..."
	rm -f ${BINARY_NAME}
	rm -rf dist
	@echo "✅ Cleaned"

# Build release binaries
release: clean test build-all
	@echo "📦 Creating release packages..."
	@cd dist && \
	$(foreach platform,$(PLATFORMS), \
		echo "Packaging $(platform)..."; \
		tar -czf ${BINARY_NAME}-$(platform).tar.gz ${BINARY_NAME}-$(platform)$$( [ "$(word 1,$(subst -, ,$(platform)))" = "windows" ] && echo ".exe" ); \
	)
	@echo "✅ Release packages ready in dist/"

# Install locally
install: build
	@echo "📦 Installing locally..."
	@mkdir -p ${HOME}/.local/bin
	@cp ${BINARY_NAME} ${HOME}/.local/bin/
	@echo "✅ Installed to ${HOME}/.local/bin/${BINARY_NAME}"

# Development build with race detection
dev:
	@echo "🔨 Building with race detection..."
	cd wizard && go build -race ${LDFLAGS} -o ../${BINARY_NAME}-dev ./cmd
	@echo "✅ Built ${BINARY_NAME}-dev"

# Build with version info
version:
	@echo "Building version ${VERSION}..."
	cd wizard && go build ${LDFLAGS} -o ../${BINARY_NAME}-${VERSION} ./cmd
	@echo "✅ Built ${BINARY_NAME}-${VERSION}"
