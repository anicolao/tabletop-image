{ config, lib, pkgs, ... }:

{
  # Raspberry Pi 4 specific hardware configuration
  boot = {
    # Use the latest LTS kernel
    kernelPackages = pkgs.linuxPackages_rpi4;
    
    # Raspberry Pi 4 bootloader
    loader.raspberryPi = {
      enable = true;
      version = 4;
      uboot.enable = true;
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
      "gpu_mem=128"
      "cma=128M"
      
      # Enable 64-bit mode
      "arm_64bit=1"
      
      # Disable rainbow splash screen
      "disable_splash=1"
      
      # Boot timing optimization
      "boot_delay=0"
      
      # USB configuration
      "dwc_otg.lpm_enable=0"
      
      # Audio configuration
      "snd_bcm2835.enable_headphones=1"
    ];
    
    # Additional firmware configuration
    loader.raspberryPi.firmwareConfig = ''
      # GPU configuration
      gpu_mem=128
      
      # Display configuration
      hdmi_group=2
      hdmi_mode=82
      hdmi_drive=2
      
      # Enable HDMI hotplug
      hdmi_force_hotplug=1
      
      # Audio configuration
      dtparam=audio=on
      
      # I2C for touchscreens
      dtparam=i2c_arm=on
      dtparam=i2c1=on
      
      # SPI configuration
      dtparam=spi=on
      
      # Enable camera (in case needed for future features)
      start_x=0
      
      # Disable ACT LED (power saving)
      dtparam=act_led_trigger=none
      dtparam=act_led_activelow=off
      
      # Overclock settings (conservative for stability)
      arm_freq=1500
      core_freq=500
      sdram_freq=500
      over_voltage=2
      
      # Temperature limit (prevent throttling)
      temp_limit=80
    '';
  };

  # Hardware support packages
  hardware = {
    # Enable Raspberry Pi 4 specific hardware
    raspberry-pi."4" = {
      apply-overlays-dtmerge.enable = true;
      fkms-3d.enable = true;
    };
    
    # Device tree configuration
    deviceTree = {
      enable = true;
      filter = "*rpi-4-*.dtb";
      
      # Enable touchscreen overlays
      overlays = [
        {
          name = "vc4-fkms-v3d";
          dtsText = ''
            /dts-v1/;
            /plugin/;
            
            / {
              compatible = "brcm,bcm2835";
              
              fragment@0 {
                target-path = "/chosen";
                __overlay__ {
                  bootargs = "vc4.fkms_max_refresh_rate=60";
                };
              };
            };
          '';
        }
      ];
    };
    
    # Enable GPU acceleration
    opengl = {
      enable = true;
      driSupport = true;
      driSupport32Bit = false;  # Not needed for ARM64
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
  
  hardware.pulseaudio = {
    enable = true;
    support32Bit = false;  # Not needed for ARM64
    
    # Audio configuration for Raspberry Pi 4
    configFile = pkgs.runCommand "default.pa" {} ''
      cat ${pkgs.pulseaudio}/etc/pulse/default.pa > $out
      echo "load-module module-alsa-sink device=hw:0,0" >> $out
      echo "load-module module-alsa-source device=hw:0,0" >> $out
    '';
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
    raspberrypifw
    wireless-regdb
  ];

  # Enable zram for better memory management on Pi 4
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 25;
  };
}