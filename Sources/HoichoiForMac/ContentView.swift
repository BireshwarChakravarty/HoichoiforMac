import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var browser: BrowserModel
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            BrowserView()
                .toolbar { toolbarContent }
        }
        .navigationTitle(browser.title)
        .onAppear {
            let store = self.library
            let model = self.browser
            model.onPageVisited = { [weak store, weak model] title, url in
                guard let store, let model else { return }
                store.recordVisit(title: title, url: url, homeURL: model.homeURL)
            }
            model.loadInitialPageIfNeeded()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button { browser.goBack() } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .disabled(!browser.canGoBack)
            .help("Go back")

            Button { browser.goForward() } label: {
                Label("Forward", systemImage: "chevron.right")
            }
            .disabled(!browser.canGoForward)
            .help("Go forward")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            if browser.isLoading {
                Button { browser.stopLoading() } label: {
                    Label("Stop", systemImage: "xmark")
                }
                .help("Stop loading")
            } else {
                Button { browser.reload() } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .help("Reload this page")
            }

            Button { browser.togglePictureInPicture() } label: {
                Label("Picture in Picture", systemImage: "pip.enter")
            }
            .help("Picture in Picture")

            let isFavorite = library.isFavorite(browser.currentURL)
            Button {
                library.toggleFavorite(title: browser.title, url: browser.currentURL)
            } label: {
                Label(isFavorite ? "Remove from Favorites" : "Add to Favorites",
                      systemImage: isFavorite ? "star.fill" : "star")
            }
            .disabled(browser.currentURL == nil)
            .help(isFavorite ? "Remove from Favorites" : "Add to Favorites")
        }
    }
}

/// The web content plus loading, error and toast overlays.
struct BrowserView: View {
    @EnvironmentObject private var browser: BrowserModel

    var body: some View {
        WebView(webView: browser.webView)
            .overlay(alignment: .top) {
                if browser.isLoading {
                    ProgressView(value: min(max(browser.progress, 0.05), 1))
                        .progressViewStyle(.linear)
                        .controlSize(.small)
                        .tint(.accentColor)
                        .frame(maxWidth: .infinity)
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                if let error = browser.loadError {
                    LoadErrorView(message: error) { browser.reload() }
                }
            }
            .overlay(alignment: .bottom) {
                if let message = browser.toastMessage {
                    Text(message)
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 32)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: browser.toastMessage)
    }
}

struct LoadErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44, weight: .regular))
                .foregroundStyle(.secondary)
            Text("Can't open hoichoi")
                .font(.title2.weight(.semibold))
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Button("Try Again", action: retry)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
