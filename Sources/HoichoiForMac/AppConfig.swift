import Foundation

/// Central place for app-wide constants and user-default keys.
enum AppConfig {
    static let appName = "Hoichoi for Mac"
    static let defaultHomeURL = URL(string: "https://www.hoichoi.tv/")!
    static let repositoryURL = URL(string: "https://github.com/BireshwarChakravarty/HoichoiforMac")!
    static let issuesURL = URL(string: "https://github.com/BireshwarChakravarty/HoichoiforMac/issues")!

    /// Domains that are treated as "part of the app". Links to anything else that
    /// the user clicks can be handed off to the default browser.
    static let firstPartyDomains = ["hoichoi.tv"]

    /// Appended to WebKit's default user agent so the site sees a regular Safari
    /// browser (WebKit's bare user agent omits the `Version/… Safari/…` part).
    static let safariApplicationName = "Version/18.0 Safari/605.1.15"

    static func isFirstParty(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else { return false }
        return firstPartyDomains.contains { host == $0 || host.hasSuffix("." + $0) }
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            SettingsKey.homeURL: defaultHomeURL.absoluteString,
            SettingsKey.openExternalLinksInBrowser: true,
            SettingsKey.restoreLastPage: true,
        ])
    }
}

enum SettingsKey {
    static let homeURL = "homeURL"
    static let openExternalLinksInBrowser = "openExternalLinksInBrowser"
    static let restoreLastPage = "restoreLastPage"
    static let lastURL = "lastURL"
    static let favorites = "favorites"
    static let recents = "recents"
}

extension URL {
    /// A normalised string used to decide whether two URLs point at the same page
    /// (ignores the fragment, a leading `www.`, letter case of scheme/host and
    /// trailing slashes).
    var comparisonKey: String {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return absoluteString
        }
        components.fragment = nil
        components.scheme = components.scheme?.lowercased()
        if var host = components.host?.lowercased() {
            if host.hasPrefix("www.") { host.removeFirst(4) }
            components.host = host
        }
        var key = components.string ?? absoluteString
        while key.hasSuffix("/") { key.removeLast() }
        return key
    }

    func isSamePage(as other: URL?) -> Bool {
        guard let other else { return false }
        return comparisonKey == other.comparisonKey
    }
}

extension String {
    /// Page titles usually look like "Some Show | hoichoi". Keep the useful part.
    var cleanedPageTitle: String {
        let first = components(separatedBy: " | ").first ?? self
        let trimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? self.trimmingCharacters(in: .whitespacesAndNewlines) : trimmed
    }
}
