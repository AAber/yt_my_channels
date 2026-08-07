# Channel Update Scripts

These scripts let you change the YouTube channels and icons without touching the Flutter source manually.

## Requirements

```bash
pip install pillow
```

---

## ⚠️ YouTube API Key

Before the app can load videos you need a YouTube Data API v3 key.

1. Go to [console.cloud.google.com](https://console.cloud.google.com/)
2. Create a project → Enable **YouTube Data API v3** → Create an API key
3. Paste it into `lib/config/api_keys.dart`:

```dart
static const String youtubeApiKey = 'YOUR_KEY_HERE';
```

Without a valid key every channel screen will show a 🔑 error.

---

## Current channels (verified August 2025)

| Button | Channel ID | YouTube handle |
|---|---|---|
| בני דוד | *(custom API, not YouTube)* | — |
| Sia | `UCN9HPn2fq-NL8M5_kp4RWZQ` | @sia |
| Taylor Swift | `UCqECaJ8Gagnn7YCbPEzWH6g` | @taylorswift |
| Ed Sheeran | `UC0C-w0YjGpqDXGB8IHb662A` | @edsheeran |
| Ariana Grande | `UC9CoOnJkIBMdeijd9qYoT_g` | @ArianaGrande |
| Beyoncé | `UCuHzBCaKmtaLcRAOoazhCPA` | @beyonce |
| Drake | `UCNTQH0uJzryQB4rRLGlv-Ww` | @Drake |
| Billie Eilish | `UCiGm_E4ZwYSHV3bcW1pnSeQ` | @BillieEilish |

---

## How to update channels

### 1. Edit the channel list

Open `scripts/update_dart_channels.py` and edit the `CHANNELS` list at the top:

```python
CHANNELS = [
    # (youtube_channel_id, display_title, subtitle, icon_filename_no_ext)
    ("UCN9HPn2fq-NL8M5_kp4RWZQ", "Sia", "sia", "billie"),
    ...
]
```

- **youtube_channel_id** — the `UC...` ID from the channel's YouTube URL
- **display_title** — shown as the card title in the app
- **subtitle** — shown as the smaller text below the title
- **icon_filename_no_ext** — filename (no `.png`) for the generated icon

Note: `בני דוד` is always kept as the first button and is NOT in this list.

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
| `apply_sia_icons.py` | Writes Sia's image directly into all Android/iOS icon slots |

---

## How to update the splash / app icon

1. Drop your source image into `assets/` (e.g. `assets/sia.jpg`)
2. Edit `scripts/generate_splash_icon.py` and update `SRC` to point at your image
3. Adjust the `top` crop percentage if needed to hide/show different parts of the image
4. Run:

```bash
python3 scripts/generate_splash_icon.py
python3 scripts/apply_sia_icons.py
```

5. Rebuild the app:

```bash
flutter clean && flutter run
```

---

## Finding a YouTube Channel ID

1. Go to the channel page on YouTube
2. The URL looks like `youtube.com/channel/UCxxxxxxxx` — copy the `UC...` part
3. Or visit `youtube.com/@handle/about` and look for `channelId` in the page source
4. Or use [commentpicker.com/youtube-channel-id.php](https://commentpicker.com/youtube-channel-id.php)
