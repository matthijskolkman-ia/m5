# SysMon — Compact System Monitor

> Mac activity monitor in a tiny 260×180 window. Live kernel stats.

## Quick Start

```bash
cd ~/Documents/m5/sysmon && ./build.sh
```

## Features

| Stat | Source | Detail |
|---|---|---|
| **CPU** | `host_processor_info` | Green/yellow/red bar |
| **MEM** | `host_statistics64` | Used / Total with bar |
| **DSK** | Filesystem attributes | Used / Total |
| **LOAD** | `getloadavg()` | 1m / 5m / 15m |
| **PROCS** | `sysctl(KERN_PROC)` | Running process count |
| **Uptime** | `sysctl(KERN_BOOTTIME)` | Days + hours |

- Updates every 2 seconds
- Color-coded thresholds: green → yellow → red
- Real macOS kernel stats — no simulated data
- App icon — dark dashboard with bar chart

## Architecture

```
Sources/
├── SysMonApp.swift      # @main entry (260×180 fixed)
├── SysMonView.swift     # SysStats fetcher + stat bars + rows
└── Assets.xcassets/     # App icon
```
