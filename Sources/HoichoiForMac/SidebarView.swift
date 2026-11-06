import AppKit
import SwiftUI

enum SidebarItem: Hashable {
    case home
    case favorite(UUID)
    case recent(UUID)
}

struct SidebarView: View {
    @EnvironmentObject private var browser: BrowserModel
    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        List(selection: selection) {
            Section("Browse") {
                Label("Home", systemImage: "house")
                    .tag(SidebarItem.home)
            }

            Section("Favorites") {
                if library.favorites.isEmpty {
                    Text("Press \u{2318}D to save the page you're on.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(library.favorites) { page in
                        Label(page.title, systemImage: "star")
                            .lineLimit(1)
                            .help(page.url.absoluteString)
                            .tag(SidebarItem.favorite(page.id))
                            .contextMenu { pageMenu(for: page, isFavorite: true) }
                    }
                    .onMove { library.moveFavorites(from: $0, to: $1) }
                }
            }

            if !library.recents.isEmpty {
                Section("Recently Viewed") {
                    ForEach(library.recents) { page in
                        Label(page.title, systemImage: "clock")
                            .lineLimit(1)
                            .help(page.url.absoluteString)
                            .tag(SidebarItem.recent(page.id))
                            .contextMenu { pageMenu(for: page, isFavorite: false) }
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    /// The highlighted row follows whatever page is showing; picking a row navigates.
    private var selection: Binding<SidebarItem?> {
        Binding(
            get: {
                guard let url = browser.currentURL else { return nil }
                if url.isSamePage(as: browser.homeURL) { return .home }
                if let page = library.favorites.first(where: { $0.url.isSamePage(as: url) }) {
                    return .favorite(page.id)
                }
                if let page = library.recents.first(where: { $0.url.isSamePage(as: url) }) {
                    return .recent(page.id)
                }
                return nil
            },
            set: { item in
                switch item {
                case .home:
                    browser.goHome()
                case .favorite(let id):
                    if let page = library.favorites.first(where: { $0.id == id }) { browser.load(page.url) }
                case .recent(let id):
                    if let page = library.recents.first(where: { $0.id == id }) { browser.load(page.url) }
                case nil:
                    break
                }
            }
        )
    }

    @ViewBuilder
    private func pageMenu(for page: SavedPage, isFavorite: Bool) -> some View {
        Button("Open") { browser.load(page.url) }
        Button("Open in Default Browser") { NSWorkspace.shared.open(page.url) }
        Button("Copy Link") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(page.url.absoluteString, forType: .string)
        }
        Divider()
        if isFavorite {
            Button("Remove from Favorites") { library.removeFavorite(page) }
        } else {
            Button("Add to Favorites") { library.toggleFavorite(title: page.title, url: page.url) }
                .disabled(library.isFavorite(page.url))
            Button("Remove from Recently Viewed") { library.removeRecent(page) }
            Button("Clear Recently Viewed") { library.clearRecents() }
        }
    }
}
