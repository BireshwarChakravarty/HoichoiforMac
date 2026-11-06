import AppKit
import SwiftUI
import WebKit

/// Hosts the shared `WKWebView` inside SwiftUI.
///
/// The web view sits in a plain container view and is set to resize with
/// whatever view it's in. That matters for video full screen: WebKit moves
/// the web view into its own full screen window, which starts at the size of
/// the app window and then grows to fill the screen. Without the resizing
/// mask, the web view kept its windowed size and the video ended up stuck in
/// the bottom-left corner.
struct WebView: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        attach(to: container)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        // While WebKit shows the video full screen, the web view lives in
        // WebKit's window; leave it there. WebKit puts it back afterwards. If
        // it ever comes back without a superview, re-attach it here.
        if webView.superview == nil {
            attach(to: container)
        }
    }

    private func attach(to container: NSView) {
        webView.translatesAutoresizingMaskIntoConstraints = true
        webView.autoresizingMask = [.width, .height]
        webView.frame = container.bounds
        container.addSubview(webView)
    }
}
