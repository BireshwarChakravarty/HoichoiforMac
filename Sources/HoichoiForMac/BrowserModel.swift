import AppKit
import Combine
import WebKit

/// Owns the single `WKWebView` that renders hoichoi.tv and exposes its state to SwiftUI.
@MainActor
final class BrowserModel: NSObject, ObservableObject {
    let webView: WKWebView

    @Published private(set) var title = AppConfig.appName
    @Published private(set) var currentURL: URL?
    @Published private(set) var isLoading = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var loadError: String?
    @Published private(set) var toastMessage: String?

    /// Called (debounced) whenever the visible page settles on a new URL/title.
    var onPageVisited: ((_ title: String, _ url: URL) -> Void)?

    private var popupWindows: [PopupWindowController] = []
    private var cancellables = Set<AnyCancellable>()
    private var lastFailedURL: URL?
    private var toastTask: Task<Void, Never>?
    private var hasLoadedInitialPage = false

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default() // keeps you signed in between launches
        configuration.applicationNameForUserAgent = AppConfig.safariApplicationName
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        #if DEBUG
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        #endif

        PlayerShortcuts.install(
            in: webView.configuration.userContentController,
            handler: ScriptMessageProxy(model: self)
        )

        bindWebViewState()
    }

    // MARK: - Settings-backed values

    var homeURL: URL {
        if let string = UserDefaults.standard.string(forKey: SettingsKey.homeURL),
           let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
           let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
           url.host != nil {
            return url
        }
        return AppConfig.defaultHomeURL
    }

    private var openExternalLinksInBrowser: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.openExternalLinksInBrowser)
    }

    // MARK: - Navigation

    func loadInitialPageIfNeeded() {
        guard !hasLoadedInitialPage else { return }
        hasLoadedInitialPage = true

        if UserDefaults.standard.bool(forKey: SettingsKey.restoreLastPage),
           let string = UserDefaults.standard.string(forKey: SettingsKey.lastURL),
           let url = URL(string: string),
           AppConfig.isFirstParty(url) {
            load(url)
        } else {
            goHome()
        }
    }

    func load(_ url: URL) {
        loadError = nil
        webView.load(URLRequest(url: url))
    }

    func goHome() { load(homeURL) }
    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func stopLoading() { webView.stopLoading() }

    func reload() {
        if loadError != nil, let failed = lastFailedURL ?? webView.url {
            load(failed)
        } else if webView.url == nil {
            goHome()
        } else {
            webView.reload()
        }
    }

    func reloadIgnoringCache() {
        loadError = nil
        webView.reloadFromOrigin()
    }

    // MARK: - Zoom

    func zoomIn() { webView.pageZoom = min(webView.pageZoom + 0.1, 3.0) }
    func zoomOut() { webView.pageZoom = max(webView.pageZoom - 0.1, 0.5) }
    func resetZoom() { webView.pageZoom = 1.0 }

    // MARK: - Full screen

    var isWindowFullScreen: Bool {
        webView.window?.styleMask.contains(.fullScreen) ?? false
    }

    func toggleFullScreen() {
        webView.window?.toggleFullScreen(nil)
    }

    func exitFullScreen() {
        if isWindowFullScreen { toggleFullScreen() }
    }

    // MARK: - Sharing

    func copyCurrentLink() {
        guard let url = currentURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        showToast("Link copied")
    }

    func openInDefaultBrowser() {
        guard let url = currentURL else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: - Website data

    func clearWebsiteData() {
        UserDefaults.standard.removeObject(forKey: SettingsKey.lastURL)
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        ) { [weak self] in
            self?.goHome()
            self?.showToast("Website data cleared")
        }
    }

    // MARK: - Playback controls

    func togglePlayPause() {
        runOnVideo("""
        if (v.paused) { v.play(); return 'Playing'; }
        v.pause(); return 'Paused';
        """)
    }

    func seek(by seconds: Double) {
        let label = seconds >= 0 ? "Forward \(Int(seconds)) seconds" : "Back \(Int(-seconds)) seconds"
        runOnVideo("""
        const end = isFinite(v.duration) ? v.duration : Number.MAX_VALUE;
        v.currentTime = Math.max(0, Math.min(end, v.currentTime + (\(seconds))));
        return '\(label)';
        """)
    }

    func setPlaybackRate(_ rate: Double) {
        runOnVideo("""
        v.playbackRate = \(rate);
        return 'Speed ' + v.playbackRate + '\u{00D7}';
        """)
    }

    func toggleMute() {
        runOnVideo("""
        v.muted = !v.muted;
        return v.muted ? 'Muted' : 'Unmuted';
        """)
    }

    func togglePictureInPicture() {
        runOnVideo("""
        if (typeof v.webkitSetPresentationMode === 'function' &&
            (!v.webkitSupportsPresentationMode || v.webkitSupportsPresentationMode('picture-in-picture'))) {
            const entering = v.webkitPresentationMode !== 'picture-in-picture';
            v.webkitSetPresentationMode(entering ? 'picture-in-picture' : 'inline');
            return entering ? '' : 'Picture in Picture closed';
        }
        if (document.pictureInPictureElement) { document.exitPictureInPicture(); return ''; }
        if (typeof v.requestPictureInPicture === 'function') { v.requestPictureInPicture(); return ''; }
        return 'unsupported';
        """)
    }

    /// Runs `body` with `v` bound to the most relevant `<video>` element on the page
    /// (the one that is playing, otherwise the largest one) and shows the returned
    /// string as a short on-screen message.
    private func runOnVideo(_ body: String) {
        let script = """
        (function () {
            const videos = Array.from(document.querySelectorAll('video'));
            if (videos.length === 0) { return 'no-video'; }
            const area = (x) => x.clientWidth * x.clientHeight;
            const v = videos.find((x) => !x.paused && !x.ended) ||
                      videos.slice().sort((a, b) => area(b) - area(a))[0];
            try {
                \(body)
            } catch (e) {
                return 'error:' + e;
            }
        })();
        """
        webView.evaluateJavaScript(script) { [weak self] result, _ in
            guard let self else { return }
            switch result as? String {
            case "no-video"?:
                self.showToast("No video on this page")
            case "unsupported"?:
                self.showToast("Picture in Picture isn't available for this video")
            case let message? where message.hasPrefix("error:"):
                self.showToast("Couldn't control the video")
            case let message? where !message.isEmpty:
                self.showToast(message)
            default:
                break
            }
        }
    }

    func showToast(_ message: String) {
        toastMessage = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }

    // MARK: - State binding

    private func bindWebViewState() {
        webView.publisher(for: \.title)
            .map { title -> String in
                guard let title, !title.isEmpty else { return AppConfig.appName }
                return title.cleanedPageTitle
            }
            .receive(on: RunLoop.main)
            .assign(to: &$title)

        webView.publisher(for: \.url).receive(on: RunLoop.main).assign(to: &$currentURL)
        webView.publisher(for: \.isLoading).receive(on: RunLoop.main).assign(to: &$isLoading)
        webView.publisher(for: \.estimatedProgress).receive(on: RunLoop.main).assign(to: &$progress)
        webView.publisher(for: \.canGoBack).receive(on: RunLoop.main).assign(to: &$canGoBack)
        webView.publisher(for: \.canGoForward).receive(on: RunLoop.main).assign(to: &$canGoForward)

        // hoichoi.tv is a single-page app, so `didFinish` doesn't fire for most
        // in-app navigations. Watch the URL + title instead.
        Publishers.CombineLatest(webView.publisher(for: \.url), webView.publisher(for: \.title))
            .debounce(for: .seconds(1.5), scheduler: RunLoop.main)
            .sink { [weak self] url, title in
                guard let self, let url, AppConfig.isFirstParty(url) else { return }
                UserDefaults.standard.set(url.absoluteString, forKey: SettingsKey.lastURL)
                if let title, !title.isEmpty {
                    self.onPageVisited?(title, url)
                }
            }
            .store(in: &cancellables)
    }

    private func handleNavigationError(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled { return }
        // 102: frame load interrupted by policy change, 204: plug-in handled load (media).
        if nsError.domain == "WebKitErrorDomain", nsError.code == 102 || nsError.code == 204 { return }

        lastFailedURL = (nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL) ?? webView.url
        loadError = nsError.localizedDescription
    }

    fileprivate func removePopup(_ popup: PopupWindowController) {
        popupWindows.removeAll { $0 === popup }
    }
}

