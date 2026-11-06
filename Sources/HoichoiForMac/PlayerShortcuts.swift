import WebKit

/// Netflix-style single-key player shortcuts, injected into every page.
///
/// | Key            | Action                  |
/// |----------------|-------------------------|
/// | Space / K      | Play / pause            |
/// | ← / →          | Back / forward 10 s     |
/// | ↑ / ↓          | Volume up / down        |
/// | M              | Mute / unmute           |
/// | F              | Full screen             |
/// | P              | Picture in Picture      |
///
/// They only act when a real player is on screen (not a small or looping
/// preview) and never while you're typing in a text field, so they don't
/// break scrolling or search. The script runs in an isolated JavaScript
/// world, out of reach of the page's own scripts.
enum PlayerShortcuts {
    static let messageName = "playerShortcut"

    static func install(in controller: WKUserContentController, handler: WKScriptMessageHandler) {
        controller.addUserScript(WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false,
            in: .defaultClient
        ))
        controller.add(handler, contentWorld: .defaultClient, name: messageName)
    }

    static let script = """
    (() => {
      if (window.__hoichoiForMacShortcuts) { return; }
      window.__hoichoiForMacShortcuts = true;

      const notify = (text) => {
        try { window.webkit.messageHandlers.\(messageName).postMessage(text); } catch (e) {}
      };

      const isTyping = (el) => {
        if (!el) { return false; }
        if (el.isContentEditable) { return true; }
        const tag = el.tagName;
        if (tag === 'TEXTAREA' || tag === 'SELECT') { return true; }
        if (tag === 'INPUT') {
          const type = (el.type || 'text').toLowerCase();
          return !['button', 'checkbox', 'radio', 'range', 'submit', 'reset', 'image', 'color', 'file'].includes(type);
        }
        return false;
      };

      const isFullscreen = () => !!(document.fullscreenElement || document.webkitFullscreenElement);

      // The main player: a video that fills most of the view (or is full screen)
      // and isn't a looping, auto-playing preview.
      const findPlayer = () => {
        const area = (v) => v.clientWidth * v.clientHeight;
        const candidates = Array.from(document.querySelectorAll('video'))
          .filter((v) => (v.readyState > 0 || v.currentSrc) && !v.loop)
          .filter((v) => isFullscreen() ||
                         (v.clientWidth >= window.innerWidth * 0.6 && v.clientHeight >= window.innerHeight * 0.45));
        if (candidates.length === 0) { return null; }
        return candidates.find((v) => !v.paused && !v.ended) ||
               candidates.sort((a, b) => area(b) - area(a))[0];
      };

      const toggleFullscreen = (video) => {
        if (isFullscreen()) {
          (document.exitFullscreen || document.webkitExitFullscreen).call(document);
          return;
        }
        // Prefer the player container (keeps the site's controls and subtitles).
        let target = video.parentElement || video;
        for (let n = video.parentElement; n && n !== document.body; n = n.parentElement) {
          const sameSize = n.clientWidth >= video.clientWidth && n.clientHeight >= video.clientHeight &&
                           n.clientHeight <= video.clientHeight * 1.5 + 120;
          if (!sameSize) { break; }
          target = n;
        }
        const request = target.requestFullscreen || target.webkitRequestFullscreen;
        if (request) {
          const result = request.call(target);
          if (result && result.catch) { result.catch(() => {}); }
        } else if (video.webkitEnterFullscreen) {
          video.webkitEnterFullscreen();
        }
      };

      const togglePictureInPicture = (video) => {
        if (typeof video.webkitSetPresentationMode === 'function') {
          const pip = video.webkitPresentationMode === 'picture-in-picture';
          video.webkitSetPresentationMode(pip ? 'inline' : 'picture-in-picture');
        } else if (document.pictureInPictureElement) {
          document.exitPictureInPicture();
        } else if (video.requestPictureInPicture) {
          video.requestPictureInPicture().catch(() => {});
        }
      };

      const percent = (x) => Math.round(x * 100) + '%';
      const setVolume = (video, delta) => {
        video.muted = false;
        video.volume = Math.min(1, Math.max(0, Math.round((video.volume + delta) * 10) / 10));
        return 'Volume ' + percent(video.volume);
      };

      window.addEventListener('keydown', (event) => {
        if (event.metaKey || event.ctrlKey || event.altKey) { return; }
        if (isTyping(event.target) || isTyping(document.activeElement)) { return; }

        const video = findPlayer();
        if (!video) { return; }

        const key = event.key.length === 1 ? event.key.toLowerCase() : event.key;
        const toggles = [' ', 'k', 'm', 'f', 'p'];
        if (event.repeat && toggles.includes(key)) { event.preventDefault(); return; }

        let message = null;
        switch (key) {
          case ' ':
          case 'k':
            if (video.paused) { video.play().catch(() => {}); message = 'Play'; }
            else { video.pause(); message = 'Pause'; }
            break;
          case 'ArrowLeft':
            video.currentTime = Math.max(0, video.currentTime - 10);
            message = '\u{2212}10 seconds';
            break;
          case 'ArrowRight': {
            const end = isFinite(video.duration) ? video.duration : Number.MAX_VALUE;
            video.currentTime = Math.min(end, video.currentTime + 10);
            message = '+10 seconds';
            break;
          }
          case 'ArrowUp':
            message = setVolume(video, 0.1);
            break;
          case 'ArrowDown':
            message = setVolume(video, -0.1);
            break;
          case 'm':
            video.muted = !video.muted;
            message = video.muted ? 'Muted' : 'Sound on';
            break;
          case 'f':
            toggleFullscreen(video);
            break;
          case 'p':
            togglePictureInPicture(video);
            break;
          default:
            return;
        }

        // We ran first (capture phase, installed at document start), so stop the
        // site's own handlers from acting on the same key a second time.
        event.preventDefault();
        event.stopImmediatePropagation();
        if (message) { notify(message); }
      }, true);
    })();
    """
}

/// Forwards script messages to the model without the user content controller
/// keeping the model alive (it retains its handlers strongly).
@MainActor
final class ScriptMessageProxy: NSObject, WKScriptMessageHandler {
    private weak var model: BrowserModel?

    init(model: BrowserModel) {
        self.model = model
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == PlayerShortcuts.messageName, let text = message.body as? String else { return }
        model?.showToast(text)
    }
}
