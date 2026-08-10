# yt_my_channels — New UX Flow: Plan & Runbook

## Overview

This document describes the new YouTube-only channel selection flow introduced in August 2025.  
The app is now fully user-driven: every channel button on the home screen is chosen by the user.

---

## Architecture

```
main.dart
  └─ SavedChannelsService.load()
       ├─ isEmpty  →  ChannelPickerScreen   (onboarding / first launch)
       └─ hasData  →  SourceSelectionScreen (channel grid)
                           └─ + Add button  →  ChannelPickerScreen (isAddMode: true)
                           └─ channel tap   →  YouTubeHomeScreen
                                                  └─ video tap  →  YouTubePlayerScreen
```

---

## Screens

### ChannelPickerScreen (`lib/screens/channel_picker_screen.dart`)

| Mode | Trigger | Behaviour |
|---|---|---|
| Onboarding | Fresh install / no saved channels | Full welcome header, no back button |
| Add mode | `+` button on grid | Back button shown, title = "Manage Channels" |

**Input accepts:**
- Full YouTube URL: `https://youtube.com/@taylorswift`
- Handle only: `@taylorswift`
- Channel ID: `UCqECaJ8Gagnn7YCbPEzWH6g`
- Channel name (falls back to YouTube search API)

**Rules:**
- Minimum 1 channel to proceed
- Maximum 8 channels
- Channels are reorderable (drag handle)
- Each channel can be removed individually
- Changes are persisted on "Continue / Save"

---

### SourceSelectionScreen (`lib/screens/source_selection_screen.dart`)

- Loads channels from `SavedChannelsService`
- Renders a 2-column grid of channel buttons
- Each button shows the channel's YouTube avatar (network image) and title
- Last tile is always the `+ Add Channel` button (disabled when at max 8)
- Search bar searches across all saved channels' videos via YouTube API
- Torah AI chat FAB (orange) remains

---

## Services

### SavedChannelsService (`lib/services/saved_channels_service.dart`)

Singleton. Persists to `SharedPreferences` under key `saved_yt_channels`.

```dart
SavedChannelsService.instance.load()          // call at app start
SavedChannelsService.instance.channels        // List<SavedChannel>
SavedChannelsService.instance.isEmpty         // true on first launch
SavedChannelsService.instance.add(channel)    // max 8
SavedChannelsService.instance.remove(id)
```

`SavedChannel` fields: `id`, `title`, `avatarUrl`

---

### YouTubeService — new methods

```dart
// Resolves any input format to a SavedChannel (id + title + avatarUrl)
Future<SavedChannel?> fetchChannelInfo(String input)

// Accepts: full URL, @handle, UC... ID, or channel name
Future<String?> _resolveChannelId(String input)
```

Resolution order:
1. Bare `UC...` ID — used directly
2. `/channel/UC...` URL pattern
3. `@handle` → YouTube `channels?forHandle=` API
4. Fallback → YouTube `search?type=channel` API

---

## What was removed

| Removed | Reason |
|---|---|
| Bnei David button | App is now YouTube-only |
| `HomeScreen` (Vimeo feed) | Vimeo content removed |
| `home_screen.dart` Vimeo player | YouTube-only |
| `api_service.dart` series search | No longer needed in selection screen |
| Hardcoded channel list | Replaced by user-defined `SavedChannelsService` |

---

## Runbook

### First launch (new install)

1. App starts → `SavedChannelsService.load()` → empty
2. `ChannelPickerScreen` shown (onboarding mode)
3. User pastes a YouTube URL / handle → taps `+`
4. App calls `YouTubeService.fetchChannelInfo()` → resolves channel ID + avatar
5. Channel appears in the staged list with avatar and title
6. User adds 1–8 channels, optionally reorders or removes
7. Taps **Continue to App** → channels saved → `SourceSelectionScreen` shown

### Returning user

1. App starts → `SavedChannelsService.load()` → has channels
2. `SourceSelectionScreen` shown immediately
3. User taps a channel button → `YouTubeHomeScreen` loads that channel's videos

### Adding / managing channels

1. User taps **+ Add Channel** tile on the grid
2. `ChannelPickerScreen` opens in add mode (back button shown)
3. User adds or removes channels
4. Taps **Save Changes** → persisted → returns to grid

### Removing a channel

1. Open **+ Add Channel** (manage mode)
2. Tap the 🗑 delete icon on any channel tile
3. Tap **Save Changes**

---

## Data flow diagram

```
User input (URL / @handle / ID)
        │
        ▼
YouTubeService._resolveChannelId()
        │  YouTube Data API v3
        ▼
YouTubeService.fetchChannelInfo()
        │  returns SavedChannel { id, title, avatarUrl }
        ▼
ChannelPickerScreen._staged list
        │  on "Continue / Save"
        ▼
SavedChannelsService  (SharedPreferences)
        │
        ▼
SourceSelectionScreen grid
        │  tap
        ▼
YouTubeHomeScreen  →  YouTubePlayerScreen
```

---

## Environment requirements

| Key | Location | Used by |
|---|---|---|
| `Keys.googleApiKey` | `lib/States/Keys.dart` | Channel resolution, video loading |
| `Keys.groqApiKey` | `lib/States/Keys.dart` | Torah AI chat |
| `vimeoBearerToken` | `lib/States/Keys.dart` | Legacy (unused in new flow) |

See `README.md` and `lib/States/Keys.template` for setup instructions.

---

## Testing checklist

- [ ] Fresh install → `ChannelPickerScreen` shown
- [ ] Add channel by URL → avatar and title appear
- [ ] Add channel by `@handle` → resolves correctly
- [ ] Add channel by bare `UC...` ID → resolves correctly
- [ ] Proceed with 0 channels → button disabled
- [ ] Proceed with 1 channel → works
- [ ] Add 8 channels → `+` tile shows "Max reached"
- [ ] Reorder channels → order persisted after restart
- [ ] Remove channel in manage mode → removed from grid
- [ ] Kill and relaunch → saved channels restored
- [ ] Search across channels → results shown
- [ ] Tap search result → `YouTubePlayerScreen` opens
