import AppKit
import SwiftUI

@main
struct HoichoiForMacApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var browser = BrowserModel()
    @StateObject private var library = LibraryStore()

    init() {
        AppConfig.registerDefaults()
    }

    var body: some Scene {
        Window(AppConfig.appName, id: "main") {
            ContentView()
                .environmentObject(browser)
                .environmentObject(library)
                .frame(minWidth: 860, minHeight: 540)
        }
        .defaultSize(width: 1280, height: 800)
        .commands {
            AppCommands(browser: browser, library: library)
        }

        Settings {
            SettingsView()
                .environmentObject(browser)
                .environmentObject(library)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
