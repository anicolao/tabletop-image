#!/usr/bin/env bash
#
# Setup Development Environment
# Initialize the tabletop-image development environment
#

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

log_step() {
    echo -e "${PURPLE}🔄 $1${NC}"
}

# Help function
show_help() {
    cat << EOF
Tabletop Image Development Environment Setup

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -f, --force         Force setup even if already configured
    --check-only        Only check prerequisites, don't setup
    --shell             Enter development shell after setup

DESCRIPTION:
    This script initializes the development environment for building
    Raspberry Pi 4 tabletop gaming kiosk images. It checks prerequisites,
    validates the Nix setup, and prepares the build environment.

EOF
}

# Parse command line arguments
FORCE_SETUP=false
CHECK_ONLY=false
ENTER_SHELL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            FORCE_SETUP=true
            shift
            ;;
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
        --shell)
            ENTER_SHELL=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check if Nix is installed
check_nix() {
    log_step "Checking Nix installation..."
    
    if ! command -v nix >/dev/null 2>&1; then
        log_error "Nix is not installed or not in PATH"
        echo ""
        echo "To install Nix:"
        echo "  curl -L https://nixos.org/nix/install | sh"
        echo ""
        echo "Or follow the installation guide at: https://nixos.org/download.html"
        return 1
    fi
    
    # Check Nix version
    local nix_version=$(nix --version 2>/dev/null | head -1)
    log_info "Found: $nix_version"
    
    # Check if flakes are enabled
    if ! nix flake --help >/dev/null 2>&1; then
        log_warning "Nix flakes are not enabled"
        echo ""
        echo "To enable flakes, add this to ~/.config/nix/nix.conf:"
        echo "  experimental-features = nix-command flakes"
        echo ""
        echo "Or set the environment variable:"
        echo "  export NIX_CONFIG='experimental-features = nix-command flakes'"
        return 1
    fi
    
    log_success "Nix is properly configured"
    return 0
}

# Check system requirements
check_system() {
    log_step "Checking system requirements..."
    
    # Check OS
    local os_name=""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        os_name="macOS $(sw_vers -productVersion 2>/dev/null || echo 'Unknown')"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        os_name="Linux $(uname -r)"
    else
        os_name="$OSTYPE"
    fi
    log_info "Operating System: $os_name"
    
    # Check architecture
    local arch=$(uname -m)
    log_info "Architecture: $arch"
    
    # Check available disk space
    local available_space=""
    if command -v df >/dev/null 2>&1; then
        available_space=$(df -h . | tail -1 | awk '{print $4}')
        log_info "Available disk space: $available_space"
        
        # Warn if less than 10GB available
        local available_gb=$(df . | tail -1 | awk '{print int($4/1024/1024)}')
        if [[ $available_gb -lt 10 ]]; then
            log_warning "Less than 10GB available. Building may require significant disk space."
        fi
    fi
    
    # Check for required tools
    local missing_tools=()
    local recommended_tools=("git" "make" "curl")
    
    for tool in "${recommended_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_warning "Missing recommended tools: ${missing_tools[*]}"
        echo "These tools are recommended but not strictly required."
    fi
    
    log_success "System requirements check completed"
}

# Check project structure
check_project() {
    log_step "Checking project structure..."
    
    cd "$PROJECT_ROOT"
    
    # Check essential files
    local required_files=(
        "flake.nix"
        "DESIGN.md"
        "Makefile"
        "firmware/flake.nix"
        "scripts/build-image.sh"
        "scripts/flash-card.sh"
    )
    
    local missing_files=()
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Missing required files:"
        printf '  %s\n' "${missing_files[@]}"
        return 1
    fi
    
    # Check that scripts are executable
    local script_files=(
        "scripts/build-image.sh"
        "scripts/flash-card.sh"
        "scripts/setup-dev.sh"
    )
    
    for script in "${script_files[@]}"; do
        if [[ -f "$script" && ! -x "$script" ]]; then
            log_info "Making $script executable..."
            chmod +x "$script"
        fi
    done
    
    log_success "Project structure is valid"
}

# Validate flake configurations
validate_flakes() {
    log_step "Validating Nix flake configurations..."
    
    cd "$PROJECT_ROOT"
    
    # Check top-level flake
    log_info "Checking top-level flake..."
    if ! nix flake check 2>/dev/null; then
        log_error "Top-level flake validation failed"
        echo "Run 'nix flake check' for detailed error information"
        return 1
    fi
    
    # Check firmware flake
    log_info "Checking firmware flake..."
    cd firmware
    if ! nix flake check 2>/dev/null; then
        log_error "Firmware flake validation failed"
        echo "Run 'cd firmware && nix flake check' for detailed error information"
        return 1
    fi
    
    cd "$PROJECT_ROOT"
    log_success "Flake configurations are valid"
}

