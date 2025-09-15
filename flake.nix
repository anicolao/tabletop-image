{
  description = "A development environment for building a Raspberry Pi 4 kiosk image.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
      packages = with nixpkgs.legacyPackages.x86_64-linux; [
        make
        nix
      ];
    };

    devShells.aarch64-linux.default = nixpkgs.legacyPackages.aarch64-linux.mkShell {
      packages = with nixpkgs.legacyPackages.aarch64-linux; [
        make
        nix
      ];
    };

    devShells.x86_64-darwin.default = nixpkgs.legacyPackages.x86_64-darwin.mkShell {
      packages = with nixpkgs.legacyPackages.x86_64-darwin; [
        make
        nix
      ];
    };

    devShells.aarch64-darwin.default = nixpkgs.legacyPackages.aarch64-darwin.mkShell {
      packages = with nixpkgs.legacyPackages.aarch64-darwin; [
        make
        nix
      ];
    };
  };
}
