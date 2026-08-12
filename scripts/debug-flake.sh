#!/usr/bin/env bash
#
# Debug Flake Issues
# This script helps diagnose and fix common Nix flake issues
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

echo "🔧 Tabletop Image Flake Debugger"
echo "================================"
echo ""

cd "$PROJECT_ROOT"

# Check Nix installation and configuration
echo "1. Checking Nix environment..."
if ! command -v nix >/dev/null 2>&1; then
    log_error "Nix is not installed or not available in PATH"
    echo ""
    echo "Please install Nix first:"
    echo "  curl -L https://nixos.org/nix/install | sh"
    echo "  # Then restart your shell or source the profile"
    exit 1
fi

nix_version=$(nix --version)
log_info "Nix version: $nix_version"

# Check if flakes are enabled
if ! nix flake --help >/dev/null 2>&1; then
    log_error "Nix flakes are not enabled"
    echo ""
    echo "Enable flakes by adding to ~/.config/nix/nix.conf:"
    echo "  experimental-features = nix-command flakes"
    echo ""
    echo "Or export temporarily:"
    echo "  export NIX_CONFIG='experimental-features = nix-command flakes'"
    exit 1
fi

log_success "Nix flakes are enabled"
echo ""

# Check if we have a lock file and if it's dirty
echo "2. Checking flake lock files..."
if [[ ! -f "flake.lock" ]]; then
    log_warning "No flake.lock found - this will be created on first build"
fi

if git status --porcelain 2>/dev/null | grep -q .; then
    log_warning "Git working tree is dirty - this may cause warnings"
fi

echo ""

# Test main flake
echo "3. Testing main flake..."
echo "   Running: nix flake check"
if nix flake check --show-trace 2>&1; then
    log_success "Main flake validation passed"
else
    log_error "Main flake validation failed"
    echo ""
    echo "Try these debugging steps:"
    echo "  1. Check syntax: nix flake check --show-trace"
    echo "  2. Update inputs: nix flake update"
    echo "  3. Clear cache: nix flake check --refresh"
fi

echo ""

# Test firmware flake
echo "4. Testing firmware flake..."
echo "   Running: cd firmware && nix flake check"
cd firmware
if nix flake check --show-trace 2>&1; then
    log_success "Firmware flake validation passed"
else
    log_error "Firmware flake validation failed"
    echo ""
    echo "Try these debugging steps:"
    echo "  1. cd firmware"
    echo "  2. nix flake check --show-trace"
    echo "  3. nix flake update"
fi

cd "$PROJECT_ROOT"
echo ""

# Test development shell
echo "5. Testing development shell..."
if timeout 30 nix develop --command echo "Shell works" 2>/dev/null; then
    log_success "Development shell loads successfully"
else
    log_error "Development shell failed to load"
    echo ""
    echo "Debug with:"
    echo "  nix develop --show-trace"
fi

echo ""

# Show helpful commands
echo "🚀 If all tests pass, try these commands:"
echo ""
echo "Enter development shell:"
echo "  nix develop"
echo ""
echo "Build image (from dev shell):"
echo "  cd firmware && nix build .#tabletopImage"
echo ""
echo "Or use the convenient script:"
echo "  build-image"
echo ""

echo "🔍 For more debugging:"
echo "  - Use --show-trace with nix commands for detailed errors"
echo "  - Check 'nix log' for build failures"
echo "  - Use 'nix flake update' to update dependencies"
echo ""