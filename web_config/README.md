# Web Config — Deeplink Setup

These files must be hosted at `https://myyt.isaac770.live/` for Universal Links (iOS)
and App Links (Android) to work.

## Files to upload

| File | Host at |
|------|---------|
| `.well-known/apple-app-site-association` | `https://myyt.isaac770.live/.well-known/apple-app-site-association` |
| `.well-known/assetlinks.json` | `https://myyt.isaac770.live/.well-known/assetlinks.json` |

Both must be served over **HTTPS** with `Content-Type: application/json`.

---

## Android — get your SHA-256 fingerprint

Replace `YOUR_RELEASE_KEYSTORE_SHA256_FINGERPRINT` in `assetlinks.json`:

```bash
keytool -list -v \
  -keystore android/app/upload-keystore.jks \
  -alias upload \
  -storepass 770now
```

Copy the `SHA256:` line (without the `SHA256:` prefix) into `assetlinks.json`.

---

## iOS — entitlements

`ios/Runner/Runner.entitlements` is already created with:
```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:myyt.isaac770.live</string>
</array>
```

Make sure this file is referenced in Xcode under:
**Runner → Signing & Capabilities → Associated Domains**

---

## How the share URL works

```
https://myyt.isaac770.live/?channels=UCN9HP...,UCqECa...&titles=Sia,Taylor%20Swift&avatars=asset%3A...,...
```

- Tapping on a device with the app installed → opens app directly, loads channels
- Tapping without the app → goes to App Store / Play Store
- After install, `DeeplinkService.checkInitialLink()` reads the URL and auto-populates channels

---

## Testing

```bash
# Android (app installed)
adb shell am start -W -a android.intent.action.VIEW \
  -d "https://myyt.isaac770.live/?channels=UCN9HPn2fq-NL8M5_kp4RWZQ&titles=Sia&avatars=" \
  live.isaac770.My_YT_Channels

# iOS (Simulator)
xcrun simctl openurl booted \
  "https://myyt.isaac770.live/?channels=UCN9HPn2fq-NL8M5_kp4RWZQ&titles=Sia&avatars="
```
