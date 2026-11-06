import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            PrivacySettingsView()
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
        }
        .frame(width: 480)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(SettingsKey.homeURL) private var homeURL = AppConfig.defaultHomeURL.absoluteString
    @AppStorage(SettingsKey.restoreLastPage) private var restoreLastPage = true
    @AppStorage(SettingsKey.openExternalLinksInBrowser) private var openExternalLinks = true

    var body: some View {
        Form {
            Section {
                TextField("Home page", text: $homeURL)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Reset to Default") {
                        homeURL = AppConfig.defaultHomeURL.absoluteString
                    }
                    .disabled(homeURL == AppConfig.defaultHomeURL.absoluteString)
                }
            }

            Section {
                Toggle("Reopen the last page when the app starts", isOn: $restoreLastPage)
                Toggle("Open links outside hoichoi.tv in your default browser", isOn: $openExternalLinks)
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
    }
}

private struct PrivacySettingsView: View {
    @EnvironmentObject private var browser: BrowserModel
    @EnvironmentObject private var library: LibraryStore
    @State private var confirmClearData = false

    var body: some View {
        Form {
            Section {
                LabeledContent("Website data") {
                    Button("Clear\u{2026}", role: .destructive) { confirmClearData = true }
                }
                Text("Removes cookies, cache and local storage. You will be signed out of hoichoi.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Recently viewed") {
                    Button("Clear") { library.clearRecents() }
                        .disabled(library.recents.isEmpty)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .confirmationDialog("Clear all website data?", isPresented: $confirmClearData) {
            Button("Clear Website Data", role: .destructive) { browser.clearWebsiteData() }
        } message: {
            Text("You will be signed out of hoichoi.")
        }
    }
}
