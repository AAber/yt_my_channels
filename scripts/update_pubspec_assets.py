#!/usr/bin/env python3
"""
update_pubspec_assets.py
-------------------------
Reads CHANNELS from generate_channel_icons.py and rewrites the
flutter.assets block in pubspec.yaml to match.

Always keeps non-channel assets (meir.png, tfc.png, etc.) listed in
KEEP_ASSETS at the bottom.

Usage:
    python3 scripts/update_pubspec_assets.py
"""

import os
import re
import sys

# ─── Must stay in sync with generate_channel_icons.py ─────────────────────────
sys.path.insert(0, os.path.dirname(__file__))
from generate_channel_icons import CHANNELS
# ──────────────────────────────────────────────────────────────────────────────

# Assets that are NOT channel icons but must always be listed
KEEP_ASSETS = [
    "assets/icon/meir.png",
    "assets/icon/tfc.png",
]

PUBSPEC = os.path.join(os.path.dirname(__file__), "..", "pubspec.yaml")


def build_assets_block() -> str:
    lines = ["  assets:"]
    for fname, _, _ in CHANNELS:
        lines.append(f"    - assets/icon/{fname}.png")
    for asset in KEEP_ASSETS:
        lines.append(f"    - {asset}")
    return "\n".join(lines)


def update_pubspec() -> None:
    with open(PUBSPEC, "r") as f:
        content = f.read()

    new_block = build_assets_block()
    # Replace the entire assets: block (indented list under flutter:)
    updated = re.sub(
        r"  assets:\n(?:    - .+\n)+",
        new_block + "\n",
        content,
    )

    if updated == content:
        print("pubspec.yaml assets block unchanged.")
        return

    with open(PUBSPEC, "w") as f:
        f.write(updated)
    print(f"✓ pubspec.yaml updated with {len(CHANNELS)} channel assets.")


if __name__ == "__main__":
    update_pubspec()
