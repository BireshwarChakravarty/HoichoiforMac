import Foundation

/// A page the user saved or visited.
struct SavedPage: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var url: URL
}

/// Persists favourites and recently viewed pages in `UserDefaults`.
@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var favorites: [SavedPage] = [] {
        didSet { persist(favorites, key: SettingsKey.favorites) }
    }

    @Published private(set) var recents: [SavedPage] = [] {
        didSet { persist(recents, key: SettingsKey.recents) }
    }

    private let defaults: UserDefaults
    private let maxRecents = 15

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        favorites = Self.load(key: SettingsKey.favorites, from: defaults)
        recents = Self.load(key: SettingsKey.recents, from: defaults)
    }

    // MARK: Favourites

    func isFavorite(_ url: URL?) -> Bool {
        guard let url else { return false }
        return favorites.contains { $0.url.isSamePage(as: url) }
    }

    func toggleFavorite(title: String, url: URL?) {
        guard let url else { return }
        if let index = favorites.firstIndex(where: { $0.url.isSamePage(as: url) }) {
            favorites.remove(at: index)
        } else {
            favorites.append(SavedPage(title: title.cleanedPageTitle, url: url))
        }
    }

    func removeFavorite(_ page: SavedPage) {
        favorites.removeAll { $0.id == page.id }
    }

    func moveFavorites(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: Recents

    func recordVisit(title: String, url: URL, homeURL: URL) {
        guard AppConfig.isFirstParty(url), !url.isSamePage(as: homeURL) else { return }
        let cleaned = title.cleanedPageTitle
        guard !cleaned.isEmpty else { return }
        var updated = recents.filter { !$0.url.isSamePage(as: url) }
        updated.insert(SavedPage(title: cleaned, url: url), at: 0)
        if updated.count > maxRecents { updated.removeLast(updated.count - maxRecents) }
        recents = updated
    }

    func removeRecent(_ page: SavedPage) {
        recents.removeAll { $0.id == page.id }
    }

    func clearRecents() {
        recents = []
    }

    // MARK: Persistence

    private func persist(_ pages: [SavedPage], key: String) {
        if let data = try? JSONEncoder().encode(pages) {
            defaults.set(data, forKey: key)
        }
    }

    private static func load(key: String, from defaults: UserDefaults) -> [SavedPage] {
        guard let data = defaults.data(forKey: key),
              let pages = try? JSONDecoder().decode([SavedPage].self, from: data)
        else { return [] }
        return pages
    }
}
