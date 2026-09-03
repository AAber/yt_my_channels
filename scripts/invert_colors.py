#!/usr/bin/env python3
"""
invert_colors.py

Reverses (inverts) the colors of a PNG image and saves the result as a new file.
Works on black/white, grayscale, RGB, and RGBA images (alpha channel is preserved).

Usage:
    python3 invert_colors.py input.png [output.png]

If output.png is not given, it defaults to "<input_name>_inverted.png".
"""

import sys
import os
from PIL import Image, ImageOps


def invert_image(input_path: str, output_path: str) -> None:
    with Image.open(input_path) as img:
        original_mode = img.mode

        if original_mode == "RGBA":
            # Split off alpha, invert RGB only, then recombine so
            # transparency is preserved.
            rgb = img.convert("RGB")
            alpha = img.getchannel("A")
            inverted_rgb = ImageOps.invert(rgb)
            inverted = inverted_rgb.convert("RGBA")
            inverted.putalpha(alpha)

        elif original_mode in ("L", "RGB"):
            # Grayscale or RGB can be inverted directly.
            inverted = ImageOps.invert(img)

        elif original_mode == "1":
            # 1-bit black/white image.
            inverted = img.convert("L")
            inverted = ImageOps.invert(inverted)
            inverted = inverted.convert("1")

        elif original_mode == "P":
            # Palette-based image: convert to RGBA first to handle
            # transparency correctly, then invert.
            rgba = img.convert("RGBA")
            rgb = rgba.convert("RGB")
            alpha = rgba.getchannel("A")
            inverted_rgb = ImageOps.invert(rgb)
            inverted = inverted_rgb.convert("RGBA")
            inverted.putalpha(alpha)

        else:
            # Fallback: convert to RGB and invert.
            inverted = ImageOps.invert(img.convert("RGB"))

        inverted.save(output_path)
        print(f"Saved inverted image to: {output_path}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 invert_colors.py input.png [output.png]")
        sys.exit(1)

    input_path = sys.argv[1]

    if not os.path.isfile(input_path):
        print(f"Error: file not found: {input_path}")
        sys.exit(1)

    if len(sys.argv) >= 3:
        output_path = sys.argv[2]
    else:
        base, ext = os.path.splitext(input_path)
        output_path = f"{base}_inverted{ext or '.png'}"

    invert_image(input_path, output_path)


if __name__ == "__main__":
    main()
