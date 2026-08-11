#!/usr/bin/env python3
"""
Resize screenshots from stores/in/ into all required sizes for
Google Play Store and Apple App Store into stores/out/.

Usage:
    python3 stores/resize_store_screenshots.py
    python3 stores/resize_store_screenshots.py --fit contain --background "#1a1a2e"
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageOps

# ── Store size definitions ────────────────────────────────────────────────────

# (subfolder, width, height)
GOOGLE_PLAY_SIZES = [
    # Phone  — 9:16 portrait (required)
    ("google_play/phone",        1080, 1920),
    # 7-inch tablet — portrait
    ("google_play/tablet_7",     1200, 1920),
    # 10-inch tablet — portrait
    ("google_play/tablet_10",    1600, 2560),
]

APP_STORE_SIZES = [
    # iPhone 6.9"  (iPhone 16 Pro Max)  — required from 2025
    ("app_store/iphone_6_9",     1320, 2868),
    # iPhone 6.5"  (iPhone 11 Pro Max / 12–14 Plus)
    ("app_store/iphone_6_5",     1242, 2688),
    # iPhone 5.5"  (iPhone 8 Plus)  — legacy, still accepted
    ("app_store/iphone_5_5",     1242, 2208),
    # iPad Pro 13" (M4)
    ("app_store/ipad_pro_13",    2064, 2752),
    # iPad Pro 11"
    ("app_store/ipad_pro_11",    1668, 2388),
]

ALL_SIZES = GOOGLE_PLAY_SIZES + APP_STORE_SIZES


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Generate store screenshots from stores/in/")
    p.add_argument("--input-dir",   default="stores/in",  help="Folder with source PNGs")
    p.add_argument("--output-dir",  default="stores/out", help="Root output folder")
    p.add_argument("--fit", choices=("cover", "contain"), default="cover",
                   help="cover = crop to fill (default), contain = letterbox")
    p.add_argument("--background", default="#000000",
                   help="Background colour for contain mode (default: #000000)")
    return p.parse_args()


def resize_image(img: Image.Image, w: int, h: int, fit: str, bg: str) -> Image.Image:
    if fit == "cover":
        return ImageOps.fit(img, (w, h), method=Image.Resampling.LANCZOS)

    # contain — letterbox / pillarbox
    thumb = img.copy()
    thumb.thumbnail((w, h), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (w, h), color=bg)
    canvas.paste(thumb.convert("RGB"),
                 ((w - thumb.width) // 2, (h - thumb.height) // 2))
    return canvas


def main() -> int:
    args = parse_args()
    in_dir  = Path(args.input_dir)
    out_dir = Path(args.output_dir)

    sources = sorted(in_dir.glob("*.png"))
    if not sources:
        print(f"No PNG files found in {in_dir}")
        return 1

    print(f"Found {len(sources)} source image(s): {[s.name for s in sources]}\n")

    generated = 0
    for subfolder, w, h in ALL_SIZES:
        dest_dir = out_dir / subfolder
        dest_dir.mkdir(parents=True, exist_ok=True)

        for src in sources:
            with Image.open(src) as im:
                img = ImageOps.exif_transpose(im).convert("RGB")

                # If target is landscape but source is portrait, rotate 90° for
                # landscape slots so the content isn't squashed sideways.
                src_portrait = img.height >= img.width
                tgt_portrait = h >= w
                if src_portrait != tgt_portrait:
                    img = img.rotate(90, expand=True)

                out_img  = resize_image(img, w, h, args.fit, args.background)
                out_path = dest_dir / src.name
                out_img.save(out_path, format="PNG", optimize=True)
                print(f"  {out_path.relative_to(out_dir.parent)}  ({w}x{h})")
                generated += 1

    print(f"\nDone — {generated} files written to {out_dir}/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
