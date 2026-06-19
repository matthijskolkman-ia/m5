# Stickies — macOS Notes App

> Minimal dark-themed sticky notes app with SQLite persistence.

## Quick Start

```bash
cd ~/Documents/m5/stickies && ./build.sh
# or open Stickies.xcodeproj in Xcode
```

## Features

- **3-panel layout**: sidebar (25%) · sticky canvas (50%) · properties (25%)
- **8 note colors**: yellow, pink, green, blue, purple, orange, white, mint
- **Pin notes** to keep them at the top
- **Font sizes**: small / medium / large
- **Auto-save** — every edit persists instantly
- **Click-to-view** without re-sorting — only moves when edited
- **App icon** — yellow sticky note with red pin and folded corner

## Storage

- SQLite at `~/Library/Application Support/Stickies/stickies.sqlite3`
- Table: `notes` (id, title, content, color, created_at, modified_at, is_pinned, font_size)

## Architecture

```
Sources/
├── StickiesApp.swift          # @main entry
├── Models/Note.swift           # Note model, NoteColor, NoteFontSize
├── Services/Database.swift     # SQLite3 wrapper
├── Views/
│   ├── ContentView.swift       # NotesStore + 3-panel layout
│   ├── NotesListSidebar.swift  # Left: paginated note list
│   ├── NoteCanvasView.swift    # Center: sticky note editor
│   └── NoteDetailPanel.swift   # Right: color, font, pin, delete
└── Assets.xcassets/            # App icon
```
