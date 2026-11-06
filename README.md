# Hoichoi for Mac

A native macOS app for watching [hoichoi](https://www.hoichoi.tv), the Bengali movie and web series service, outside the browser. Free and open source.

<p align="center"><img src="Resources/AppIcon.png" width="160" alt="Hoichoi for Mac icon"></p>

<p align="center">
  <a href="https://github.com/BireshwarChakravarty/HoichoiforMac/releases/latest/download/Hoichoi-for-Mac.dmg"><b>Download for Mac</b></a>
  · macOS 13 Ventura or later · Apple silicon and Intel
</p>

> **Unofficial.** This app isn't made, endorsed or supported by hoichoi or SVF Entertainment.
> You need your own hoichoi account and subscription. The app doesn't download, rip or
> redistribute anything. It shows the official hoichoi website in its own Mac window.

## Features

- **A real Mac app.** It has its own window, Dock icon, sidebar, toolbar, menu bar and Settings, and supports light and dark mode.
- **Starts on the hoichoi home screen**, and a Home button is always in the toolbar.
- **Full screen with nothing on top.** The video fills the display. Press F, use the player's full screen button or click the green window button.
- **The pointer hides in full screen** after 3 seconds without movement, and comes back when you move the mouse.
- **Netflix-style keys.** Space plays and pauses, the arrow keys skip and change the volume, and F, M and P toggle full screen, mute and Picture in Picture.
- **Stays signed in** between launches.
- **Favorites and Recently Viewed.** Press ⌘D to pin any title to the sidebar.
- **Safari's engine.** Playback is hardware-accelerated and battery-friendly, and AirPlay is supported.
- **Works with sign-in and links.** Google, Facebook and Apple sign-in work in a popup. Links that leave hoichoi.tv open in your default browser.
- **Private.** The app runs in the macOS App Sandbox and has no analytics or tracking of its own.

## Install

1. Download **[Hoichoi-for-Mac.dmg](https://github.com/BireshwarChakravarty/HoichoiforMac/releases/latest/download/Hoichoi-for-Mac.dmg)**.
2. Open it and drag **Hoichoi for Mac** into **Applications**.
3. The app isn't notarized by Apple, so macOS blocks it the first time you open it. To get past this:
   - Right-click the app and choose **Open**, then click **Open** again.
   - On macOS 15 or later, go to **System Settings → Privacy & Security** and click **Open Anyway**.
   - Or run this in Terminal:

     ```bash
     xattr -dr com.apple.quarantine "/Applications/Hoichoi for Mac.app"
     ```

You only need to do this once per version. To update, drag the new version into Applications and choose **Replace**.

## Keyboard shortcuts

While watching:

| Key | Action |
| --- | --- |
| Space or K | Play / pause |
| ← / → | Back / forward 10 seconds |
| ↑ / ↓ | Volume up / down |
| M | Mute / unmute |
| F | Full screen (Esc to exit) |
| P | Picture in Picture |

These keys only control the main player. They don't fire while you're typing, and they ignore the looping preview clips on browse pages.

Anywhere:

| Shortcut | Action |
| --- | --- |
| ⌘[ / ⌘] | Back / forward |
| ⇧⌘H | Home |
| ⌘R | Reload (⌥⌘R ignores the cache) |
| ⌘D | Add to or remove from Favorites |
| ⌘+ / ⌘− / ⌘0 | Zoom in / out / actual size |
| ⌘, | Settings |
| ⌘/ | Show all shortcuts |

## Good to know

- **Picture quality is automatic.** hoichoi's protected streams play through Apple's own video player, the same one Safari uses. That player chooses the resolution from your connection speed and the size of the video on screen, and doesn't offer a quality menu. For the best picture, watch in full screen and give it a few seconds to ramp up.
- **Screenshots of a playing video come out black.** macOS blocks screen capture of DRM-protected video. This is normal.
- **If a page looks broken** (missing styling or an empty page), press ⌥⌘R to reload it without the cache. If that doesn't help, go to **Settings → Privacy** and clear website data. If hoichoi.tv also looks broken in Safari, the problem is on hoichoi's side.
- **If a title won't play,** check whether it plays in Safari. The app can only play what Safari can. **Go → Open Page in Default Browser** opens the current page in your browser.

## Build from source

You need macOS 13 or later and Xcode 15 or later. The Command Line Tools are enough.

```bash
git clone https://github.com/BireshwarChakravarty/HoichoiforMac.git
```

```bash
cd HoichoiforMac
```

```bash
make run
```

`make run` builds the app for your Mac into `build/` and opens it. Other targets:

- `make app` builds a universal app plus a zip and a DMG in `dist/`.
- `make debug` runs a debug build with `swift run`.

You can also open `Package.swift` in Xcode and press Run. To inspect pages, turn on Safari's **Develop** menu and pick **Hoichoi for Mac** under your Mac's name.

Releases are built by GitHub Actions. To publish a version, open **Actions → Build → Run workflow** and enter a tag such as `v1.1.0`.

## How it works

It's a Swift Package Manager project with no third-party dependencies.

```
Sources/HoichoiForMac/
├── HoichoiForMacApp.swift      # App entry point: main window and Settings
├── ContentView.swift           # Split view, toolbar, full screen and overlays
├── SidebarView.swift           # Home, Favorites, Recently Viewed
├── BrowserModel.swift          # Owns the web view: navigation and playback
├── PlayerShortcuts.swift       # Single-key player controls injected into the page
├── PopupWindowController.swift # Popup windows for social sign-in
├── LibraryStore.swift          # Favorites and recents
├── AppCommands.swift           # Menu bar
├── SettingsView.swift          # Settings
├── WebView.swift               # WebKit view wrapper
└── AppConfig.swift             # Constants and helpers
Resources/                      # Info.plist, entitlements, app icon
scripts/                        # Build, sign, package and icon scripts
```

Player controls work by running a small script against the page's `<video>` element. The script runs in its own isolated JavaScript sandbox, so the page's scripts can't see or interfere with it. The app doesn't use any private hoichoi API, and it never touches the protected video streams.

## Contributing

Issues and pull requests are welcome. Please keep the app lightweight: no third-party dependencies, no tracking, and nothing that gets around hoichoi's subscription or DRM.

If something breaks, [open an issue](https://github.com/BireshwarChakravarty/HoichoiforMac/issues).

## License

[MIT](LICENSE). "hoichoi" is a trademark of its owner and is used here only to say what the app is for.
