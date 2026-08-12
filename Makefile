# Tabletop Image Makefile
# Provides convenient targets for building and flashing Raspberry Pi 4 tabletop images

.PHONY: help dev-shell build flash clean test-build check format

# Default target
help: ## Show this help message
	@echo "Tabletop Image Build System"
	@echo "==========================="
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make dev-shell                    # Enter development environment"
	@echo "  make build                        # Build the tabletop image"
	@echo "  make flash DEVICE=/dev/disk4      # Flash image to SD card"
	@echo "  make clean                        # Clean build artifacts"

dev-shell: ## Enter the Nix development shell
	@echo "🚀 Entering development environment..."
	nix develop

build: ## Build the tabletop image for Raspberry Pi 4
	@echo "🔨 Building tabletop image..."
	@if [ ! -d firmware ]; then \
		echo "❌ firmware/ directory not found. Run 'make dev-shell' first."; \
		exit 1; \
	fi
	cd firmware && nix build .#tabletopImage --print-build-logs
	@echo "✅ Build complete!"
	@echo "📁 Image location: firmware/result/sd-image/"
	@ls -la firmware/result/sd-image/

test-build: ## Test build without creating the full image (faster)
	@echo "🧪 Testing build configuration..."
	cd firmware && nix build .#nixosConfigurations.tabletop.config.system.build.toplevel --print-build-logs
	@echo "✅ Configuration test complete!"

