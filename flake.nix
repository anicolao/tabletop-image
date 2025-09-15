{
  description = "Tabletop Image - Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        # Cross-compilation support for ARM64
        pkgsCross = import nixpkgs {
          inherit system;
          crossSystem = {
            config = "aarch64-unknown-linux-gnu";
            system = "aarch64-linux";
          };
        };

        # Development scripts
        buildImageScript = pkgs.writeShellScriptBin "build-image" ''
          set -euo pipefail
          echo "Building tabletop image..."
          cd firmware
          nix build .#tabletopImage --print-build-logs
          echo "Image built successfully!"
          echo "Output: $(readlink -f result)"
        '';

        flashCardScript = pkgs.writeShellScriptBin "flash-card" ''
          set -euo pipefail
          
          if [ $# -ne 1 ]; then
            echo "Usage: flash-card <device>"
            echo "Example: flash-card /dev/disk4"
            exit 1
          fi
          
          DEVICE="$1"
          IMAGE_PATH="firmware/result/sd-image/tabletop-image.img"
          
          if [ ! -f "$IMAGE_PATH" ]; then
            echo "Image not found at $IMAGE_PATH"
            echo "Run 'build-image' first"
            exit 1
          fi
          
          echo "WARNING: This will erase all data on $DEVICE"
          echo "Image: $IMAGE_PATH"
          echo -n "Continue? (y/N) "
          read -r response
          
          if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Aborted"
            exit 1
          fi
          
          echo "Flashing image to $DEVICE..."
          if command -v pv >/dev/null 2>&1; then
            pv "$IMAGE_PATH" | sudo dd of="$DEVICE" bs=4M status=progress
          else
            sudo dd if="$IMAGE_PATH" of="$DEVICE" bs=4M status=progress
          fi
          
          echo "Syncing..."
          sudo sync
          echo "Flash complete!"
        '';

        setupDevScript = pkgs.writeShellScriptBin "setup-dev" ''
          set -euo pipefail
          echo "Setting up tabletop-image development environment..."
          
          # Check if we're in a Nix shell
          if [ -z "''${IN_NIX_SHELL:-}" ]; then
            echo "Please run this inside the development shell:"
            echo "  nix develop"
            exit 1
          fi
          
          # Create firmware directory if it doesn't exist
          if [ ! -d firmware ]; then
            echo "Creating firmware directory..."
            mkdir -p firmware
          fi
          
          echo "Development environment ready!"
          echo ""
          echo "Available commands:"
          echo "  build-image     - Build the tabletop image"
          echo "  flash-card      - Flash image to SD card"
          echo "  make build      - Build using Makefile"
          echo "  make flash      - Flash using Makefile"
          echo ""
          echo "To build an image:"
          echo "  1. cd firmware && nix build .#tabletopImage"
          echo "  2. Or use: build-image"
        '';

      in
      {
        devShells.default = pkgs.mkShell {
          name = "tabletop-image-dev";
          
          buildInputs = with pkgs; [
            # Core Nix tools
            nix
            nixos-rebuild
            nixos-generators
            
            # Development tools
            git
            gnumake
            which
            file
            tree
            
            # Cross-compilation tools
            pkgsCross.stdenv.cc
            qemu
            
            # Image tools
            dosfstools
            mtools
            
            # SD card flashing tools
            pv              # Progress viewer for dd
            coreutils       # Contains dd
            util-linux      # Contains lsblk, fdisk
            
            # Documentation tools
            pandoc
            
            # Custom scripts
            buildImageScript
            flashCardScript
            setupDevScript
          ];

          shellHook = ''
            echo "🎮 Tabletop Image Development Environment"
            echo "========================================="
            echo ""
            echo "Available commands:"
            echo "  setup-dev       - Initialize development environment"
            echo "  build-image     - Build the tabletop image"
            echo "  flash-card      - Flash image to SD card"
            echo "  make <target>   - Use Makefile targets"
            echo ""
            echo "Getting started:"
            echo "  1. Run 'setup-dev' to initialize"
            echo "  2. Run 'build-image' to build the image"
            echo "  3. Run 'flash-card /dev/diskX' to flash to SD card"
            echo ""
            
            # Set up environment variables
            export TABLETOP_IMAGE_ROOT="$(pwd)"
            export NIX_CONFIG="experimental-features = nix-command flakes"
            
            # Ensure firmware directory exists
            [ ! -d firmware ] && mkdir -p firmware
          '';

          # Environment variables for cross-compilation
          CROSS_COMPILE = "aarch64-unknown-linux-gnu-";
          ARCH = "arm64";
        };

        # Formatter for nix files
        formatter = pkgs.nixpkgs-fmt;

        # Development packages that can be installed
        packages = {
          inherit buildImageScript flashCardScript setupDevScript;
        };
      }
    );
}