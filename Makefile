# Makefile for Tabletop Image

# Variables
SHELL := /bin/bash
IMAGE_PATH := ./result/sd-image/nixos-sd-image-*-aarch64-linux.img

# Default target
all: build

# Build the SD card image
build:
	@echo "Building the Raspberry Pi 4 image..."
	nix build ./firmware#default --system aarch64-linux --extra-platforms "aarch64-linux" --extra-substituters "https://cache.nixos.org"

# Flash the image to an SD card
flash:
	@if [ -z "$(DEVICE)" ]; then \
		echo "Error: Please specify the device. Example: make flash DEVICE=/dev/sdX"; \
		exit 1; \
	fi
	@echo "Flashing image to $(DEVICE)..."
	dd if=$(IMAGE_PATH) of=$(DEVICE) bs=4M conv=fsync status=progress
	@echo "Flash complete."

# Clean build artifacts
clean:
	@echo "Cleaning up build artifacts..."
	rm -rf ./result
	@echo "Clean complete."

.PHONY: all build flash clean
