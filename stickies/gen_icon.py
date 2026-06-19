#!/usr/bin/env python3
"""Generate Stickies app icon — a yellow sticky note with folded corner and pin."""

from PIL import Image, ImageDraw
import math, os

OUT = "Sources/Assets.xcassets/AppIcon.appiconset"

SIZES = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

def rounded_rect(draw, xy, r, fill):
    """Draw a filled rounded rectangle."""
    x1, y1, x2, y2 = xy
    draw.rounded_rectangle(xy, radius=r, fill=fill)

def draw_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    m = size * 0.08  # margin
    r = size * 0.12  # corner radius

    # Shadow
    shadow_off = size * 0.03
    d.rounded_rectangle(
        [m + shadow_off, m + shadow_off, size - m + shadow_off, size - m + shadow_off],
        radius=r, fill=(0, 0, 0, 60)
    )

    # Note body — warm yellow
    body = [m, m, size - m, size - m]
    d.rounded_rectangle(body, radius=r, fill=(255, 220, 80, 255))

    # Folded corner (bottom-right)
    fold = size * 0.18
    d.polygon(
        [(size - m - fold, size - m), (size - m, size - m), (size - m, size - m - fold)],
        fill=(235, 200, 60, 255)
    )
    # Fold shadow line
    d.line(
        [(size - m - fold, size - m), (size - m, size - m - fold)],
        fill=(200, 170, 50, 180), width=max(1, int(size * 0.015))
    )

    # Pin at top-center
    cx = size / 2
    pin_y = m * 0.5
    pin_r = size * 0.07
    # Pin head circle
    d.ellipse(
        [cx - pin_r, pin_y - pin_r * 0.8, cx + pin_r, pin_y + pin_r * 1.2],
        fill=(200, 50, 50, 255)
    )
    # Pin highlight
    hl_r = pin_r * 0.35
    d.ellipse(
        [cx - hl_r, pin_y - pin_r * 0.3, cx + hl_r * 0.6, pin_y + pin_r * 0.3],
        fill=(240, 120, 120, 200)
    )

    # Pencil lines on the note (only for sizes >= 64)
    if size >= 64:
        line_color = (180, 160, 60, 120)
        line_w = max(1, int(size * 0.01))
        line_y = m + size * 0.28
        line_gap = size * 0.08
        line_left = m + size * 0.15
        line_right = size - m - size * 0.15
        for _ in range(4):
            d.line([line_left, line_y, line_right, line_y], fill=line_color, width=line_w)
            line_y += line_gap

    return img

os.makedirs(OUT, exist_ok=True)

for name, sz in SIZES:
    img = draw_icon(sz)
    path = os.path.join(OUT, name)
    img.save(path)
    print(f"  {name} ({sz}x{sz})")

# Write Contents.json
import json
contents = {
    "images": [
        {"size": "16x16", "idiom": "mac", "filename": "icon_16x16.png", "scale": "1x"},
        {"size": "16x16", "idiom": "mac", "filename": "icon_16x16@2x.png", "scale": "2x"},
        {"size": "32x32", "idiom": "mac", "filename": "icon_32x32.png", "scale": "1x"},
        {"size": "32x32", "idiom": "mac", "filename": "icon_32x32@2x.png", "scale": "2x"},
        {"size": "128x128", "idiom": "mac", "filename": "icon_128x128.png", "scale": "1x"},
        {"size": "128x128", "idiom": "mac", "filename": "icon_128x128@2x.png", "scale": "2x"},
        {"size": "256x256", "idiom": "mac", "filename": "icon_256x256.png", "scale": "1x"},
        {"size": "256x256", "idiom": "mac", "filename": "icon_256x256@2x.png", "scale": "2x"},
        {"size": "512x512", "idiom": "mac", "filename": "icon_512x512.png", "scale": "1x"},
        {"size": "512x512", "idiom": "mac", "filename": "icon_512x512@2x.png", "scale": "2x"},
    ],
    "info": {"author": "xcode", "version": 1},
}
with open(os.path.join(OUT, "Contents.json"), "w") as f:
    json.dump(contents, f, indent=2)

print("Done — icon set generated.")