# Setup Git hooks (if in a git repository)
setup_git_hooks() {
    if [[ -d ".git" ]]; then
        log_step "Setting up Git hooks..."
        
        # Create pre-commit hook for Nix formatting
        cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Pre-commit hook for Nix formatting

set -e

# Check if any .nix files are staged
if git diff --cached --name-only | grep -q '\.nix$'; then
    echo "Checking Nix file formatting..."
    
    # Format staged .nix files
    git diff --cached --name-only | grep '\.nix$' | xargs nix fmt 2>/dev/null || true
    
    # Re-add formatted files
    git diff --cached --name-only | grep '\.nix$' | xargs git add
fi
EOF
        
        chmod +x .git/hooks/pre-commit
        log_success "Git hooks configured"
    fi
}

# Create development convenience files
create_dev_files() {
    log_step "Creating development convenience files..."
    
    # Create .envrc for direnv users
    if ! [[ -f ".envrc" ]]; then
        cat > .envrc << 'EOF'
# Direnv configuration for tabletop-image
use flake
EOF
        log_info "Created .envrc for direnv users"
    fi
    
    # Create VS Code settings for Nix
    if ! [[ -d ".vscode" ]]; then
        mkdir -p .vscode
        cat > .vscode/settings.json << 'EOF'
{
    "nixEnvSelector.suggestion": false,
    "nixfmt.path": "nixpkgs-fmt",
    "nix.enableLanguageServer": true,
    "nix.serverPath": "nil",
    "files.associations": {
        "*.nix": "nix"
    },
    "editor.formatOnSave": true,
    "[nix]": {
        "editor.defaultFormatter": "jnoortheen.nix-ide"
    }
}
EOF
        log_info "Created VS Code settings for Nix development"
    fi
    
    log_success "Development convenience files created"
}

# Show setup summary
show_summary() {
    echo ""
    log_success "Development Environment Setup Complete! 🎉"
    echo ""
    echo "📁 Project: $(basename "$PROJECT_ROOT")"
    echo "🏠 Location: $PROJECT_ROOT"
    echo ""
    echo "🚀 Quick Start:"
    echo "  1. Enter development shell:"
    echo "     nix develop"
    echo ""
    echo "  2. Build the tabletop image:"
    echo "     make build"
    echo "     # or"
    echo "     ./scripts/build-image.sh"
    echo ""
    echo "  3. Flash to SD card:"
    echo "     make flash DEVICE=/dev/diskX"
    echo "     # or"
    echo "     ./scripts/flash-card.sh /dev/diskX"
    echo ""
    echo "📚 Available commands in dev shell:"
    echo "  - build-image       Build the tabletop image"
    echo "  - flash-card        Flash image to SD card"
    echo "  - make <target>     Use Makefile targets"
    echo ""
    echo "📖 Documentation:"
    echo "  - README.md         Project overview"
    echo "  - DESIGN.md         Technical design document"
    echo "  - make help         Makefile help"
    echo ""
    echo "🔧 For help:"
    echo "  - make help-setup   Detailed setup guide"
    echo "  - make help-flash   SD card flashing guide"
    echo ""
}

# Main execution
main() {
    echo "🎮 Tabletop Image Development Setup"
    echo "==================================="
    echo ""
    
    local setup_failed=false
    
    # Step 1: Check Nix
    if ! check_nix; then
        setup_failed=true
    fi
    
    # Step 2: Check system
    check_system
    
    # Step 3: Check project structure
    if ! check_project; then
        setup_failed=true
    fi
    
    # If we're only checking, stop here
    if [[ "$CHECK_ONLY" == true ]]; then
        if [[ "$setup_failed" == true ]]; then
            log_error "Prerequisites check failed"
            exit 1
        else
            log_success "All prerequisites satisfied"
            exit 0
        fi
    fi
    
    # Exit if basic checks failed
    if [[ "$setup_failed" == true ]]; then
        log_error "Basic setup requirements not met. Please fix the issues above."
        exit 1
    fi
    
    # Step 4: Validate flakes
    if ! validate_flakes; then
        log_error "Flake validation failed"
        exit 1
    fi
    
    # Step 5: Setup additional features
    setup_git_hooks
    create_dev_files
    
    # Step 6: Show summary
    show_summary
    
    # Enter shell if requested
    if [[ "$ENTER_SHELL" == true ]]; then
        echo ""
        log_info "Entering development shell..."
        exec nix develop
    fi
}

# Error handling
trap 'log_error "Setup failed on line $LINENO. Exit code: $?"' ERR

# Run main function
main "$@"