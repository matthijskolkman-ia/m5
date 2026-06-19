# NotionLite — Minimal Notion Clone

> Condensed Notion–style page editor with blocks, cover colors, and SQLite.

## Quick Start

```bash
cd ~/Documents/m5/notion-lite && ./build.sh
```

## Features

- **3-panel layout**: sidebar (22%) · page editor (53%) · properties (25%)
- **8 block types**: heading 1/2/3, paragraph, bullet, to-do, divider, quote
- **9 cover colors**: gray, red, orange, yellow, green, teal, blue, purple, pink
- **20 page icons** to pick from
- **Favorites** keep pages pinned
- **Click-to-view** without re-sorting
- **App icon** — dark page with blue accent

## Storage

- SQLite at `~/Library/Application Support/NotionLite/notionlite.sqlite3`
- Tables: `pages`, `blocks` (foreign key cascade)

## Architecture

```
Sources/
├── NotionLiteApp.swift         # @main entry
├── Models/Page.swift           # Page, Block, BlockType, CoverColor
├── Services/Database.swift     # SQLite3 wrapper
├── Views/
│   ├── ContentView.swift       # PageStore + 3-panel layout
│   ├── PageListSidebar.swift   # Left: page list with favorites
│   ├── PageEditorView.swift    # Center: cover + title + blocks
│   └── PageDetailPanel.swift   # Right: icon, cover, stats, delete
└── Assets.xcassets/            # App icon
```
