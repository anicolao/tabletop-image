# Troubleshooting Nix Flake Issues

If you're experiencing flake validation errors, here are the most common issues and solutions:

## Quick Fix Commands

```bash
# 1. Ensure flakes are enabled
export NIX_CONFIG="experimental-features = nix-command flakes"

# 2. Test the main flake
nix flake check --show-trace

# 3. Test the firmware flake
cd firmware && nix flake check --show-trace

# 4. Update dependencies if needed
nix flake update

# 5. Use our debug script
./scripts/debug-flake.sh
```

## Common Issues Fixed

### 1. Deprecated `defaultPackage` Warning
- **Fixed**: Replaced `defaultPackage.${system}` with `packages.default`
- **Location**: `firmware/flake.nix`

### 2. Missing or Incorrect Hardware Modules  
- **Fixed**: Removed `hardware.raspberry-pi."4"` references
- **Fixed**: Updated to use standard `hardware.graphics` instead of `hardware.opengl`
- **Location**: `firmware/modules/hardware-rpi4.nix`

### 3. Audio System Updates
- **Fixed**: Replaced deprecated PulseAudio with modern PipeWire
- **Location**: Both flake files

### 4. Package Version Updates
- **Fixed**: Updated to NixOS 24.11 for better hardware support
- **Fixed**: Removed non-existent `raspberrypifw` package reference

## Development Workflow

1. **Enter the development shell**:
   ```bash
   nix develop
   ```

2. **Build the image**:
   ```bash
   # From within the dev shell:
   build-image
   
   # Or manually:
   cd firmware && nix build .#tabletopImage
   ```

3. **Flash to SD card**:
   ```bash
   flash-card /dev/diskX
   ```

## If You Still Have Issues

1. **Run the debug script**:
   ```bash
   ./scripts/debug-flake.sh
   ```

2. **Check your Nix configuration**:
   ```bash
   # Make sure flakes are enabled
   cat ~/.config/nix/nix.conf
   # Should contain: experimental-features = nix-command flakes
   ```

3. **Clear Nix cache**:
   ```bash
   nix flake check --refresh
   ```

4. **Verify Git status**:
   ```bash
   git status
   # Clean working tree reduces warnings
   ```

## Expected Output

After fixes, you should see:
```
✅ All validation checks passed! 🎉
```

When entering the development shell:
```
🎮 Tabletop Image Development Environment
=========================================

Available commands:
  setup-dev       - Initialize development environment
  build-image     - Build the tabletop image
  flash-card      - Flash image to SD card
  make <target>   - Use Makefile targets
```