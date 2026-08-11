# Store Screenshots

Resizes source screenshots into every size required by Google Play and the Apple App Store.

---

## Usage

From the project root:

```bash
python3 stores/resize_store_screenshots.py
```

With options:

```bash
# Letterbox instead of crop, dark background
python3 stores/resize_store_screenshots.py --fit contain --background "#0d0d0d"

# Custom input / output folders
python3 stores/resize_store_screenshots.py --input-dir path/to/in --output-dir path/to/out
```

---

## Input

Drop any number of `.png` screenshots into `stores/in/`.  
The script picks up **all** PNGs automatically — no code changes needed when you add new screens.

Current screenshots:

| File | Description |
|------|-------------|
| `Main_Screen.png` | Home / channel grid |
| `choose_channels.png` | Channel picker onboarding |
| `feed.png` | Video feed |
| `select_or_remove.png` | Manage channels |

---

## Output

All files are written to `stores/out/` (created automatically):

```
stores/out/
  google_play/
    phone/            ← 1080 × 1920   (required)
    tablet_7/         ← 1200 × 1920   (7-inch tablet)
    tablet_10/        ← 1600 × 2560   (10-inch tablet)
  app_store/
    iphone_6_9/       ← 1320 × 2868   (iPhone 16 Pro Max — required from 2025)
    iphone_6_5/       ← 1242 × 2688   (iPhone 11 Pro Max / 12–14 Plus)
    iphone_5_5/       ← 1242 × 2208   (iPhone 8 Plus — legacy, still accepted)
    ipad_pro_13/      ← 2064 × 2752   (iPad Pro 13")
    ipad_pro_11/      ← 1668 × 2388   (iPad Pro 11")
```

Each subfolder contains one resized PNG per source file.

---

## Options

| Flag | Default | Description |
|------|---------|-------------|
| `--input-dir` | `stores/in` | Folder containing source PNGs |
| `--output-dir` | `stores/out` | Root folder for generated images |
| `--fit` | `cover` | `cover` = crop to fill · `contain` = letterbox |
| `--background` | `#000000` | Background colour used in `contain` mode |

---

## Requirements

```bash
pip install Pillow
```
