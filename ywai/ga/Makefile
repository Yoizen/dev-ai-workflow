.PHONY: build build-all test lint clean install help release

# Binary name
BINARY=ga

# Go settings
GO=go
COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo dev)
DATE ?= $(shell date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)
GOFLAGS=-ldflags="-s -w -X=github.com/yoizen/ga/internal/version.Version=$(VERSION) -X=github.com/yoizen/ga/internal/version.Commit=$(COMMIT) -X=github.com/yoizen/ga/internal/version.Date=$(DATE)"

# Version (can be overridden)
VERSION ?= dev

# Default target
help:
	@echo "Guardian Agent (Go) - Development Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Development:"
	@echo "  build         Build binary for current platform"
	@echo "  build-all     Build binaries for all platforms (macOS, Linux, Windows)"
	@echo "  test          Run tests"
	@echo "  lint          Run go vet"
	@echo "  clean         Clean build artifacts"
	@echo "  install       Install binary to ~/.local/bin"
	@echo ""
	@echo "Release:"
	@echo "  release       Create release for current platform"
	@echo "  release-all   Create releases for all platforms"
	@echo ""

# Build binary for current platform
build:
	@echo "Building $(BINARY) for $(GOOS)/$(GOARCH)..."
	$(GO) build $(GOFLAGS) -o bin/$(BINARY) ./cmd/ga
	@echo "✅ Built bin/$(BINARY)"

# Build for all platforms
build-all: build-darwin-amd64 build-darwin-arm64 build-linux-amd64 build-linux-arm64 build-windows-amd64

build-darwin-amd64:
	@echo "Building $(BINARY) for darwin/amd64..."
	GOOS=darwin GOARCH=amd64 $(GO) build $(GOFLAGS) -o bin/$(BINARY)-darwin-amd64 ./cmd/ga

build-darwin-arm64:
	@echo "Building $(BINARY) for darwin/arm64..."
	GOOS=darwin GOARCH=arm64 $(GO) build $(GOFLAGS) -o bin/$(BINARY)-darwin-arm64 ./cmd/ga

build-linux-amd64:
	@echo "Building $(BINARY) for linux/amd64..."
	GOOS=linux GOARCH=amd64 $(GO) build $(GOFLAGS) -o bin/$(BINARY)-linux-amd64 ./cmd/ga

build-linux-arm64:
	@echo "Building $(BINARY) for linux/arm64..."
	GOOS=linux GOARCH=arm64 $(GO) build $(GOFLAGS) -o bin/$(BINARY)-linux-arm64 ./cmd/ga

build-windows-amd64:
	@echo "Building $(BINARY) for windows/amd64..."
	GOOS=windows GOARCH=amd64 $(GO) build $(GOFLAGS) -o bin/$(BINARY)-windows-amd64.exe ./cmd/ga

# Run tests
test:
	$(GO) test -v ./...

# Run linter
lint:
	$(GO) vet ./...
	@echo "✅ Lint passed"

# Clean build artifacts
clean:
	rm -rf bin/
	rm -rf ~/.cache/ga/
	@echo "✅ Cleaned"

# Install binary to ~/.local/bin
install: build
	mkdir -p ~/.local/bin
	cp bin/$(BINARY) ~/.local/bin/$(BINARY)
	chmod +x ~/.local/bin/$(BINARY)
	@echo "✅ Installed to ~/.local/bin/$(BINARY)"
	@echo "Add ~/.local/bin to your PATH if needed"

# Create release for current platform
release:
	@echo "Creating release for $(GOOS)/$(GOARCH)..."
	@mkdir -p dist
	$(GO) build $(GOFLAGS) -o dist/$(BINARY) ./cmd/ga
	@echo "✅ Release created: dist/$(BINARY)"

# Create releases for all platforms
release-all: release-darwin-amd64 release-darwin-arm64 release-linux-amd64 release-linux-arm64 release-windows-amd64
	@echo ""
	@echo "✅ All releases created in dist/"
	@ls -la dist/

release-darwin-amd64:
	@mkdir -p dist
	GOOS=darwin GOARCH=amd64 $(GO) build $(GOFLAGS) -o dist/$(BINARY)-darwin-amd64 ./cmd/ga

release-darwin-arm64:
	@mkdir -p dist
	GOOS=darwin GOARCH=arm64 $(GO) build $(GOFLAGS) -o dist/$(BINARY)-darwin-arm64 ./cmd/ga

release-linux-amd64:
	@mkdir -p dist
	GOOS=linux GOARCH=amd64 $(GO) build $(GOFLAGS) -o dist/$(BINARY)-linux-amd64 ./cmd/ga

release-linux-arm64:
	@mkdir -p dist
	GOOS=linux GOARCH=arm64 $(GO) build $(GOFLAGS) -o dist/$(BINARY)-linux-arm64 ./cmd/ga

release-windows-amd64:
	@mkdir -p dist
	GOOS=windows GOARCH=amd64 $(GO) build $(GOFLAGS) -o dist/$(BINARY)-windows-amd64.exe ./cmd/ga
