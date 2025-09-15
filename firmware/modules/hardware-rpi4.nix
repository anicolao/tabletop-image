{ config, lib, pkgs, ... }:

{
  # Raspberry Pi 4 specific hardware configuration
  # This module configures raspberry-pi hardware support
  boot = {
    # Use the latest stable kernel
    kernelPackages = pkgs.linuxPackages;
    
    # Raspberry Pi 4 bootloader configuration
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
    
    # Required kernel modules for Raspberry Pi 4
    kernelModules = [
      # GPU/Video
      "vc4"
      "v3d"
      "bcm2835_dma"
      
      # I2C for touchscreens
      "i2c_bcm2835"
      "i2c_dev"
      
      # SPI
      "spi_bcm2835"
      
      # Audio
      "snd_bcm2835"
      
      # USB
      "dwc2"
      "usbhid"
      
      # Input devices
      "uinput"
      "evdev"
    ];
    
    # Kernel parameters for optimal Raspberry Pi 4 performance
    kernelParams = [
      # Console configuration
      "console=serial0,115200"
      "console=tty1"
      
      # GPU memory split (128MB for GPU)
      "cma=128M"
      
      # Disable rainbow splash screen
      "disable_splash=1"
      
      # Boot timing optimization
      "boot_delay=0"
      
      # USB configuration
      "dwc_otg.lpm_enable=0"
      
      # Audio configuration
      "snd_bcm2835.enable_headphones=1"
    ];
  };

  # Hardware support packages
  hardware = {
    # Enable GPU acceleration
    graphics = {
      enable = true;
      enable32Bit = false;  # Not needed for ARM64
    };
  };

  # Power management
  powerManagement = {
    enable = false;  # Disable for kiosk stability
    cpuFreqGovernor = "performance";  # Maximum performance
  };

  # Network hardware
  networking = {
    # Enable WiFi hardware
    wireless.enable = lib.mkDefault false;  # Use NetworkManager instead
    
    # Enable Ethernet
    useDHCP = lib.mkDefault true;
    
    # Interface configuration
    interfaces = {
      eth0.useDHCP = true;
      wlan0.useDHCP = true;
    };
  };

  # Audio hardware
  sound = {
    enable = true;
    mediaKeys.enable = false;  # Not needed for kiosk
  };
  
  # Use PipeWire for modern audio handling
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # Input devices and touchscreen support
  services.xserver = {
    # Video drivers
    videoDrivers = [ "modesetting" ];
    
    # Input configuration
    inputClassSections = [
      # Touchscreen configuration
      ''
        Identifier "TouchScreen"
        MatchIsTouchscreen "on"
        Driver "libinput"
        Option "Calibration" "0 0 0 0"
        Option "InvertX" "false"
        Option "InvertY" "false"
        Option "SwapAxes" "false"
      ''
      
      # USB mouse configuration
      ''
        Identifier "USB Mouse"
        MatchIsPointer "on"
        MatchDevicePath "/dev/input/event*"
        Driver "libinput"
      ''
    ];
  };

  # USB and input device rules
  services.udev = {
    extraRules = ''
      # Touchscreen permissions
      SUBSYSTEM=="input", GROUP="input", MODE="0664"
      
      # USB device permissions
      SUBSYSTEM=="usb", ATTR{idVendor}=="0eef", MODE="0666", GROUP="users"
      
      # I2C device permissions for touchscreens
      SUBSYSTEM=="i2c-dev", GROUP="i2c", MODE="0664"
      
      # GPIO permissions (for future expansion)
      SUBSYSTEM=="gpio", GROUP="gpio", MODE="0664"
    '';
  };

  # Additional groups for hardware access
  users.groups = {
    i2c = {};
    gpio = {};
  };

  # Add kiosk user to hardware groups
  users.users.kiosk.extraGroups = [ "audio" "video" "input" "i2c" "gpio" "dialout" ];

  # System services for hardware
  systemd.services = {
    # Disable unnecessary hardware services
    ModemManager.enable = false;
    
    # Custom service to set up hardware on boot
    rpi4-hardware-setup = {
      description = "Raspberry Pi 4 Hardware Setup";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-udev-settle.service" ];
      
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "rpi4-setup" ''
          # Set up I2C permissions
          [ -e /dev/i2c-1 ] && chmod 664 /dev/i2c-1 && chgrp i2c /dev/i2c-1
          
          # Set up GPIO permissions
          [ -d /sys/class/gpio ] && chgrp -R gpio /sys/class/gpio && chmod -R 664 /sys/class/gpio
          
          # Optimize for touchscreen responsiveness
          echo 1 > /sys/module/usbcore/parameters/autosuspend || true
          
          # Set CPU governor to performance
          echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor || true
          echo performance > /sys/devices/system/cpu/cpu1/cpufreq/scaling_governor || true
          echo performance > /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor || true
          echo performance > /sys/devices/system/cpu/cpu3/cpufreq/scaling_governor || true
        '';
      };
    };
  };

  # Firmware packages
  hardware.firmware = with pkgs; [
    # Standard firmware for wireless devices
    wireless-regdb
  ];

  # Enable zram for better memory management on Pi 4
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };
}