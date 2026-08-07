# Channel Update Scripts

These scripts let you change the YouTube channels and icons without touching the Flutter source manually.

## Requirements

```bash
pip install pillow
```

---

## How to update channels

### 1. Edit the channel list

Open `scripts/update_dart_channels.py` and edit the `CHANNELS` list at the top:

```python
CHANNELS = [
    # (youtube_channel_id, display_title, subtitle, icon_filename_no_ext)
    ("UCqECaJ8Gagnn7YCbPEzWH6g", "Taylor Swift",  "taylorswift",  "taylor"),
    ...
]
```

- **youtube_channel_id** — the `UC...` ID from the channel's YouTube URL  
- **display_title** — shown as the card title in the app  
- **subtitle** — shown as the smaller text below the title  
- **icon_filename_no_ext** — filename (no `.png`) for the generated icon  

If you want different icon colors, also edit `CHANNELS` in `generate_channel_icons.py`.

### 2. Run everything at once

```bash
python3 scripts/run_all.py
```

This will:
1. Generate colored PNG icons → `assets/icon/<name>.png`
2. Update `pubspec.yaml` assets list
3. Rewrite the channel data in `source_selection_screen.dart`

### 3. Restart the app

```bash
flutter run
```

---

## Individual scripts

| Script | What it does |
|---|---|
| `generate_channel_icons.py` | Creates placeholder PNG icons in `assets/icon/` |
| `update_pubspec_assets.py` | Syncs `pubspec.yaml` flutter.assets block |
| `update_dart_channels.py` | Rewrites channel list in `source_selection_screen.dart` |
| `run_all.py` | Runs all three in order |
| `generate_splash_icon.py` | Processes a source image into splash + app icon sizes |

---

## How to update the splash / app icon

1. Drop your source image into `assets/` (e.g. `assets/sia.jpg`)
2. Edit `scripts/generate_splash_icon.py` and update `SRC` to point at your image
3. Adjust the `top` crop percentage if needed to hide/show different parts of the image
4. Run:

```bash
python3 scripts/generate_splash_icon.py
```

5. Regenerate the native splash and launcher icons:

```bash
flutter pub run flutter_native_splash:create
flutter pub run flutter_launcher_icons
```

6. Rebuild the app:

```bash
flutter run
```

---

## Finding a YouTube Channel ID

1. Go to the channel page on YouTube  
2. The URL looks like `youtube.com/channel/UCxxxxxxxx` — copy the `UC...` part  
3. Or use a tool like [commentpicker.com/youtube-channel-id.php](https://commentpicker.com/youtube-channel-id.php)
