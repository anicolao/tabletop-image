# Tabletop Image

A Nix-based build system for creating Raspberry Pi 4 SD card images that transform your device into a dedicated tabletop gaming kiosk.

## Overview

This repository enables you to build minimal, reproducible SD card images for Raspberry Pi 4 devices that run as full-screen browser kiosks, specifically designed for playing board games on attached touchscreens. The entire system is built using Nix configuration to ensure consistent, reproducible builds across different development environments.

## Goals

- **Kiosk Mode Browser**: Create a streamlined Raspberry Pi 4 image that boots directly into a full-screen browser without traditional desktop environment overhead
- **Touchscreen Gaming**: Optimized for touchscreen interaction to enable intuitive board game playing experiences
- **Minimal Footprint**: Lightweight system focused solely on the browser and essential services needed for gaming
- **Reproducible Builds**: Leverage Nix package manager to ensure anyone can reproduce identical tabletop firmware images
- **Cross-Platform Development**: Support development on macOS laptops with access to Linux builders for image compilation

## Target Hardware

- **Primary**: Raspberry Pi 4 (all variants)
- **Display**: Touchscreen displays compatible with Raspberry Pi 4
- **Storage**: MicroSD card (minimum 8GB recommended)

## Development Environment

This project is designed to work seamlessly with:
- **Host System**: macOS laptops (primary development environment)
- **Build System**: Linux builders (for compiling ARM images)
- **Package Manager**: Nix (ensuring reproducible builds)

## Key Features

- **Zero-Configuration Boot**: SD card boots directly to gaming interface
- **Touch-Optimized UI**: Responsive design for touchscreen interaction
- **Offline Capable**: Core functionality works without internet connectivity
- **Minimal Attack Surface**: Reduced system components for improved security
- **Easy Updates**: Nix-based configuration allows for straightforward system updates

## Use Cases

- **Digital Board Game Tables**: Transform any touchscreen into a board game surface
- **Game Cafes/Stores**: Provide consistent gaming experiences across multiple stations
- **Home Gaming**: Create dedicated gaming devices from Raspberry Pi hardware
- **Educational Environments**: Classroom gaming setups with standardized configurations

## Project Status

This project is in initial development. The Nix configuration and build system are being designed to support the described goals and use cases.

## Contributing

This project welcomes contributions to improve the tabletop gaming experience and build system reliability. Please ensure all contributions maintain the reproducible build philosophy and cross-platform compatibility goals.
