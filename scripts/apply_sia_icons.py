#!/usr/bin/env python3
"""
apply_sia_icons.py
-------------------
Directly writes Sia's image into all Android mipmap ic_launcher.png files
and the iOS AppIcon assets, bypassing flutter_launcher_icons.

Usage:
    python3 scripts/apply_sia_icons.py
"""

from PIL import Image
import os

SRC = os.path.join(os.path.dirname(__file__), "..", "assets", "sia.jpg")
RES = os.path.join(os.path.dirname(__file__), "..", "android", "app", "src", "main", "res")
IOS_ICONS = os.path.join(os.path.dirname(__file__), "..", "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")

# Android mipmap densities -> px size
ANDROID_SIZES = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}

# iOS required sizes (size x scale -> px)
IOS_SIZES = {
    "Icon-App-20x20@1x.png":    20,
    "Icon-App-20x20@2x.png":    40,
    "Icon-App-20x20@3x.png":    60,
    "Icon-App-29x29@1x.png":    29,
    "Icon-App-29x29@2x.png":    58,
    "Icon-App-29x29@3x.png":    87,
    "Icon-App-40x40@1x.png":    40,
    "Icon-App-40x40@2x.png":    80,
    "Icon-App-40x40@3x.png":    120,
    "Icon-App-60x60@2x.png":    120,
    "Icon-App-60x60@3x.png":    180,
    "Icon-App-76x76@1x.png":    76,
    "Icon-App-76x76@2x.png":    152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}


def make_square(img: Image.Image) -> Image.Image:
    """Crop top 18% to hide face, then square-crop centered."""
    w, h = img.size
    top = int(h * 0.18)
    cropped = img.crop((0, top, w, h))
    cw, ch = cropped.size
    side = min(cw, ch)
    left = (cw - side) // 2
    return cropped.crop((left, 0, left + side, side))


def main():
    img = Image.open(SRC).convert("RGBA")
    square = make_square(img)
    print(f"Source square: {square.size}")

    # Android mipmaps
    print("\nAndroid:")
    for folder, size in ANDROID_SIZES.items():
        out_path = os.path.join(RES, folder, "ic_launcher.png")
        if os.path.exists(os.path.dirname(out_path)):
            square.resize((size, size), Image.LANCZOS).convert("RGB").save(out_path)
            print(f"  {folder}/ic_launcher.png ({size}x{size})")

    # iOS icons
    print("\niOS:")
    if os.path.exists(IOS_ICONS):
        for filename, size in IOS_SIZES.items():
            out_path = os.path.join(IOS_ICONS, filename)
            square.resize((size, size), Image.LANCZOS).convert("RGB").save(out_path)
            print(f"  {filename} ({size}x{size})")
    else:
        print(f"  iOS icon dir not found: {IOS_ICONS}")

    print("\nDone! Do a full rebuild: flutter clean && flutter run")


if __name__ == "__main__":
    main()
