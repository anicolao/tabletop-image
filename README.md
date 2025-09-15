# Tabletop Image

A Nix-based build system for creating Raspberry Pi 4 SD card images that transform your device into a dedicated tabletop gaming kiosk.

## Overview

This repository enables you to build minimal, reproducible SD card images for Raspberry Pi 4 devices that run as full-screen browser kiosks, specifically designed for playing board games on attached touchscreens. The entire system is built using Nix configuration to ensure consistent, reproducible builds across different development environments.

## Goals

- **Kiosk Mode Browser**: Create a streamlined Raspberry Pi 4 image that boots directly into a full-screen browser without traditional desktop environment overhead
- **Touchscreen Gaming**: Optimized for touchscreen interaction to enable intuitive board game playing experiences
- **Minimal Footprint**: Lightweight system focused solely on the browser and essential services needed for gaming
- **Reproducible Builds**: Leverage Nix package manager to ensure anyone can reproduce identical tabletop firmware images
- **Cross-Platform Development**: Support development on macOS laptops with access to Linux builders for image compilation

## Target Hardware

- **Primary**: Raspberry Pi 4 (all variants)
- **Display**: Touchscreen displays compatible with Raspberry Pi 4
- **Storage**: MicroSD card (minimum 8GB recommended)

## Development Environment

This project is designed to work seamlessly with:
- **Host System**: macOS laptops (primary development environment)
- **Build System**: Linux builders (for compiling ARM images)
- **Package Manager**: Nix (ensuring reproducible builds)

## Key Features

- **Zero-Configuration Boot**: SD card boots directly to gaming interface
- **Touch-Optimized UI**: Responsive design for touchscreen interaction
- **Offline Capable**: Core functionality works without internet connectivity
- **Minimal Attack Surface**: Reduced system components for improved security
- **Easy Updates**: Nix-based configuration allows for straightforward system updates

## Use Cases

- **Digital Board Game Tables**: Transform any touchscreen into a board game surface
- **Game Cafes/Stores**: Provide consistent gaming experiences across multiple stations
- **Home Gaming**: Create dedicated gaming devices from Raspberry Pi hardware
- **Educational Environments**: Classroom gaming setups with standardized configurations

## Getting Started

### Prerequisites

- **Nix Package Manager**: Required for reproducible builds
  ```bash
  curl -L https://nixos.org/nix/install | sh
  ```

- **Enable Nix Flakes**: Add to `~/.config/nix/nix.conf`:
  ```
  experimental-features = nix-command flakes
  ```

### Quick Start

1. **Setup Development Environment**:
   ```bash
   ./scripts/setup-dev.sh
   nix develop
   ```

2. **Build the Image**:
   ```bash
   make build
   # or
   ./scripts/build-image.sh
   ```

3. **Flash to SD Card**:
   ```bash
   make flash DEVICE=/dev/diskX
   # or
   ./scripts/flash-card.sh /dev/diskX
   ```

4. **Boot Raspberry Pi**: Insert SD card and power on

### Available Commands

- `make help` - Show all available targets
- `make dev-shell` - Enter development environment
- `make build` - Build the tabletop image
- `make flash DEVICE=...` - Flash image to SD card
- `make clean` - Clean build artifacts
- `make check` - Validate configuration

## Architecture

This project uses a two-tier Nix flake architecture:

```
tabletop-image/
├── flake.nix              # Development environment & tools
├── firmware/
│   ├── flake.nix          # Image building configuration  
│   ├── modules/
│   │   ├── kiosk.nix      # Browser kiosk configuration
│   │   └── hardware-rpi4.nix  # Raspberry Pi 4 hardware support
├── scripts/               # Helper build scripts
├── Makefile              # Build automation
└── DESIGN.md             # Technical design document
```

### Build System Features

- **Cross-Platform Development**: Build on macOS/Linux for Raspberry Pi 4
- **Reproducible Builds**: Nix ensures identical images across environments
- **Minimal Footprint**: Browser-only kiosk with essential services
- **Touch Optimization**: Configured for touchscreen interaction
- **Easy Deployment**: Single SD card image with auto-boot

## Project Status

✅ **Complete Build System**: Nix flakes, Makefile, and helper scripts  
✅ **Hardware Support**: Raspberry Pi 4 with touchscreen optimization  
✅ **Kiosk Configuration**: Chromium browser in fullscreen mode  
✅ **Documentation**: Design document and usage guides  
🚧 **Game Integration**: Default interface with extensible game framework  

## Contributing

This project welcomes contributions to improve the tabletop gaming experience and build system reliability. Please ensure all contributions maintain the reproducible build philosophy and cross-platform compatibility goals.

### Development Workflow

1. Fork and clone the repository
2. Run `./scripts/setup-dev.sh` to initialize your environment
3. Make changes and test with `make test-build`
4. Build and test full image with `make build`
5. Submit pull request with your improvements
