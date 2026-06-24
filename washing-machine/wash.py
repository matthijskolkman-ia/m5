"""
🧺 Washing Machine — Drop files in, they get sorted.
Monitors ~/Desktop/inbox and auto-organizes by type into ~/Documents/m5/sorted/
"""
import os
import shutil
import time
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

INBOX = Path.home() / "Desktop" / "inbox"
OUTBOX = Path.home() / "Documents" / "m5" / "sorted"

# File type → destination folder
SORT_RULES = {
    # Images
    (".png", ".jpg", ".jpeg", ".gif", ".webp", ".heic", ".svg", ".bmp"): "images",
    # Video
    (".mp4", ".mov", ".mkv", ".avi", ".webm"): "videos",
    # Audio
    (".mp3", ".wav", ".flac", ".aac", ".m4a", ".ogg"): "audio",
    # Documents
    (".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".pages", ".numbers", ".key"): "documents",
    # Code
    (".py", ".swift", ".js", ".ts", ".html", ".css", ".json", ".yaml", ".yml",
     ".toml", ".md", ".sh", ".go", ".rs", ".zig", ".php", ".c", ".h", ".cpp"): "code",
    # Archives
    (".zip", ".tar", ".gz", ".bz2", ".xz", ".7z", ".rar"): "archives",
    # Data
    (".csv", ".tsv", ".sql", ".sqlite", ".db"): "data",
}

def sort_file(filepath: Path):
    """Move a file to its sorted destination."""
    ext = filepath.suffix.lower()
    dest_folder = None

    for extensions, folder in SORT_RULES.items():
        if ext in extensions:
            dest_folder = folder
            break

    if dest_folder is None:
        dest_folder = "other"

    dest_dir = OUTBOX / dest_folder
    dest_dir.mkdir(parents=True, exist_ok=True)

    # Avoid overwrites
    dest = dest_dir / filepath.name
    counter = 1
    while dest.exists():
        stem = filepath.stem
        dest = dest_dir / f"{stem}_{counter}{filepath.suffix}"
        counter += 1

    try:
        shutil.move(str(filepath), str(dest))
        print(f"🧺 Sorted: {filepath.name} → {dest_folder}/")
    except Exception as e:
        print(f"⚠️  Failed to move {filepath.name}: {e}")


class WashHandler(FileSystemEventHandler):
    def on_created(self, event):
        if not event.is_directory:
            # Wait a moment for file to finish copying
            time.sleep(0.5)
            path = Path(event.src_path)
            if path.exists() and path.is_file():
                sort_file(path)


def main():
    INBOX.mkdir(parents=True, exist_ok=True)
    OUTBOX.mkdir(parents=True, exist_ok=True)

    print(f"""
╔══════════════════════════════════════╗
║         🧺 Washing Machine          ║
║   Drop files into Desktop/inbox     ║
║   They auto-sort into m5/sorted/    ║
╠══════════════════════════════════════╣
║  Inbox:  {str(INBOX):<26} ║
║  Outbox: {str(OUTBOX):<26} ║
╚══════════════════════════════════════╝
""")

    # Sort any existing files
    for f in INBOX.iterdir():
        if f.is_file():
            sort_file(f)

    observer = Observer()
    observer.schedule(WashHandler(), str(INBOX), recursive=False)
    observer.start()
    print("👀 Watching... (Ctrl+C to stop)\n")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
    print("\n🧺 Washing machine stopped.")


if __name__ == "__main__":
    main()
