# Deeplink & Share — Test Scenarios

## Server verification (already confirmed ✅)

| URL | Expected |
|-----|----------|
| `https://myyt.isaac770.live/.well-known/assetlinks.json` | JSON with `mobile.meritv.com` + `live.isaac770.My_YT_Channels` entries |
| `https://myyt.isaac770.live/.well-known/apple-app-site-association` | JSON with `P5NY23GU8C.live.isaac770.my-yt-channels` |

---

## 1 — Android App Links (app already installed)

**Goal:** tapping the link opens the app directly, no browser.

```bash
adb shell am start -W -a android.intent.action.VIEW \
  -d "https://myyt.isaac770.live/?channels=UCN9HPn2fq-NL8M5_kp4RWZQ,UCqECaJ8Gagnn7YCbPEzWH6g&titles=Sia,Taylor%20Swift&avatars=asset%3Aassets%2Ficon%2Fsia.png,asset%3Aassets%2Ficon%2Ftaylor.png" \
  live.isaac770.My_YT_Channels
```

**Pass criteria:**
- App opens directly (no browser, no chooser dialog)
- Sia and Taylor Swift appear in the channel grid
- If they were already saved, no duplicates are added

---

## 2 — iOS Universal Links (app already installed)

```bash
xcrun simctl openurl booted \
  "https://myyt.isaac770.live/?channels=UCN9HPn2fq-NL8M5_kp4RWZQ,UCqECaJ8Gagnn7YCbPEzWH6g&titles=Sia,Taylor%20Swift&avatars=asset%3Aassets%2Ficon%2Fsia.png,asset%3Aassets%2Ficon%2Ftaylor.png"
```

**Pass criteria:** same as Android above.

---

## 3 — Share → now playing (in-app test)

1. Open the app → tap **Shuffle** icon in the top bar
2. Wait for the queue to load
3. Tap the **share (↑)** icon in the AppBar
4. Verify the share sheet opens with text like:
   ```
   🎵 Listen to "<track title>" and more on My YT Channels!
   Get the app and auto-load my playlist 👇
   https://myyt.isaac770.live/?channels=...&titles=...
   ```
5. Share to **WhatsApp** — verify the OG preview card shows the app image

**Pass criteria:** URL contains `channels=` and `titles=` params, OG card visible in WhatsApp.

---

## 4 — Share → full playlist (in-app test)

1. On the Shuffle screen tap the **playlist (≡▶)** icon
2. Share sheet opens with all saved channel names listed
3. Copy the URL from the message
4. Paste into a browser — verify redirect goes to correct store (iOS → App Store, Android → Play Store)

---

## 5 — Fresh install deeplink (deferred deeplink)

> Requires a device that does **not** have the app installed.

1. Send the share URL to another device (e.g. via WhatsApp)
2. Tap the link on the fresh device
3. Gets redirected to App Store / Play Store ✅
4. Install the app
5. On first launch — verify the channels from the URL are automatically added to the grid

**Pass criteria:** channel grid is pre-populated without the user going through the picker manually.

---

## 6 — OG preview card (WhatsApp / iMessage)

Paste this URL into WhatsApp or iMessage:
```
https://myyt.isaac770.live/
```

**Pass criteria:**
- Preview card appears with the app image
- Title: **My YT Channels**
- Tapping the card redirects to the correct store

---

## 7 — Duplicate guard

1. Add Sia to your channels manually
2. Tap a share link that also contains Sia's channel ID
3. Open the app

**Pass criteria:** Sia appears only once in the grid.

---

## 8 — Max channels guard

1. Fill the grid to 8 channels
2. Tap a share link containing a 9th channel

**Pass criteria:** The 9th channel is silently ignored (max 8 enforced by `SavedChannelsService`).

---

## Quick test URLs

| Channels | URL |
|----------|-----|
| Sia only | `https://myyt.isaac770.live/?channels=UCN9HPn2fq-NL8M5_kp4RWZQ&titles=Sia&avatars=asset%3Aassets%2Ficon%2Fsia.png` |
| All 7 singers | `https://myyt.isaac770.live/?channels=UCN9HPn2fq-NL8M5_kp4RWZQ,UCqECaJ8Gagnn7YCbPEzWH6g,UC0C-w0YjGpqDXGB8IHb662A,UC9CoOnJkIBMdeijd9qYoT_g,UCuHzBCaKmtaLcRAOoazhCPA,UCNTQH0uJzryQB4rRLGlv-Ww,UCiGm_E4ZwYSHV3bcW1pnSeQ&titles=Sia,Taylor%20Swift,Ed%20Sheeran,Ariana%20Grande,Beyonc%C3%A9,Drake,Billie%20Eilish&avatars=asset%3Aassets%2Ficon%2Fsia.png,asset%3Aassets%2Ficon%2Ftaylor.png,asset%3Aassets%2Ficon%2Fed.png,asset%3Aassets%2Ficon%2Fariana.png,asset%3Aassets%2Ficon%2Fbeyonce.png,asset%3Aassets%2Ficon%2Fdrake.png,asset%3Aassets%2Ficon%2Fbillie.png` |
