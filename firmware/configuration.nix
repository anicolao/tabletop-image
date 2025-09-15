{ config, pkgs, ... }:

{
  imports = [
    (pkgs.path + "/nixos/modules/installer/cd-dvd/sd-image-aarch64.nix")
  ];

  # Nixpkgs architecture
  nixpkgs.hostPlatform = "aarch64-linux";

  # Bootloader
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  # Networking
  networking.hostName = "tabletop";
  networking.wireless.enable = true;
  networking.networkmanager.enable = true;

  # Kiosk mode setup
  services.xserver = {
    enable = true;
    layout = "us";
    xkbVariant = "";
    displayManager.startx.enable = true;
    windowManager.openbox = {
      enable = true;
      autostart = ''
        xset -dpms
        xset s off
        xset s noblank
        firefox --kiosk "https://www.google.com" &
      '';
    };
  };

  # Sound
  sound.enable = true;
  hardware.pulseaudio.enable = true;

  # OpenGL
  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [
      amlogic-gpu-fw
    ];
  };


  # Users
  users.users.kiosk = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "audio" ];
    password = "kiosk";
  };
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "kiosk";

  # Packages
  environment.systemPackages = with pkgs; [
    firefox
    git
  ];

  # System services
  services.openssh.enable = true;

  # System configuration
  system.stateVersion = "23.11";
}
