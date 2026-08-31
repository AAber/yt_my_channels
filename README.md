# My YT Channels

A Flutter app for browsing YouTube channels and media content.

# AppStore Link
https://apps.apple.com/us/app/my-yt-channels/id6800364851

# PlayStore Link
https://play.google.com/store/apps/details?id=live.isaac770.My_YT_Channels

---

## First-time setup

### 1. Clone the repo

```bash
git clone <your-repo-url>
cd yt_my_channels
flutter pub get
```

### 2. Create your Keys.dart from the template

`lib/States/Keys.dart` is listed in `.gitignore` and is **never committed to the repo**.  
You must create it locally from the provided template:

```bash
cp lib/States/Keys.template lib/States/Keys.dart
```

Then open `lib/States/Keys.dart` and replace every placeholder with your real key:

```dart
const String vimeoBearerToken = 'YOUR_VIMEO_BEARER_TOKEN';   // ← paste real token
const String groqApiKey       = 'YOUR_GROQ_API_KEY';          // ← paste real key

class Keys {
  static const String googleClientId       = 'YOUR_GOOGLE_CLIENT_ID';
  static const String googleServerClientId = 'YOUR_GOOGLE_SERVER_CLIENT_ID';
  static const String googleApiKey         = 'YOUR_YOUTUBE_API_KEY'; // ← paste real key
}
```

---

## API Keys — where to get them

### YouTube Data API v3 (`Keys.googleApiKey`)

Used to load videos from each singer's YouTube channel.

1. Go to [console.cloud.google.com](https://console.cloud.google.com/)
2. Create a project (or select an existing one)
3. Navigate to **APIs & Services → Library**
4. Search for **YouTube Data API v3** and click **Enable**
5. Go to **APIs & Services → Credentials → Create Credentials → API Key**
6. Copy the key into `Keys.googleApiKey`

> Tip: restrict the key to the YouTube Data API v3 to avoid abuse.

---

### Groq API key (`groqApiKey`)

Used by the Torah AI Assistant chat feature.

1. Go to [console.groq.com](https://console.groq.com/)
2. Sign up or log in
3. Navigate to **API Keys → Create API Key**
4. Copy the key into `groqApiKey`

---

## Running the app

```bash
flutter run
```

For a release build:

```bash
flutter build apk --release       # Android
flutter build ipa                  # iOS
```

---

## Channel & icon scripts

See [`scripts/README.md`](scripts/README.md) for instructions on:
- Updating YouTube channels
- Regenerating singer icons
- Updating the splash screen / app icon

---

## Project structure

```
lib/
  States/
    Keys.dart         ← your local keys (gitignored, never commit)
    Keys.template     ← committed template — copy to Keys.dart
  screens/            ← UI screens
  services/           ← API & data services
  models/             ← data models
  config/             ← app configuration
assets/
  icon/               ← channel button images
scripts/              ← Python helper scripts
android/              ← Android project
ios/                  ← iOS project
```

---

## Security notes

- `lib/States/Keys.dart` is in `.gitignore` — **never remove it from there**
- Never commit real API keys to the repository
- Rotate any key that is accidentally exposed
