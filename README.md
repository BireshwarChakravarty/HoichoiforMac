# Hoichoi for Mac

An open-source, native macOS app for watching [hoichoi](https://www.hoichoi.tv) — Bengali movies and web series — outside the browser.

> **Unofficial.** This project is not made, endorsed or supported by hoichoi or SVF Entertainment.
> You still need your own hoichoi account and subscription. The app doesn't download, rip or
> redistribute anything. It's a dedicated Mac window for the official website.

<p align="center"><img src="Resources/AppIcon.png" width="160" alt="App icon"></p>

## Why

hoichoi has apps for iPhone, iPad, Android and TVs, but not for the Mac. On a Mac you're stuck with a
browser tab. This app gives hoichoi its own window, Dock icon and menu bar, and adds the
keyboard shortcuts and conveniences you'd expect from a Mac app.

## Features

- **Native SwiftUI app.** Has its own window and Dock icon, a sidebar, a toolbar, a Settings window, full-screen support and light/dark mode.
- **Uses Safari's engine.** Pages render with WebKit, so playback is hardware-accelerated and energy-efficient, and AirPlay is available.
- **Stays signed in.** Cookies persist between launches.
- **Picks up where you left off.** The app reopens the last page you were on (you can turn this off).
- **Favorites.** Press ⌘D to save any show, movie or page to the sidebar. You can drag to reorder them.
- **Recently Viewed.** The sidebar keeps a list of the titles you opened most recently.
- **Simple player keys.** Space, the arrow keys, F, M and P work like they do on Netflix. A Playback menu adds playback speed.
- **Handles links properly.** Sign-in popups (Google, Facebook, Apple) open in a small window. Links that leave hoichoi.tv open in your default browser.
- **Zoom.** ⌘+ / ⌘− / ⌘0 change the page zoom, and trackpad back/forward swipes work.
- **Private and sandboxed.** The app runs in the App Sandbox with network access only. It has no analytics or tracking of its own.

### Keyboard shortcuts

While a video is playing, the app uses simple single-key controls, like Netflix:

| Key | Action |
| --- | --- |
| Space or K | Play / pause |
| ← / → | Back / forward 10 seconds |
| ↑ / ↓ | Volume up / down |
| M | Mute / unmute |
| F | Full screen: same as the player's own full screen button (Esc to exit) |
| P | Picture in Picture |

These keys only act on the main player. They don't fire while you type in a search box, and they don't affect looping preview clips.

Everywhere else, the app uses the usual Mac shortcuts: ⌘[ / ⌘] for back and forward, ⇧⌘H for Home, ⌘R to reload, ⌘D to add a favorite, and ⌘+ / ⌘− / ⌘0 for zoom.
**Help → Keyboard Shortcuts** (⌘/) shows the full list.

## Install

### Download a build

1. Download **[Hoichoi-for-Mac.dmg](https://github.com/BireshwarChakravarty/HoichoiforMac/releases/latest/download/Hoichoi-for-Mac.dmg)**, which is always the latest release.
   You can also browse all versions, including zip downloads, on the [Releases](https://github.com/BireshwarChakravarty/HoichoiforMac/releases) page.
2. Open the DMG and drag **Hoichoi for Mac** into **Applications**.
3. The app is ad-hoc signed, not notarized by Apple, so Gatekeeper will block it the first time. Do one of the following:
   - Right-click the app and choose **Open**, then click **Open** again. On macOS 15, go to **System Settings → Privacy & Security** and click **Open Anyway**.
   - Or run this in Terminal:

     ```bash
     xattr -dr com.apple.quarantine "/Applications/Hoichoi for Mac.app"
     ```

### Build from source

You need macOS 13 Ventura or later and Xcode 15 or later. The Command Line Tools are enough for `swift build`.

```bash
git clone https://github.com/BireshwarChakravarty/HoichoiforMac.git
```

```bash
cd HoichoiforMac
```

```bash
make run
```

`make run` builds the app for your Mac's architecture into `build/Hoichoi for Mac.app` and opens it. Other targets:

- `make app` builds a universal (Apple silicon + Intel) app, plus a zip and a DMG in `dist/`.
- `make debug` runs a debug build with `swift run`. The Safari Web Inspector is enabled in debug builds.
- `make icon` regenerates the app icon (needs Pillow).

You can also open `Package.swift` in Xcode and press Run.

### Use your own icon (personal builds)

You can give your own copy of the app a different icon:

1. Put a PNG or JPEG at `Resources/Custom/AppIcon.png`. A ready-made `.icns` also works, saved as `Resources/Custom/AppIcon.icns`.
   Wide images such as wordmarks are centred on a white square. To use a different background colour, set it as a hex value, for example `CUSTOM_ICON_BACKGROUND=000000 make run`.
2. Run `make run`.

`Resources/Custom/` is git-ignored, and CI builds never use it, so a personal icon never ends up in the repository or in a public release.
If you use another company's logo this way, keep that build to yourself.

## How it works

The app uses Swift Package Manager and has no third-party dependencies.

```
Sources/HoichoiForMac/
├── HoichoiForMacApp.swift      # App entry point: main window + Settings scene
├── ContentView.swift           # Split view, toolbar, loading/error/toast overlays
├── SidebarView.swift           # Home, Favorites, Recently Viewed
├── BrowserModel.swift          # Owns the WKWebView; navigation, playback controls, delegates
├── PopupWindowController.swift # Windows for window.open() (social sign-in)
├── LibraryStore.swift          # Favorites & recents, persisted in UserDefaults
├── AppCommands.swift           # Menu bar + keyboard shortcuts
├── SettingsView.swift          # Preferences
├── WebView.swift               # NSViewRepresentable wrapper
└── AppConfig.swift             # Constants, settings keys, helpers
Resources/                      # Info.plist, entitlements, icon
scripts/build-app.sh            # Builds, bundles, signs and zips the .app
```

Playback controls work by running a small piece of JavaScript against the page's `<video>` element.
The app doesn't call any private hoichoi API, and it doesn't touch the DRM-protected streams.

## Known limitations

- **Video playback depends on DRM.** hoichoi protects its streams with DRM. In this app they play
  only through the same protected path Safari uses. If a title won't play here, check whether it
  plays in Safari. If it doesn't play there either, the app can't fix it. In that case, use
  **Go → Open Page in Default Browser** to watch in another browser.
- The hoichoi website can change at any time. If something breaks, please [open an issue](https://github.com/BireshwarChakravarty/HoichoiforMac/issues).
- The playback shortcuts only reach videos in the top-level page. A video inside an embedded frame won't respond to them.
- Builds aren't notarized. If you have an Apple Developer ID, set `CODESIGN_IDENTITY` when you run `scripts/build-app.sh`, then notarize the zip.

## Contributing

Issues and pull requests are welcome. Please keep the app lightweight: no third-party dependencies, no tracking, and no
features that get around hoichoi's subscription or DRM.

## License

[MIT](LICENSE). "hoichoi" is a trademark of its respective owner and is used here only to describe what the app is for.