// MARK: - WKNavigationDelegate

extension BrowserModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .allow }
        let scheme = url.scheme?.lowercased() ?? ""

        // mailto:, tel:, upi:, app store links, etc. belong to other apps.
        let webSchemes: Set<String> = ["http", "https", "about", "blob", "data", "javascript"]
        if !webSchemes.contains(scheme) {
            NSWorkspace.shared.open(url)
            return .cancel
        }

        // Links the user clicks that leave hoichoi.tv (social media, help pages…)
        // open in the default browser. Redirects and form posts (sign-in, payments)
        // stay inside the app.
        if navigationAction.navigationType == .linkActivated,
           navigationAction.targetFrame?.isMainFrame ?? true,
           !AppConfig.isFirstParty(url),
           openExternalLinksInBrowser {
            NSWorkspace.shared.open(url)
            return .cancel
        }

        return .allow
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loadError = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadError = nil
        lastFailedURL = nil
        // Give the page keyboard focus so Space, arrows, etc. work straight away,
        // unless the user is focused somewhere else (e.g. the sidebar).
        if let window = webView.window, window.firstResponder === window || window.firstResponder == nil {
            window.makeFirstResponder(webView)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationError(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

// MARK: - WKUIDelegate

extension BrowserModel: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // A plain `target="_blank"` link: keep hoichoi pages in the main window and
        // send everything else to the browser.
        if navigationAction.navigationType == .linkActivated {
            if let url = navigationAction.request.url {
                if AppConfig.isFirstParty(url) || !openExternalLinksInBrowser {
                    webView.load(navigationAction.request)
                } else {
                    NSWorkspace.shared.open(url)
                }
            }
            return nil
        }

        // A scripted `window.open` – typically "Sign in with Google/Facebook/Apple".
        // These need a real popup that can talk back to its opener.
        let popup = PopupWindowController(configuration: configuration, windowFeatures: windowFeatures)
        popup.onClose = { [weak self, weak popup] in
            guard let self, let popup else { return }
            self.removePopup(popup)
        }
        popupWindows.append(popup)
        popup.showWindow(nil)
        return popup.webView
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async {
        let alert = NSAlert()
        alert.messageText = frame.request.url?.host ?? AppConfig.appName
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async -> Bool {
        let alert = NSAlert()
        alert.messageText = frame.request.url?.host ?? AppConfig.appName
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo
    ) async -> String? {
        let alert = NSAlert()
        alert.messageText = frame.request.url?.host ?? AppConfig.appName
        alert.informativeText = prompt
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = defaultText ?? ""
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo
    ) async -> [URL]? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        return panel.runModal() == .OK ? panel.urls : nil
    }
}
