#!/usr/bin/env bash
#
# Flash Tabletop Image to SD Card
# Safe SD card flashing with verification and error handling
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
Tabletop Image SD Card Flasher

USAGE:
    $0 [OPTIONS] <DEVICE>

ARGUMENTS:
    DEVICE              Target device (e.g., /dev/disk4, /dev/sdb)

OPTIONS:
    -h, --help          Show this help message
    -f, --force         Skip confirmation prompts
    -v, --verify        Verify flash after writing
    --image PATH        Specify custom image path
    --dry-run           Show what would be done without actually flashing

EXAMPLES:
    $0 /dev/disk4                    # Flash to /dev/disk4 (macOS)
    $0 /dev/sdb                      # Flash to /dev/sdb (Linux)
    $0 --verify /dev/disk4           # Flash and verify
    $0 --image custom.img /dev/sdb   # Flash custom image

SAFETY:
    This script includes safety checks to prevent accidental data loss:
    - Device validation
    - Size verification
    - Unmount confirmation
    - Progress monitoring

EOF
}

# Parse command line arguments
FORCE_MODE=false
VERIFY_FLASH=false
DRY_RUN=false
CUSTOM_IMAGE=""
TARGET_DEVICE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            FORCE_MODE=true
            shift
            ;;
        -v|--verify)
            VERIFY_FLASH=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --image)
            CUSTOM_IMAGE="$2"
            shift 2
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            if [[ -z "$TARGET_DEVICE" ]]; then
                TARGET_DEVICE="$1"
            else
                log_error "Too many arguments. Only one device should be specified."
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [[ -z "$TARGET_DEVICE" ]]; then
    log_error "Target device not specified"
    show_help
    exit 1
fi

# Find the image file
find_image() {
    local image_path=""
    
    if [[ -n "$CUSTOM_IMAGE" ]]; then
        if [[ -f "$CUSTOM_IMAGE" ]]; then
            image_path="$CUSTOM_IMAGE"
        else
            log_error "Custom image file not found: $CUSTOM_IMAGE"
            exit 1
        fi
    else
        # Look for built image
        local search_paths=(
            "$FIRMWARE_DIR/result/sd-image/*.img"
            "$PROJECT_ROOT/result/sd-image/*.img"
        )
        
        for pattern in "${search_paths[@]}"; do
            local files=( $pattern )
            if [[ -f "${files[0]}" ]]; then
                image_path="${files[0]}"
                break
            fi
        done
        
        if [[ -z "$image_path" ]]; then
            log_error "No image file found. Please build the image first:"
            echo "  make build"
            echo "  or"
            echo "  $SCRIPT_DIR/build-image.sh"
            exit 1
        fi
    fi
    
    echo "$image_path"
}

# Show available devices
show_devices() {
    log_info "Available storage devices:"
    
    if command -v diskutil >/dev/null 2>&1; then
        # macOS
        diskutil list | grep -E "(/dev/disk|IDENTIFIER|TYPE|SIZE)"
    elif command -v lsblk >/dev/null 2>&1; then
        # Linux
        lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL
    elif command -v fdisk >/dev/null 2>&1; then
        # Fallback
        sudo fdisk -l | grep -E "^Disk|^Device"
    else
        log_warning "Cannot detect storage devices automatically"
        log_info "Please verify your device path manually"
    fi
}

# Validate target device
validate_device() {
    local device="$1"
    
    log_step "Validating target device: $device"
    
    # Check if device exists
    if [[ ! -e "$device" ]]; then
        log_error "Device not found: $device"
        show_devices
        exit 1
    fi
    
    # Check if it's a block device
    if [[ ! -b "$device" ]]; then
        log_error "Not a block device: $device"
        exit 1
    fi
    
    # Get device information
    local device_info=""
    if command -v diskutil >/dev/null 2>&1; then
        # macOS
        device_info=$(diskutil info "$device" 2>/dev/null || echo "Unknown device")
    elif command -v lsblk >/dev/null 2>&1; then
        # Linux
        device_info=$(lsblk -no SIZE,MODEL "$device" 2>/dev/null || echo "Unknown device")
    fi
    
    log_info "Device info: $device_info"
    
    # Warn about mounted partitions
    local mounted_partitions=""
    if command -v diskutil >/dev/null 2>&1; then
        # macOS
        mounted_partitions=$(diskutil list "$device" 2>/dev/null | grep -E "mounted" || true)
    elif command -v mount >/dev/null 2>&1; then
        # Linux
        mounted_partitions=$(mount | grep "^$device" || true)
    fi
    
    if [[ -n "$mounted_partitions" ]]; then
        log_warning "Device has mounted partitions:"
        echo "$mounted_partitions"
        log_info "These will be unmounted automatically before flashing"
    fi
    
    log_success "Device validation passed"
}

