#!/usr/bin/env python3
"""
update_dart_channels.py
------------------------
Rewrites the _sourceButtons list and _youtubeChannels constant in
source_selection_screen.dart based on CHANNELS defined below.

Usage:
    python3 scripts/update_dart_channels.py

After running, hot-restart the app to see changes.
"""

import os
import re

# ─── EDIT THIS LIST to change channels ────────────────────────────────────────
# (channel_id, dart_title, dart_subtitle, icon_filename_without_ext)
CHANNELS = [
    ("UCqECaJ8Gagnn7YCbPEzWH6g", "Taylor Swift",   "taylorswift",    "taylor"),
    ("UC0C-w0YjGpqDXGB8IHb662A", "Ed Sheeran",     "edsheeran",      "ed"),
    ("UCsRM0YB_dabtEPGPTKo-gcw", "Adele",          "adele",          "adele"),
    ("UCJrOtniJ0-NWz37R30urifQ", "Ariana Grande",  "arianagrande",   "ariana"),
    ("UCBmNph6atAoGfqLoCL_duAg", "Beyoncé",        "beyonce",        "beyonce"),
    ("UCByOQJjav0CUDwxCk-wiVtw", "Drake",          "drake",          "drake"),
    ("UCiGm_E4ZwYSHV3bcW1pnSeQ", "Billie Eilish",  "billieeilish",   "billie"),
    ("UC0WP5P-ufpRfjbNrmOWwLBQ", "The Weeknd",     "theweeknd",      "weeknd"),
]
# ──────────────────────────────────────────────────────────────────────────────

DART_FILE = os.path.join(
    os.path.dirname(__file__), "..", "lib", "screens", "source_selection_screen.dart"
)


def build_source_buttons() -> str:
    """Generates the _sourceButtons = [ ... ]; block."""
    entries = []
    for ch_id, title, subtitle, icon in CHANNELS:
        entries.append(
            f"      _SourceButtonData(\n"
            f"        title: '{title}',\n"
            f"        subtitle: '{subtitle}',\n"
            f"        iconPath: 'assets/icon/{icon}.png',\n"
            f"        onTap: () {{\n"
            f"          Navigator.pushReplacement(\n"
            f"            context,\n"
            f"            MaterialPageRoute(\n"
            f"              builder: (context) => const YouTubeHomeScreen(\n"
            f"                channelId: '{ch_id}',\n"
            f"                title: '{title}',\n"
            f"              ),\n"
            f"            ),\n"
            f"          );\n"
            f"        }},\n"
            f"      ),"
        )
    body = "\n".join(entries)
    return f"    _sourceButtons = [\n{body}\n    ];"


def build_youtube_channels() -> str:
    """Generates the _youtubeChannels = [ ... ]; constant."""
    entries = []
    for ch_id, title, _, icon in CHANNELS:
        entries.append(
            f"    {{\n"
            f"      'id': '{ch_id}',\n"
            f"      'title': '{title}',\n"
            f"      'icon': 'assets/icon/{icon}.png'\n"
            f"    }},"
        )
    body = "\n".join(entries)
    return f"  static const _youtubeChannels = [\n{body}\n  ];"


def update_dart() -> None:
    with open(DART_FILE, "r") as f:
        content = f.read()

    # Replace _sourceButtons block
    content = re.sub(
        r"_sourceButtons = \[.*?\];",
        build_source_buttons(),
        content,
        flags=re.DOTALL,
    )

    # Replace _youtubeChannels constant
    content = re.sub(
        r"static const _youtubeChannels = \[.*?\];",
        build_youtube_channels(),
        content,
        flags=re.DOTALL,
    )

    with open(DART_FILE, "w") as f:
        f.write(content)

    print(f"✓ source_selection_screen.dart updated with {len(CHANNELS)} channels.")


if __name__ == "__main__":
    update_dart()
