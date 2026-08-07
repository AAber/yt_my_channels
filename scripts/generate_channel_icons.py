#!/usr/bin/env python3
"""
generate_channel_icons.py
--------------------------
Generates colored placeholder PNG icons for each channel/singer defined in CHANNELS.
Run this script whenever you add or change channels.

Usage:
    python3 scripts/generate_channel_icons.py

Output:
    assets/icon/<filename>.png  for each entry in CHANNELS
"""

from PIL import Image, ImageDraw
import os

# ─── EDIT THIS LIST to add/change channels ────────────────────────────────────
# (filename_without_ext, display_label, background_hex_color)
CHANNELS = [
    ("taylor",  "Taylor\nSwift",   "#FF69B4"),
    ("ed",      "Ed\nSheeran",     "#FF8C00"),
    ("adele",   "Adele",           "#4B0082"),
    ("ariana",  "Ariana\nGrande",  "#FF1493"),
    ("beyonce", "Beyoncé",         "#DAA520"),
    ("drake",   "Drake",           "#1C1C1C"),
    ("billie",  "Billie\nEilish",  "#00C864"),
    ("weeknd",  "The\nWeeknd",     "#8B0000"),
]
# ──────────────────────────────────────────────────────────────────────────────

ICON_SIZE = 200
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")


def generate_icon(filename: str, label: str, bg: str) -> None:
    img = Image.new("RGB", (ICON_SIZE, ICON_SIZE), bg)
    draw = ImageDraw.Draw(img)
    lines = label.split("\n")
    line_height = 36
    y = ICON_SIZE // 2 - (len(lines) * line_height) // 2
    for line in lines:
        bbox = draw.textbbox((0, 0), line)
        w = bbox[2] - bbox[0]
        draw.text(((ICON_SIZE - w) // 2, y), line, fill="white")
        y += line_height
    path = os.path.join(OUT_DIR, f"{filename}.png")
    img.save(path)
    print(f"  ✓ {path}")


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    print(f"Generating {len(CHANNELS)} icons into {os.path.abspath(OUT_DIR)}/\n")
    for fname, label, color in CHANNELS:
        generate_icon(fname, label, color)
    print("\nDone! Remember to run update_pubspec_assets.py next.")
