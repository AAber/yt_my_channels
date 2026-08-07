#!/usr/bin/env python3
"""
run_all.py
-----------
Runs all update scripts in the correct order:
  1. generate_channel_icons.py  – creates PNG icons in assets/icon/
  2. update_pubspec_assets.py   – syncs pubspec.yaml flutter.assets block
  3. update_dart_channels.py    – rewrites channel data in source_selection_screen.dart

Edit CHANNELS in update_dart_channels.py (and optionally colors in
generate_channel_icons.py) then run:

    python3 scripts/run_all.py

Then hot-restart the Flutter app.
"""

import subprocess
import sys
import os

SCRIPTS_DIR = os.path.dirname(__file__)

steps = [
    "generate_channel_icons.py",
    "update_pubspec_assets.py",
    "update_dart_channels.py",
]

for script in steps:
    path = os.path.join(SCRIPTS_DIR, script)
    print(f"\n── Running {script} ──")
    result = subprocess.run([sys.executable, path])
    if result.returncode != 0:
        print(f"✗ {script} failed. Aborting.")
        sys.exit(1)

print("\n✅ All done! Hot-restart the Flutter app to see your changes.")
