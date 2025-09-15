{
  description = "NixOS configuration for a Raspberry Pi 4 kiosk.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators }: {
    packages.aarch64-linux.default = nixos-generators.nixosGenerate {
      system = "aarch64-linux";
      format = "sd-image";
      modules = [
        ./configuration.nix
      ];
    };
  };
}
