# Design Document: Tabletop Image Build System

This document outlines the design for the Nix-based build system for the Tabletop Image project. The goal is to create a reproducible, cross-platform development environment for building a minimal kiosk-mode Raspberry Pi 4 image.

## 1. Core Principles

- **Reproducibility**: The entire build process will be managed by Nix to ensure that anyone can produce an identical image from the same source code.
- **Simplicity**: The user interaction with the build system should be as simple as possible. Helper scripts or a `Makefile` will abstract away the complexity of Nix commands.
- **Cross-Platform Development**: The primary development environment is macOS, with the ability to use a Linux builder (either a remote machine or a local VM) for ARM image compilation.

## 2. Directory Structure

The project will be organized as follows:

```
.
├── firmware/
│   ├── flake.nix        # Nix flake for building the RPi image
│   └── configuration.nix  # NixOS configuration for the image
├── flake.nix            # Top-level flake for the development shell
├── Makefile             # Helper scripts for building and flashing
└── README.md
```

## 3. Two-Flake Approach

We will use a two-flake approach to separate the development environment from the image build process.

### 3.1. Top-Level `flake.nix`

The `flake.nix` in the root directory will be responsible for providing a development shell.

- **Inputs**: It will take `nixpkgs` as an input.
- **Outputs**:
    - `devShell`: A Nix development shell that includes all the necessary tools for building the image, such as:
        - `nix`
        - `make`
        - `rsync`
        - Other utilities needed for flashing or interacting with the Raspberry Pi.

This setup allows a developer on any Nix-supported platform (like macOS or Linux) to enter a consistent development environment by running `nix develop`.

### 3.2. `firmware/flake.nix`

The `flake.nix` inside the `firmware/` directory will be responsible for building the actual Raspberry Pi image.

- **Inputs**: It will also take `nixpkgs` as an input.
- **Outputs**:
    - `packages.raspberry-pi-image`: The main output will be a disk image that can be flashed to an SD card. This will be a NixOS configuration tailored for the Raspberry Pi 4.
    - The image will be configured to:
        - Boot directly into a fullscreen web browser (kiosk mode).
        - Enable necessary hardware support for the Raspberry Pi 4 (e.g., graphics, networking).
        - Be as minimal as possible, excluding any services or packages not required for the kiosk mode.

## 4. `Makefile`

A `Makefile` will be provided in the root directory to simplify the build process. It will contain targets such as:

- `make build`: This will execute the `nix build` command for the `firmware` flake, building the SD card image. This command will also include the necessary flags to use a remote builder if configured.
- `make flash DEVICE=/dev/sdX`: This target will flash the built image to a specified SD card device. It will use `dd` or a similar utility. **This will be a destructive operation and the user will be warned.**
- `make clean`: This will remove the build artifacts.

## 5. Build Process Overview

1.  The user clones the repository.
2.  The user runs `nix develop` in the root directory to enter the development shell. This ensures they have all the required tools.
3.  The user runs `make build` to compile the image. If on macOS, this command will automatically use a configured Linux builder.
4.  The user runs `make flash DEVICE=/dev/sdX` to write the image to an SD card.

This design separates concerns, simplifies the user experience, and adheres to the core principles of reproducibility and cross-platform development.
