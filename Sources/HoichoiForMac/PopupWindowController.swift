import AppKit
import Combine
import WebKit

/// A small window used for pages opened with `window.open`, e.g. social sign-in.
/// The web view is created from the configuration WebKit hands us so that the
/// popup can communicate with (and be closed by) its opener.
@MainActor
final class PopupWindowController: NSWindowController, NSWindowDelegate, WKUIDelegate {
    let webView: WKWebView
    var onClose: (() -> Void)?

    private var cancellables = Set<AnyCancellable>()

    init(configuration: WKWebViewConfiguration, windowFeatures: WKWindowFeatures) {
        let width = max(windowFeatures.width?.doubleValue ?? 520, 360)
        let height = max(windowFeatures.height?.doubleValue ?? 680, 420)
        let frame = NSRect(x: 0, y: 0, width: width, height: height)

        webView = WKWebView(frame: frame, configuration: configuration)

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.contentView = webView
        window.title = AppConfig.appName
        window.center()

        super.init(window: window)

        window.delegate = self
        webView.uiDelegate = self

        webView.publisher(for: \.title)
            .receive(on: RunLoop.main)
            .sink { [weak window] title in
                window?.title = (title?.isEmpty == false) ? title! : AppConfig.appName
            }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // The page called `window.close()`.
    func webViewDidClose(_ webView: WKWebView) {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
        onClose = nil
    }
}
