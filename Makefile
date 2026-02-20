.PHONY: test test-unit test-integration test-coverage lint clean install help

# Default target
help:
	@echo "Guardian Agent - Development Commands"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  test             Run all tests"
	@echo "  test-unit        Run unit tests only"
	@echo "  test-integration Run integration tests only"
	@echo "  test-coverage    Run tests with coverage report"
	@echo "  lint             Run shellcheck linter"
	@echo "  clean            Clean cache and temp files"
	@echo "  install          Install gga locally"
	@echo "  help             Show this help"

# Run all tests
test:
	@echo "Running all tests..."
	shellspec

# Run unit tests only
test-unit:
	@echo "Running unit tests..."
	shellspec spec/unit

# Run integration tests only
test-integration:
	@echo "Running integration tests..."
	shellspec spec/integration

# Run tests with coverage (requires kcov)
test-coverage:
	@echo "Running tests with coverage..."
	shellspec --kcov

# Lint shell scripts
lint:
	@echo "Linting shell scripts..."
	shellcheck bin/gga lib/*.sh
	@echo "✅ Linting passed"

# Clean temp files and cache
clean:
	@echo "Cleaning..."
	rm -rf coverage/
	rm -rf ~/.cache/gga/
	@echo "✅ Cleaned"

# Install locally
install:
	@echo "Installing gga locally..."
	./install.sh

# Quick check before commit
check: lint test
	@echo ""
	@echo "✅ All checks passed!"
