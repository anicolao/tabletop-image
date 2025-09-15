{
  description = "Tabletop Image - Raspberry Pi 4 Kiosk Firmware";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators }:
    let
      system = "x86_64-linux";  # Build system
      targetSystem = "aarch64-linux";  # Target Raspberry Pi 4
      
      # Cross-compilation setup
      pkgs = import nixpkgs {
        inherit system;
        crossSystem = {
          config = "aarch64-unknown-linux-gnu";
          system = targetSystem;
        };
      };

      # Base NixOS configuration for Raspberry Pi 4
      tabletopConfiguration = { config, pkgs, lib, ... }: {
        imports = [
          ./modules/kiosk.nix
          ./modules/hardware-rpi4.nix
        ];

        # Basic system configuration
        system.stateVersion = "24.05";
        
        # Networking
        networking = {
          hostName = "tabletop-kiosk";
          networkmanager.enable = true;
          wireless.enable = false;  # Disabled in favor of NetworkManager
        };

        # User configuration
        users.users.kiosk = {
          isNormalUser = true;
          extraGroups = [ "wheel" "audio" "video" "input" ];
          # No password - auto-login
          hashedPassword = null;
        };

        # Auto-login configuration
        services.getty.autologinUser = "kiosk";

        # Disable unnecessary services for minimal footprint
        services = {
          openssh.enable = false;  # No remote access by default
          udisks2.enable = false;
          printing.enable = false;
          avahi.enable = false;
          blueman.enable = false;
        };

        # Minimal package set
        environment.systemPackages = with pkgs; [
          # Essential tools only
          coreutils
          util-linux
          nano  # Basic editor for emergency access
        ];

        # Boot configuration
        boot = {
          loader = {
            grub.enable = false;
            generic-extlinux-compatible.enable = true;
          };
          
          # Kernel parameters for Raspberry Pi 4
          kernelParams = [
            "console=serial0,115200"
            "console=tty1"
            "cma=128M"  # GPU memory
          ];
          
          # Enable required kernel modules
          kernelModules = [ "vc4" "bcm2835_dma" "i2c_bcm2835" ];
        };

        # Hardware support
        hardware = {
          raspberry-pi."4".apply-overlays-dtmerge.enable = true;
          deviceTree = {
            enable = true;
            filter = "*rpi-4-*.dtb";
          };
        };

        # Graphics and input
        services.xserver = {
          enable = true;
          displayManager.lightdm.enable = false;
          displayManager.startx.enable = true;
          
          # No window manager - direct Chromium launch
          windowManager.session = [{
            name = "chromium-kiosk";
            start = "";
          }];
          
          # Touch input support
          libinput = {
            enable = true;
            touchpad.tapping = true;
          };
        };

        # Audio support
        sound.enable = true;
        hardware.pulseaudio.enable = true;

        # Security
        security.sudo.wheelNeedsPassword = false;  # For emergency access
      };

    in
    {
      # Generate the SD card image
      packages.${system} = {
        tabletopImage = nixos-generators.nixosGenerate {
          system = targetSystem;
          modules = [ tabletopConfiguration ];
          format = "sd-aarch64";
          
          # Customize the generated image
          specialArgs = {
            inherit nixpkgs;
          };
        };
      };

      # Default package
      defaultPackage.${system} = self.packages.${system}.tabletopImage;

      # NixOS configuration for testing/development
      nixosConfigurations.tabletop = nixpkgs.lib.nixosSystem {
        system = targetSystem;
        modules = [ tabletopConfiguration ];
      };

      # Development shell for firmware work
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nixos-generators
          qemu
        ];
        
        shellHook = ''
          echo "🔧 Firmware development shell"
          echo "Available commands:"
          echo "  nix build .#tabletopImage  - Build SD card image"
          echo "  nixos-rebuild build --flake .#tabletop  - Build system"
        '';
      };
    };
}