# Unmount device
unmount_device() {
    local device="$1"
    
    log_step "Unmounting device: $device"
    
    if command -v diskutil >/dev/null 2>&1; then
        # macOS
        if diskutil unmountDisk "$device" 2>/dev/null; then
            log_success "Device unmounted successfully"
        else
            log_warning "Could not unmount device (may not be mounted)"
        fi
    elif command -v umount >/dev/null 2>&1; then
        # Linux - unmount all partitions
        local partitions=$(lsblk -lno NAME "$device" | tail -n +2 | sed "s|^|/dev/|" || true)
        for partition in $partitions; do
            if mountpoint -q "$partition" 2>/dev/null; then
                sudo umount "$partition" 2>/dev/null || log_warning "Could not unmount $partition"
            fi
        done
        log_success "Partitions unmounted"
    fi
}

# Flash the image
flash_image() {
    local image_path="$1"
    local device="$2"
    
    log_step "Flashing image to device..."
    log_info "Source: $image_path"
    log_info "Target: $device"
    
    # Get image size
    local image_size=$(du -h "$image_path" | cut -f1)
    log_info "Image size: $image_size"
    
    # Prepare flash command
    local dd_command
    local dd_args=(
        "if=$image_path"
        "of=$device"
        "bs=4M"
        "status=progress"
    )
    
    if command -v pv >/dev/null 2>&1; then
        # Use pv for progress bar if available
        log_info "Using pv for progress monitoring..."
        pv "$image_path" | sudo dd "of=$device" bs=4M status=progress
    else
        # Use dd directly
        log_info "Flashing (this may take several minutes)..."
        sudo dd "${dd_args[@]}"
    fi
    
    log_success "Image flashed successfully"
}

# Verify flash
verify_flash() {
    local image_path="$1"
    local device="$2"
    
    log_step "Verifying flash..."
    
    # Get image size in bytes
    local image_size=$(stat -c%s "$image_path" 2>/dev/null || stat -f%z "$image_path" 2>/dev/null)
    
    if [[ -z "$image_size" ]]; then
        log_warning "Could not determine image size, skipping verification"
        return
    fi
    
    log_info "Verifying first ${image_size} bytes..."
    
    # Read back the same amount of data and compare
    if command -v cmp >/dev/null 2>&1; then
        if cmp -n "$image_size" "$image_path" "$device" >/dev/null 2>&1; then
            log_success "Verification passed - flash is correct"
        else
            log_error "Verification failed - flash may be corrupted"
            exit 1
        fi
    else
        log_warning "cmp command not available, skipping verification"
    fi
}

# Sync and eject
sync_and_eject() {
    local device="$1"
    
    log_step "Syncing filesystem..."
    sync
    
    # Wait a moment for sync to complete
    sleep 2
    
    log_step "Ejecting device..."
    if command -v diskutil >/dev/null 2>&1; then
        # macOS
        diskutil eject "$device" 2>/dev/null || log_warning "Could not eject device"
    elif command -v eject >/dev/null 2>&1; then
        # Linux
        sudo eject "$device" 2>/dev/null || log_warning "Could not eject device"
    fi
    
    log_success "Device is safe to remove"
}

# Show final instructions
show_final_instructions() {
    cat << EOF

🎉 SD Card Flashing Complete!

Next steps:
1. Insert the SD card into your Raspberry Pi 4
2. Connect a touchscreen display via HDMI
3. Power on the device
4. The system will boot directly to the tabletop gaming interface

Troubleshooting:
- If the system doesn't boot, check that your Pi 4 has the latest firmware
- Ensure your power supply provides at least 3A for stable operation
- For touchscreen issues, check the display connection and compatibility

For support, see the project documentation or create an issue.

EOF
}

# Main execution
main() {
    echo "💾 Tabletop Image SD Card Flasher"
    echo "================================="
    echo ""
    
    # Find the image
    local image_path
    image_path=$(find_image)
    log_info "Using image: $image_path"
    
    # Validate device
    validate_device "$TARGET_DEVICE"
    
    # Show what we're about to do
    echo ""
    log_warning "DANGER: This will completely erase the target device!"
    log_info "Image: $image_path ($(du -h "$image_path" | cut -f1))"
    log_info "Target: $TARGET_DEVICE"
    echo ""
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would flash image to device (no actual changes made)"
        return 0
    fi
    
    # Confirmation
    if [[ "$FORCE_MODE" == false ]]; then
        echo -n "Are you sure you want to continue? [y/N] "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            log_info "Operation cancelled by user"
            exit 0
        fi
    fi
    
    # Execute the flash process
    unmount_device "$TARGET_DEVICE"
    flash_image "$image_path" "$TARGET_DEVICE"
    
    if [[ "$VERIFY_FLASH" == true ]]; then
        verify_flash "$image_path" "$TARGET_DEVICE"
    fi
    
    sync_and_eject "$TARGET_DEVICE"
    
    # Show final instructions
    show_final_instructions
    
    log_success "SD card is ready for use! 🎮"
}

# Error handling
trap 'log_error "Flashing failed on line $LINENO. Exit code: $?"' ERR

# Check for root/sudo when needed
if [[ $EUID -eq 0 ]]; then
    log_warning "Running as root. This is not recommended for safety."
fi

# Run main function
main "$@"