#!/usr/bin/env python3
"""
generate_channel_icons.py
--------------------------
Downloads official YouTube channel avatar images for each channel in CHANNELS
and saves them to assets/icon/<filename>.png.

Usage:
    python3 scripts/generate_channel_icons.py

Requirements:
    pip install pillow
"""

import urllib.request
import ssl
import re
import os
from PIL import Image

# ─── EDIT THIS LIST to add/change channels ────────────────────────────────────
# (filename_without_ext, youtube_channel_id)
CHANNELS = [
    ("sia",     "UCN9HPn2fq-NL8M5_kp4RWZQ"),
    ("taylor",  "UCqECaJ8Gagnn7YCbPEzWH6g"),
    ("ed",      "UC0C-w0YjGpqDXGB8IHb662A"),
    ("ariana",  "UC9CoOnJkIBMdeijd9qYoT_g"),
    ("beyonce", "UCuHzBCaKmtaLcRAOoazhCPA"),
    ("drake",   "UCNTQH0uJzryQB4rRLGlv-Ww"),
    ("billie",  "UCiGm_E4ZwYSHV3bcW1pnSeQ"),
]
# ──────────────────────────────────────────────────────────────────────────────

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")
HEADERS = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"}
CTX = ssl._create_unverified_context()


def fetch_avatar(channel_id: str) -> bytes | None:
    url = f"https://www.youtube.com/channel/{channel_id}"
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=10, context=CTX) as r:
        html = r.read().decode("utf-8", errors="ignore")

    m = re.search(r'"avatar":\{"thumbnails":\[\{"url":"([^"]+)"', html)
    if not m:
        m = re.search(r'"channelAvatarImageUrl":"([^"]+)"', html)
    if not m:
        m = re.search(r'<meta property="og:image" content="([^"]+)"', html)
    if not m:
        return None

    img_url = m.group(1).replace("\\u0026", "&")
    img_req = urllib.request.Request(img_url, headers=HEADERS)
    with urllib.request.urlopen(img_req, timeout=10, context=CTX) as ir:
        return ir.read()


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print(f"Downloading {len(CHANNELS)} channel avatars...\n")
    for fname, channel_id in CHANNELS:
        out_path = os.path.join(OUT_DIR, f"{fname}.png")
        try:
            data = fetch_avatar(channel_id)
            if not data:
                print(f"  MISS  {fname} — avatar URL not found in page")
                continue
            with open(out_path, "wb") as f:
                f.write(data)
            img = Image.open(out_path)
            print(f"  OK    {fname}.png  {img.size}  {len(data)//1024}KB")
        except Exception as e:
            print(f"  ERR   {fname}: {e}")

    print("\nDone! Run update_pubspec_assets.py if you added new filenames.")


if __name__ == "__main__":
    main()
