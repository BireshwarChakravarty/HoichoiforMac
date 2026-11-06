import AppKit
import SwiftUI

/// Menu bar items and keyboard shortcuts.
struct AppCommands: Commands {
    @ObservedObject var browser: BrowserModel
    @ObservedObject var library: LibraryStore

    var body: some Commands {
        // Single-window app: no File > New Window.
        CommandGroup(replacing: .newItem) {}

        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Copy Page Link") { browser.copyCurrentLink() }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(browser.currentURL == nil)
        }

        CommandGroup(after: .toolbar) {
            Button("Reload Page") { browser.reload() }
                .keyboardShortcut("r", modifiers: .command)
            Button("Reload Ignoring Cache") { browser.reloadIgnoringCache() }
                .keyboardShortcut("r", modifiers: [.command, .option])
            Divider()
            Button("Actual Size") { browser.resetZoom() }
                .keyboardShortcut("0", modifiers: .command)
            Button("Zoom In") { browser.zoomIn() }
                .keyboardShortcut("=", modifiers: .command)
            Button("Zoom Out") { browser.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
            Divider()
        }

        CommandMenu("Go") {
            Button("Back") { browser.goBack() }
                .keyboardShortcut("[", modifiers: .command)
                .disabled(!browser.canGoBack)
            Button("Forward") { browser.goForward() }
                .keyboardShortcut("]", modifiers: .command)
                .disabled(!browser.canGoForward)
            Button("Home") { browser.goHome() }
                .keyboardShortcut("h", modifiers: [.command, .shift])
            Divider()
            Button(library.isFavorite(browser.currentURL) ? "Remove from Favorites" : "Add to Favorites") {
                library.toggleFavorite(title: browser.title, url: browser.currentURL)
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(browser.currentURL == nil)
            Divider()
            Button("Open Page in Default Browser") { browser.openInDefaultBrowser() }
                .keyboardShortcut("o", modifiers: [.command, .option])
                .disabled(browser.currentURL == nil)
        }

        // Playback keys are single keys handled inside the page (see
        // PlayerShortcuts), so they never fire while you're typing. These menu
        // items are for clicking and discovery.
        CommandMenu("Playback") {
            Button("Play / Pause  (Space)") { browser.togglePlayPause() }
            Button("Back 10 Seconds  (\u{2190})") { browser.seek(by: -10) }
            Button("Forward 10 Seconds  (\u{2192})") { browser.seek(by: 10) }
            Button("Mute / Unmute  (M)") { browser.toggleMute() }
            Divider()
            Menu("Playback Speed") {
                ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                    Button(rate == 1.0 ? "Normal" : "\(rate.formatted())\u{00D7}") {
                        browser.setPlaybackRate(rate)
                    }
                }
            }
            Divider()
            Button("Picture in Picture  (P)") { browser.togglePictureInPicture() }
        }

        CommandGroup(replacing: .help) {
            Button("Keyboard Shortcuts") { showKeyboardShortcuts() }
                .keyboardShortcut("/", modifiers: .command)
            Divider()
            Button("\(AppConfig.appName) on GitHub") {
                NSWorkspace.shared.open(AppConfig.repositoryURL)
            }
            Button("Report an Issue…") {
                NSWorkspace.shared.open(AppConfig.issuesURL)
            }
        }
    }
}

@MainActor
private func showKeyboardShortcuts() {
    let alert = NSAlert()
    alert.messageText = "Keyboard Shortcuts"
    alert.informativeText = """
    While watching
    Space or K  \u{2014}  play / pause
    \u{2190} \u{2192}  \u{2014}  back / forward 10 seconds
    \u{2191} \u{2193}  \u{2014}  volume
    M  \u{2014}  mute
    F  \u{2014}  full screen (Esc to exit)
    P  \u{2014}  Picture in Picture

    Anywhere
    \u{2318}[ \u{2318}]  \u{2014}  back / forward
    \u{21E7}\u{2318}H  \u{2014}  home
    \u{2318}R  \u{2014}  reload
    \u{2318}D  \u{2014}  add to Favorites
    """
    alert.addButton(withTitle: "OK")
    alert.runModal()
}
