#!/usr/bin/env python3
"""
generate_splash_icon.py
------------------------
Processes assets/sia.jpg into all required splash and app icon sizes.
Crops from 18% down to avoid showing the face at the top.

Usage:
    python3 scripts/generate_splash_icon.py
"""

from PIL import Image
import os

SRC = os.path.join(os.path.dirname(__file__), "..", "assets", "sia.jpg")
ICON_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")
ASSETS_DIR = os.path.join(os.path.dirname(__file__), "..", "assets")


def process():
    img = Image.open(SRC).convert("RGBA")
    w, h = img.size
    print(f"Original: {w}x{h}")

    # Crop top 18% to hide face, keep wig/body
    top = int(h * 0.18)
    crop = img.crop((0, top, w, h))
    cw, ch = crop.size

    # Square-crop centered horizontally
    side = min(cw, ch)
    left = (cw - side) // 2
    square = crop.crop((left, 0, left + side, side))
    print(f"Square crop: {square.size}")

    # app_icon.png (1024x1024)
    app_icon = square.resize((1024, 1024), Image.LANCZOS).convert("RGB")
    app_icon.save(os.path.join(ICON_DIR, "app_icon.png"))
    print("  app_icon.png")

    # app_icon1024.png
    app_icon.save(os.path.join(ICON_DIR, "app_icon1024.png"))
    print("  app_icon1024.png")

    # app_icon_foreground.png (adaptive icon, image centered with padding)
    fg = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    inner = square.resize((768, 768), Image.LANCZOS).convert("RGBA")
    fg.paste(inner, (128, 128), inner)
    fg.save(os.path.join(ICON_DIR, "app_icon_foreground.png"))
    print("  app_icon_foreground.png")

    # sia_splash.png (1152x1152 recommended by flutter_native_splash)
    splash = square.resize((1152, 1152), Image.LANCZOS).convert("RGBA")
    splash.save(os.path.join(ASSETS_DIR, "sia_splash.png"))
    print("  sia_splash.png")

    print("\nDone! Run: flutter pub run flutter_native_splash:create")
    print("      and: flutter pub run flutter_launcher_icons")


if __name__ == "__main__":
    process()
