"""
🌀 Dryer — Watches ~/Desktop/inbox/dryer for images.
Auto-converts HEIC → PNG, creates thumbnails, outputs to outbox.

Requirements: pip install watchdog Pillow pillow-heif
"""
import os
import time
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

try:
    from PIL import Image
    from pillow_heif import register_heif_opener
    register_heif_opener()
    HAS_PILLOW = True
except ImportError:
    HAS_PILLOW = False
    print("⚠️  Install pillow + pillow-heif: pip install Pillow pillow-heif")

INBOX = Path.home() / "Desktop" / "inbox" / "dryer"
OUTBOX = Path.home() / "Desktop" / "outbox"
THUMB_SIZE = (400, 400)


def dry_image(filepath: Path):
    """Convert HEIC to PNG, create thumbnail, save to outbox."""
    if not HAS_PILLOW:
        print("⚠️  Pillow not installed. Skipping.")
        return

    OUTBOX.mkdir(parents=True, exist_ok=True)
    base = filepath.stem

    try:
        img = Image.open(filepath)

        # Convert to PNG if needed
        png_path = OUTBOX / f"{base}.png"
        if not png_path.exists():
            if img.mode in ("RGBA", "P"):
                img = img.convert("RGBA")
            img.save(png_path, "PNG")
            print(f"🌀 Converted: {filepath.name} → {png_path.name}")

        # Create thumbnail
        thumb_path = OUTBOX / f"{base}_thumb.png"
        if not thumb_path.exists():
            thumb = img.copy()
            thumb.thumbnail(THUMB_SIZE)
            thumb.save(thumb_path, "PNG")
            print(f"🌀 Thumbnail: {thumb_path.name}")

        print(f"   Size: {img.size[0]}×{img.size[1]} | Mode: {img.mode}")

    except Exception as e:
        print(f"⚠️  Failed to dry {filepath.name}: {e}")


def dry_any_file(filepath: Path):
    """Route file to the right dryer."""
    ext = filepath.suffix.lower()
    if ext in (".heic", ".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tiff"):
        dry_image(filepath)
    else:
        # Just copy unknown files
        dest = OUTBOX / filepath.name
        if not dest.exists():
            import shutil
            shutil.copy2(filepath, dest)
            print(f"🌀 Copied: {filepath.name} → outbox/")


class DryHandler(FileSystemEventHandler):
    def on_created(self, event):
        if not event.is_directory:
            time.sleep(0.5)
            path = Path(event.src_path)
            if path.exists() and path.is_file():
                dry_any_file(path)


def main():
    INBOX.mkdir(parents=True, exist_ok=True)
    OUTBOX.mkdir(parents=True, exist_ok=True)

    print(f"""
╔══════════════════════════════════════╗
║           🌀 Dryer                  ║
║   Drop images into inbox/dryer/     ║
║   HEIC→PNG + thumbnails → outbox/  ║
╠══════════════════════════════════════╣
║  Inbox:  {str(INBOX):<26} ║
║  Outbox: {str(OUTBOX):<26} ║
╚══════════════════════════════════════╝
""")

    # Process existing
    for f in INBOX.iterdir():
        if f.is_file():
            dry_any_file(f)

    observer = Observer()
    observer.schedule(DryHandler(), str(INBOX), recursive=False)
    observer.start()
    print("👀 Watching... (Ctrl+C to stop)\n")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()
    print("\n🌀 Dryer stopped.")


if __name__ == "__main__":
    main()
