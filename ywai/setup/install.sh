#!/bin/bash
# YWAI Setup Installer - Go Binary Wrapper
# Downloads and executes the compiled Go setup wizard

set -euo pipefail

# Configuration
REPO="Yoizen/dev-ai-workflow"
DOWNLOAD_BINARY_NAME="setup-wizard"
COMMAND_NAME="ywai"
INSTALL_DIR="${HOME}/.local/bin"

# Parse environment variables
YWAI_VERSION="${YWAI_VERSION:-}"
YWAI_CHANNEL="${YWAI_CHANNEL:-stable}"

# Detect platform
detect_platform() {
    local os arch
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"
    
    case "$os" in
        linux) os="linux" ;;
        darwin) os="darwin" ;;
        *) echo "❌ Unsupported OS: $os" >&2; exit 1 ;;
    esac
    
    case "$arch" in
        x86_64|amd64) arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) echo "❌ Unsupported architecture: $arch" >&2; exit 1 ;;
    esac
    
    echo "${os}-${arch}"
}

# Download binary
download_binary() {
    local platform="$1"
    local version="${YWAI_VERSION:-latest}"
    local download_url
    
    if [ "$version" = "latest" ]; then
        download_url="https://github.com/${REPO}/releases/latest/download/${DOWNLOAD_BINARY_NAME}-${platform}"
    else
        download_url="https://github.com/${REPO}/releases/download/${version}/${DOWNLOAD_BINARY_NAME}-${platform}"
    fi
    
    echo "📥 Downloading ${DOWNLOAD_BINARY_NAME} v${version} for ${platform}..."
    
    # Create install directory
    mkdir -p "$INSTALL_DIR"
    
    # Download and install
    if curl -fsSL "$download_url" -o "${INSTALL_DIR}/${COMMAND_NAME}"; then
        chmod +x "${INSTALL_DIR}/${COMMAND_NAME}"
        ln -sf "${INSTALL_DIR}/${COMMAND_NAME}" "${INSTALL_DIR}/${DOWNLOAD_BINARY_NAME}"
        echo "✅ Installed to ${INSTALL_DIR}/${COMMAND_NAME} (alias: ${DOWNLOAD_BINARY_NAME})"
    else
        echo "❌ Failed to download binary from $download_url" >&2
        echo "💡 Falling back to source build..." >&2
        
        # Fallback: build from source
        build_from_source "$platform"
    fi
}

# Build from source (fallback)
build_from_source() {
    local platform="$1"
    echo "🔨 Building from source..."
    
    # Create temp directory
    local temp_dir
    temp_dir="$(mktemp -d)"
    cd "$temp_dir"
    
    # Clone repository
    if ! git clone --depth 1 "https://github.com/${REPO}.git"; then
        echo "❌ Failed to clone repository" >&2
        exit 1
    fi
    
    cd "${REPO#*/}"
    
    # Build
    if [ -f "ywai/setup/Makefile" ]; then
        cd ywai/setup
    fi

    if ! make build; then
        echo "❌ Failed to build from source" >&2
        exit 1
    fi

    # Install
    cp "setup-wizard" "${INSTALL_DIR}/${COMMAND_NAME}"
    chmod +x "${INSTALL_DIR}/${COMMAND_NAME}"
    ln -sf "${INSTALL_DIR}/${COMMAND_NAME}" "${INSTALL_DIR}/${DOWNLOAD_BINARY_NAME}"
    
    # Cleanup
    cd /
    rm -rf "$temp_dir"
    
    echo "✅ Built and installed from source"
}

# Execute with arguments
execute_setup() {
    local binary_path="${INSTALL_DIR}/${COMMAND_NAME}"
    
    # Add to PATH if not already there
    if ! echo "$PATH" | grep -q "$INSTALL_DIR"; then
        export PATH="$INSTALL_DIR:$PATH"
    fi
    
    # Execute with all arguments
    exec "$binary_path" "$@"
}

# Main execution
main() {
    echo "🚀 YWAI Setup - Go Binary Installer v${YWAI_VERSION:-latest}"
    echo "======================================================"
    
    # Detect platform
    local platform
    platform="$(detect_platform)"
    echo "🔍 Detected platform: ${platform}"
    
    # Check if binary exists and version matches
    local binary_path="${INSTALL_DIR}/${COMMAND_NAME}"
    local should_download=true
    
    if [ -f "$binary_path" ]; then
        if [ "${FORCE_DOWNLOAD:-}" != "true" ]; then
            echo "✅ Binary already exists at $binary_path"
            should_download=false
        fi
    fi
    
    # Download if needed
    if [ "$should_download" = "true" ]; then
        download_binary "$platform"
    fi
    
    # Execute setup
    echo "🎯 Executing setup..."
    execute_setup "$@"
}

# Run main function with all arguments
main "$@"
