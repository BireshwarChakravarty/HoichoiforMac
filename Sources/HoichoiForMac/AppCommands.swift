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

        CommandMenu("Playback") {
            Button("Play / Pause") { browser.togglePlayPause() }
                .keyboardShortcut("p", modifiers: [.command, .option])
            Button("Skip Back 10 Seconds") { browser.seek(by: -10) }
                .keyboardShortcut(.leftArrow, modifiers: [.command, .option])
            Button("Skip Forward 10 Seconds") { browser.seek(by: 10) }
                .keyboardShortcut(.rightArrow, modifiers: [.command, .option])
            Button("Mute / Unmute") { browser.toggleMute() }
                .keyboardShortcut("m", modifiers: [.command, .option])
            Divider()
            Menu("Playback Speed") {
                ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                    Button(rate == 1.0 ? "Normal" : "\(rate.formatted())\u{00D7}") {
                        browser.setPlaybackRate(rate)
                    }
                }
            }
            Divider()
            Button("Picture in Picture") { browser.togglePictureInPicture() }
                .keyboardShortcut("p", modifiers: [.command, .control])
        }

        CommandGroup(replacing: .help) {
            Button("\(AppConfig.appName) on GitHub") {
                NSWorkspace.shared.open(AppConfig.repositoryURL)
            }
            Button("Report an Issue…") {
                NSWorkspace.shared.open(AppConfig.issuesURL)
            }
        }
    }
}