flash: ## Flash image to SD card (requires DEVICE=/dev/diskX)
	@if [ -z "$(DEVICE)" ]; then \
		echo "❌ Please specify the target device:"; \
		echo "   make flash DEVICE=/dev/disk4"; \
		echo ""; \
		echo "Available devices:"; \
		if command -v diskutil >/dev/null 2>&1; then \
			diskutil list; \
		elif command -v lsblk >/dev/null 2>&1; then \
			lsblk; \
		else \
			echo "   Run 'diskutil list' (macOS) or 'lsblk' (Linux) to see devices"; \
		fi; \
		exit 1; \
	fi
	@if [ ! -f firmware/result/sd-image/*.img ]; then \
		echo "❌ Image not found. Run 'make build' first."; \
		exit 1; \
	fi
	@echo "⚠️  WARNING: This will erase all data on $(DEVICE)"
	@echo "📱 Target device: $(DEVICE)"
	@echo "🖼️  Image: $$(ls firmware/result/sd-image/*.img)"
	@echo -n "Continue? [y/N] " && read ans && [ $${ans:-N} = y ]
	@echo "💾 Flashing image..."
	@IMAGE=$$(ls firmware/result/sd-image/*.img | head -1); \
	if command -v pv >/dev/null 2>&1; then \
		pv "$$IMAGE" | sudo dd of=$(DEVICE) bs=4M status=progress; \
	else \
		sudo dd if="$$IMAGE" of=$(DEVICE) bs=4M status=progress; \
	fi
	@echo "🔄 Syncing..."
	sudo sync
	@echo "✅ Flash complete! SD card is ready."

verify: ## Verify the flashed SD card
	@if [ -z "$(DEVICE)" ]; then \
		echo "❌ Please specify the device to verify:"; \
		echo "   make verify DEVICE=/dev/disk4"; \
		exit 1; \
	fi
	@echo "🔍 Verifying SD card structure..."
	@if command -v diskutil >/dev/null 2>&1; then \
		diskutil list $(DEVICE); \
	elif command -v fdisk >/dev/null 2>&1; then \
		sudo fdisk -l $(DEVICE); \
	fi

clean: ## Clean build artifacts and temporary files
	@echo "🧹 Cleaning build artifacts..."
	@if [ -d firmware/result ]; then \
		rm -rf firmware/result; \
		echo "   Removed firmware/result"; \
	fi
	@if [ -d result ]; then \
		rm -rf result; \
		echo "   Removed result"; \
	fi
	@echo "✅ Clean complete!"

deep-clean: clean ## Deep clean including Nix store garbage collection
	@echo "🗑️  Performing deep clean..."
	nix-collect-garbage
	nix store gc
	@echo "✅ Deep clean complete!"

check: ## Check flake validity and formatting
	@echo "✅ Checking top-level flake..."
	nix flake check
	@echo "✅ Checking firmware flake..."
	cd firmware && nix flake check
	@echo "🎉 All checks passed!"

format: ## Format Nix files
	@echo "🎨 Formatting Nix files..."
	nix fmt
	cd firmware && nix fmt ..
	@echo "✅ Formatting complete!"

update: ## Update flake inputs
	@echo "📦 Updating flake inputs..."
	nix flake update
	cd firmware && nix flake update
	@echo "✅ Update complete!"

show-info: ## Show system information and build details
	@echo "ℹ️  System Information"
	@echo "===================="
	@echo "Host system: $$(uname -a)"
	@echo "Nix version: $$(nix --version)"
	@echo ""
	@echo "📋 Project Structure:"
	@tree -L 3 -I '.git' . || find . -type d -not -path '*/.*' | head -20
	@echo ""
	@echo "🔧 Available in dev shell:"
	@echo "  - Cross-compilation tools for ARM64"
	@echo "  - Image building and flashing utilities"
	@echo "  - Development and debugging tools"

# Advanced targets for development

dev-qemu: ## Boot the image in QEMU for testing (requires build first)
	@if [ ! -f firmware/result/sd-image/*.img ]; then \
		echo "❌ Image not found. Run 'make build' first."; \
		exit 1; \
	fi
	@echo "🚀 Starting QEMU with tabletop image..."
	@IMAGE=$$(ls firmware/result/sd-image/*.img | head -1); \
	qemu-system-aarch64 \
		-M raspi4b \
		-cpu cortex-a72 \
		-m 1G \
		-drive format=raw,file="$$IMAGE" \
		-netdev user,id=net0 \
		-device usb-net,netdev=net0 \
		-display gtk \
		-show-cursor

dev-enter-firmware: ## Enter firmware development shell
	@echo "🔧 Entering firmware development shell..."
	cd firmware && nix develop

# Help for specific scenarios
help-flash: ## Show detailed flashing instructions
	@echo "💾 SD Card Flashing Guide"
	@echo "========================"
	@echo ""
	@echo "1. Find your SD card device:"
	@echo "   macOS: diskutil list"
	@echo "   Linux: lsblk or sudo fdisk -l"
	@echo ""
	@echo "2. Unmount the SD card (important!):"
	@echo "   macOS: diskutil unmountDisk /dev/diskX"
	@echo "   Linux: sudo umount /dev/sdXY (for all partitions)"
	@echo ""
	@echo "3. Flash the image:"
	@echo "   make flash DEVICE=/dev/diskX"
	@echo ""
	@echo "4. Safely eject:"
	@echo "   macOS: diskutil eject /dev/diskX"
	@echo "   Linux: sudo eject /dev/sdX"
	@echo ""
	@echo "⚠️  Always double-check the device path to avoid data loss!"

help-setup: ## Show initial setup instructions
	@echo "🎮 Tabletop Image Setup Guide"
	@echo "============================="
	@echo ""
	@echo "First time setup:"
	@echo "1. make dev-shell          # Enter development environment"
	@echo "2. make build              # Build the image (~30-60 minutes)"
	@echo "3. make flash DEVICE=...   # Flash to SD card"
	@echo ""
	@echo "Development workflow:"
	@echo "1. Edit files in firmware/"
	@echo "2. make test-build         # Quick config test"
	@echo "3. make build              # Full rebuild"
	@echo "4. make flash DEVICE=...   # Test on hardware"
	@echo ""
	@echo "Troubleshooting:"
	@echo "- make clean               # Clean build artifacts"
	@echo "- make check               # Validate configuration"
	@echo "- make help-flash          # Flashing help"