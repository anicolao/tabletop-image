#!/usr/bin/env bash
#
# Build Tabletop Image Script
# Orchestrates the complete build process for the Raspberry Pi 4 tabletop kiosk image
#

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FIRMWARE_DIR="$PROJECT_ROOT/firmware"

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
Tabletop Image Builder

USAGE:
    $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -q, --quick         Quick build (skip some optimizations)
    -c, --clean         Clean before building
    -v, --verbose       Verbose output
    --check-only        Only validate configuration, don't build
    --show-logs         Show build logs in real-time

EXAMPLES:
    $0                  # Standard build
    $0 --clean          # Clean build
    $0 --quick          # Fast build for testing
    $0 --check-only     # Validate configuration only

EOF
}

# Parse command line arguments
QUICK_BUILD=false
CLEAN_BUILD=false
VERBOSE=false
CHECK_ONLY=false
SHOW_LOGS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -q|--quick)
            QUICK_BUILD=true
            shift
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
        --show-logs)
            SHOW_LOGS=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."
    
    # Check if we're in a Nix environment
    if ! command -v nix >/dev/null 2>&1; then
        log_error "Nix is not available. Please install Nix or enter the dev shell with 'nix develop'"
        exit 1
    fi
    
    # Check if we have flakes enabled
    if ! nix flake --help >/dev/null 2>&1; then
        log_error "Nix flakes are not enabled. Please enable experimental features."
        exit 1
    fi
    
    # Check project structure
    if [[ ! -f "$PROJECT_ROOT/flake.nix" ]]; then
        log_error "Top-level flake.nix not found. Are you in the project root?"
        exit 1
    fi
    
    if [[ ! -f "$FIRMWARE_DIR/flake.nix" ]]; then
        log_error "Firmware flake.nix not found. Firmware directory may be incomplete."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Clean build artifacts
clean_build() {
    log_step "Cleaning build artifacts..."
    
    # Remove Nix result symlinks
    find "$PROJECT_ROOT" -name "result*" -type l -delete 2>/dev/null || true
    
    # Clean firmware directory
    if [[ -d "$FIRMWARE_DIR" ]]; then
        cd "$FIRMWARE_DIR"
        find . -name "result*" -type l -delete 2>/dev/null || true
    fi
    
    log_success "Build artifacts cleaned"
}

# Validate configuration
validate_config() {
    log_step "Validating configuration..."
    
    # Check top-level flake
    cd "$PROJECT_ROOT"
    if ! nix flake check 2>/dev/null; then
        log_error "Top-level flake validation failed"
        return 1
    fi
    
    # Check firmware flake
    cd "$FIRMWARE_DIR"
    if ! nix flake check 2>/dev/null; then
        log_error "Firmware flake validation failed"
        return 1
    fi
    
    # Test build configuration without actually building
    if ! nix build .#nixosConfigurations.tabletop.config.system.build.toplevel --dry-run >/dev/null 2>&1; then
        log_error "NixOS configuration test failed"
        return 1
    fi
    
    log_success "Configuration validation passed"
}

# Build the image
build_image() {
    log_step "Building tabletop image..."
    
    cd "$FIRMWARE_DIR"
    
    # Determine build flags
    local build_flags=()
    
    if [[ "$VERBOSE" == true ]]; then
        build_flags+=("--print-build-logs")
    fi
    
    if [[ "$SHOW_LOGS" == true ]]; then
        build_flags+=("--print-build-logs")
    fi
    
    # Add optimization flags
    if [[ "$QUICK_BUILD" == false ]]; then
        build_flags+=("--option" "max-jobs" "auto")
        build_flags+=("--option" "cores" "0")
    fi
    
    # Start the build
    local start_time=$(date +%s)
    
    if [[ "$VERBOSE" == true ]] || [[ "$SHOW_LOGS" == true ]]; then
        nix build .#tabletopImage "${build_flags[@]}"
    else
        log_info "Building... (this may take 30-60 minutes for the first build)"
        log_info "Use --show-logs or --verbose to see detailed output"
        nix build .#tabletopImage "${build_flags[@]}" 2>&1 | grep -E "(building|built:|copying)" || true
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_success "Build completed in ${duration}s"
    
    # Show build results
    if [[ -L "result" ]]; then
        local result_path=$(readlink -f result)
        log_info "Build output: $result_path"
        
        # List the contents
        if [[ -d "$result_path/sd-image" ]]; then
            log_info "SD card images:"
            ls -la "$result_path/sd-image/" | grep -v "^total" | while read -r line; do
                echo "  $line"
            done
        fi
    fi
}

# Show build summary
show_summary() {
    log_success "Build Summary"
    echo "============="
    echo ""
    
    if [[ -L "$FIRMWARE_DIR/result" ]]; then
        local result_path=$(readlink -f "$FIRMWARE_DIR/result")
        echo "📁 Build output: $result_path"
        
        if [[ -d "$result_path/sd-image" ]]; then
            local image_files=( "$result_path/sd-image"/*.img )
            if [[ -f "${image_files[0]}" ]]; then
                echo "💾 SD card image: ${image_files[0]}"
                echo "📊 Image size: $(du -h "${image_files[0]}" | cut -f1)"
            fi
        fi
    fi
    
    echo ""
    echo "Next steps:"
    echo "1. Flash to SD card: make flash DEVICE=/dev/diskX"
    echo "2. Or use script: $SCRIPT_DIR/flash-card.sh /dev/diskX"
    echo "3. Insert SD card into Raspberry Pi 4 and power on"
    echo ""
}

# Main execution
main() {
    echo "🎮 Tabletop Image Builder"
    echo "========================="
    echo ""
    
    # Step 1: Prerequisites
    check_prerequisites
    
    # Step 2: Clean if requested
    if [[ "$CLEAN_BUILD" == true ]]; then
        clean_build
    fi
    
    # Step 3: Validate configuration
    validate_config
    
    # Step 4: Build (unless check-only)
    if [[ "$CHECK_ONLY" == true ]]; then
        log_success "Configuration check completed successfully"
        echo ""
        echo "To build the image, run:"
        echo "  $0"
        echo "  or"
        echo "  make build"
        return 0
    fi
    
    # Step 5: Build the image
    build_image
    
    # Step 6: Show summary
    show_summary
    
    log_success "Tabletop image build completed successfully! 🎉"
}

# Error handling
trap 'log_error "Build failed on line $LINENO. Exit code: $?"' ERR

# Run main function
main "$@"