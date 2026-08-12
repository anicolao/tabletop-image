# Tabletop Image Build System Design

## Architecture Overview

This project implements a two-tier Nix flake architecture for building reproducible Raspberry Pi 4 tabletop gaming kiosk images:

```
tabletop-image/
├── flake.nix              # Development environment & tools
├── firmware/
│   ├── flake.nix          # Image building configuration
│   ├── configuration.nix  # NixOS system configuration
│   └── modules/           # Custom NixOS modules
├── scripts/               # Helper build scripts
├── Makefile              # Build automation
└── DESIGN.md             # This document
```

## Design Principles

### 1. Separation of Concerns
- **Top-level flake.nix**: Provides development environment with all necessary tools
- **firmware/flake.nix**: Handles actual image compilation and ARM cross-compilation

### 2. Reproducible Builds
- All dependencies locked via Nix flakes
- Deterministic image generation
- Cross-platform consistency (macOS dev → Linux builds)

### 3. Minimal Image Footprint
- Browser-only kiosk mode
- No desktop environment overhead
- Essential services only

## Component Details

### Development Environment (Top-level flake.nix)

**Purpose**: Provide all tools needed for development and building

**Includes**:
- Nix package manager tools
- Cross-compilation utilities
- Image flashing tools (for SD cards)
- Development utilities (git, make, etc.)
- Documentation tools

**Target Users**: Developers working on macOS/Linux wanting to build images

### Firmware Build System (firmware/flake.nix)

**Purpose**: Generate minimal NixOS-based Raspberry Pi 4 images

**Key Features**:
- ARM64 cross-compilation
- Minimal NixOS configuration
- Chromium browser in kiosk mode
- Touchscreen drivers and optimization
- Auto-boot to browser interface
- SD card image generation

### Build Automation

**Makefile Goals**:
- `make dev-shell`: Enter development environment
- `make build`: Build the tabletop image
- `make flash DEVICE=/dev/diskX`: Flash image to SD card
- `make clean`: Clean build artifacts

**Helper Scripts**:
- `scripts/build-image.sh`: Orchestrate the build process
- `scripts/flash-card.sh`: Safe SD card flashing with verification
- `scripts/setup-dev.sh`: Initialize development environment

## Target System Configuration

### Hardware Support
- **Platform**: Raspberry Pi 4 (all variants)
- **Architecture**: ARM64/aarch64
- **Storage**: MicroSD card (8GB minimum)
- **Display**: Touchscreen via HDMI/DSI

### Software Stack
- **Base**: NixOS (minimal configuration)
- **Init**: systemd
- **Browser**: Chromium (kiosk mode)
- **Window Manager**: None (direct framebuffer)
- **Services**: Essential hardware drivers only

### Kiosk Configuration
- Auto-login without desktop
- Chromium launches fullscreen
- Touch input optimization
- No user interface chrome
- Local storage for offline games

## Build Process Flow

1. **Development Setup**:
   ```bash
   nix develop  # Enter dev shell from top-level flake
   ```

2. **Image Building**:
   ```bash
   make build   # Cross-compile ARM image using firmware/flake.nix
   ```

3. **SD Card Preparation**:
   ```bash
   make flash DEVICE=/dev/diskX  # Flash to SD card
   ```

4. **Deployment**:
   - Insert SD card into Raspberry Pi 4
   - Power on device
   - System boots directly to browser kiosk

## Cross-Platform Considerations

### macOS Development
- Nix provides Linux builders for ARM cross-compilation
- Development tools run natively on macOS
- Image building happens on remote Linux builders

### Build Caching
- Nix binary cache for common dependencies
- Local caching of build artifacts
- Cachix integration for CI/CD

## Future Extensions

- **Multi-device Management**: Fleet configuration
- **Game Integration**: Pre-installed web games
- **Network Configuration**: WiFi setup automation
- **Monitoring**: Remote health checking
- **Updates**: Over-the-air system updates

## Security Considerations

- Minimal attack surface (browser-only)
- No SSH by default (physical access only)
- Read-only root filesystem
- Automatic security updates via Nix channels