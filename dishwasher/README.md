# Dishwasher — Tiny Cycle Simulator

> Pocket-sized dishwasher with 5 wash programs, animated water, and a cute icon.

## Quick Start

```bash
cd ~/Documents/m5/dishwasher && ./build.sh
```

## Features

| Program | Temp | Duration | Color |
|---|---|---|---|
| Eco 🍃 | 45°C | 2:30 | Green |
| Auto 🔵 | 55°C | 2:00 | Blue |
| HOT 🔥 | 70°C | 1:40 | Red |
| Short ⚡ | 40°C | 0:45 | Yellow |
| Small 🟢 | 35°C | 1:00 | Teal |

- **Animated water level**, bubbles, and steam during cycles
- **Phase indicator**: Pre-wash → Washing → Rinsing → Drying → Done
- **Status light** glows when running
- **Compact**: 210×160 px, non-resizable
- **App icon** — blue dishwasher with racks and control panel

## Architecture

```
Sources/
├── DishwasherApp.swift     # @main entry (210×160 fixed window)
├── DishwasherView.swift    # WashProgram, WashPhase, animation, timer
└── Assets.xcassets/        # App icon
```
