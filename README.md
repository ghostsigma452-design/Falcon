# <Falcon>

> A 3D game engine written in **Nim**, built on **Vulkan 1.4** via [vk14](https://github.com/treeform/vk14), with **SDL2** for windowing and input.

[![Nim](https://img.shields.io/badge/Nim-2.0-blue)](https://nim-lang.org)
[![Vulkan](https://img.shields.io/badge/Vulkan-1.4-green)](https://vulkan.lunarg.com)
[![Status](https://img.shields.io/badge/status-WIP-orange)]()

**<engine-name>** is a work-in-progress game engine that uses
[**vk14**](https://github.com/treeform/vk14) as its Vulkan 1.4 rendering backend
and **SDL2** for window creation, input, and event handling. The core stays
small, readable, and fast.

> ⚠️ Under active development — APIs are unstable.

## Requirements

- [Nim](https://nim-lang.org) 2.0+
- [Vulkan 1.4](https://vulkan.lunarg.com/sdk/home) driver
- **SDL2** development libraries

## Getting Started
```sh
git clone https://github.com/ghostsigma452-design/Falcon
cd Falcon
nimble install vk14
nimble install sdl2
nim c main.nim
./main # if on linux
./main.exe # if on windows
