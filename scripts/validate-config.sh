#!/usr/bin/env bash
#
# Validate Configuration Structure
# Tests the Nix configuration structure and syntax without requiring Nix to be installed
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Check file structure
check_structure() {
    log_info "Checking project structure..."
    
    local required_files=(
        "flake.nix"
        "DESIGN.md"
        "Makefile"
        "firmware/flake.nix"
        "firmware/modules/kiosk.nix"
        "firmware/modules/hardware-rpi4.nix"
        "scripts/build-image.sh"
        "scripts/flash-card.sh"
        "scripts/setup-dev.sh"
        ".gitignore"
    )
    
    local missing_files=()
    cd "$PROJECT_ROOT"
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            missing_files+=("$file")
        fi
    done
    
    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_error "Missing files:"
        printf '  %s\n' "${missing_files[@]}"
        return 1
    fi
    
    log_success "All required files present"
}

# Basic syntax check for Nix files
check_nix_syntax() {
    log_info "Checking Nix file syntax..."
    
    local nix_files=(
        "flake.nix"
        "firmware/flake.nix"
        "firmware/modules/kiosk.nix"
        "firmware/modules/hardware-rpi4.nix"
    )
    
    cd "$PROJECT_ROOT"
    
    for file in "${nix_files[@]}"; do
        log_info "Checking $file..."
        
        # Basic bracket/brace matching
        local open_braces=$(grep -o '{' "$file" | wc -l)
        local close_braces=$(grep -o '}' "$file" | wc -l)
        local open_brackets=$(grep -o '\[' "$file" | wc -l)
        local close_brackets=$(grep -o '\]' "$file" | wc -l)
        local open_parens=$(grep -o '(' "$file" | wc -l)
        local close_parens=$(grep -o ')' "$file" | wc -l)
        
        if [[ $open_braces -ne $close_braces ]]; then
            log_error "$file: Mismatched braces (open: $open_braces, close: $close_braces)"
            return 1
        fi
        
        if [[ $open_brackets -ne $close_brackets ]]; then
            log_error "$file: Mismatched brackets (open: $open_brackets, close: $close_brackets)"
            return 1
        fi
        
        if [[ $open_parens -ne $close_parens ]]; then
            log_error "$file: Mismatched parentheses (open: $open_parens, close: $close_parens)"
            return 1
        fi
        
        # Check for required sections in flake.nix files
        if [[ "$file" == *"flake.nix" ]]; then
            if ! grep -q "description.*=" "$file"; then
                log_warning "$file: Missing description field"
            fi
            if ! grep -q "inputs.*=" "$file"; then
                log_error "$file: Missing inputs section"
                return 1
            fi
            if ! grep -q "outputs.*=" "$file"; then
                log_error "$file: Missing outputs section"
                return 1
            fi
        fi
        
        log_success "$file syntax check passed"
    done
}

# Check script permissions
check_scripts() {
    log_info "Checking script permissions..."
    
    local scripts=(
        "scripts/build-image.sh"
        "scripts/flash-card.sh"
        "scripts/setup-dev.sh"
    )
    
    cd "$PROJECT_ROOT"
    
    for script in "${scripts[@]}"; do
        if [[ ! -x "$script" ]]; then
            log_error "$script is not executable"
            return 1
        fi
    done
    
    log_success "All scripts are executable"
}

# Check documentation
check_docs() {
    log_info "Checking documentation..."
    
    cd "$PROJECT_ROOT"
    
    # Check README exists and has content
    if [[ ! -s "README.md" ]]; then
        log_error "README.md is missing or empty"
        return 1
    fi
    
    # Check DESIGN.md exists and has content
    if [[ ! -s "DESIGN.md" ]]; then
        log_error "DESIGN.md is missing or empty"
        return 1
    fi
    
    # Check Makefile has help target
    if ! grep -q "^help:" "Makefile"; then
        log_warning "Makefile missing help target"
    fi
    
    log_success "Documentation check passed"
}

# Validate configuration content
check_config_content() {
    log_info "Checking configuration content..."
    
    cd "$PROJECT_ROOT"
    
    # Check top-level flake has devShell
    if ! grep -q "devShells" "flake.nix"; then
        log_error "Top-level flake.nix missing devShells"
        return 1
    fi
    
    # Check firmware flake has packages
    if ! grep -q "packages" "firmware/flake.nix"; then
        log_error "Firmware flake.nix missing packages"
        return 1
    fi
    
    # Check hardware module has Raspberry Pi config
    if ! grep -q "raspberry-pi" "firmware/modules/hardware-rpi4.nix"; then
        log_error "Hardware module missing Raspberry Pi configuration"
        return 1
    fi
    
    # Check kiosk module has browser config
    if ! grep -q "chromium" "firmware/modules/kiosk.nix"; then
        log_error "Kiosk module missing Chromium configuration"
        return 1
    fi
    
    log_success "Configuration content validation passed"
}

# Check project structure consistency
check_consistency() {
    log_info "Checking project consistency..."
    
    cd "$PROJECT_ROOT"
    
    # Check that all referenced files exist
    local firmware_imports=(
        "./modules/kiosk.nix"
        "./modules/hardware-rpi4.nix"
    )
    
    for import in "${firmware_imports[@]}"; do
        local full_path="firmware/${import#./}"
        if [[ ! -f "$full_path" ]]; then
            log_error "Referenced file not found: $full_path"
            return 1
        fi
    done
    
    # Check that scripts reference correct paths
    if ! grep -q "firmware/flake.nix" "scripts/build-image.sh"; then
        log_warning "build-image.sh may not reference firmware/flake.nix correctly"
    fi
    
    log_success "Project consistency check passed"
}

# Generate validation report
generate_report() {
    echo ""
    log_success "Configuration Validation Report"
    echo "==============================="
    echo ""
    echo "✅ Project Structure: Valid"
    echo "✅ Nix Syntax: Valid"
    echo "✅ Script Permissions: Valid"
    echo "✅ Documentation: Present"
    echo "✅ Configuration Content: Valid"
    echo "✅ Project Consistency: Valid"
    echo ""
    echo "📁 File Count:"
    echo "   - Nix files: $(find . -name "*.nix" | wc -l)"
    echo "   - Scripts: $(find scripts -name "*.sh" | wc -l)"
    echo "   - Documentation: $(find . -maxdepth 1 -name "*.md" | wc -l)"
    echo ""
    echo "🎯 Next Steps:"
    echo "   1. Install Nix: curl -L https://nixos.org/nix/install | sh"
    echo "   2. Enable flakes: echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf"
    echo "   3. Run setup: ./scripts/setup-dev.sh"
    echo "   4. Build image: make build"
    echo ""
}

# Main execution
main() {
    echo "🔍 Tabletop Image Configuration Validator"
    echo "========================================="
    echo ""
    
    local validation_failed=false
    
    check_structure || validation_failed=true
    check_nix_syntax || validation_failed=true
    check_scripts || validation_failed=true
    check_docs || validation_failed=true
    check_config_content || validation_failed=true
    check_consistency || validation_failed=true
    
    if [[ "$validation_failed" == true ]]; then
        echo ""
        log_error "Configuration validation failed"
        echo "Please fix the issues above before proceeding."
        exit 1
    fi
    
    generate_report
    log_success "All validation checks passed! 🎉"
}

main "$@"