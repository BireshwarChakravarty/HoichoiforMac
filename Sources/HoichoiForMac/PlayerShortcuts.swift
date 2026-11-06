import WebKit

/// Netflix-style single-key player shortcuts, injected into every page.
///
/// | Key            | Action                  |
/// |----------------|-------------------------|
/// | Space / K      | Play / pause            |
/// | ← / →          | Back / forward 10 s     |
/// | ↑ / ↓          | Volume up / down        |
/// | M              | Mute / unmute           |
/// | F              | Full screen (Esc exits) |
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

      const send = (body) => {
        try { window.webkit.messageHandlers.\(messageName).postMessage(body); } catch (e) {}
      };
      const notify = (text) => send({ toast: text });

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

      // F does what the player's own full screen button does, so the site switches
      // to its full screen layout (no margins, title or back arrow), and WebKit
      // shows that element edge to edge. If the button can't be found, request
      // full screen on the player container; if that doesn't take effect,
      // fall back to the app's window full screen.
      const labelOf = (el) => {
        const cls = typeof el.className === 'string' ? el.className : ((el.className && el.className.baseVal) || '');
        return [el.getAttribute('aria-label'), el.getAttribute('title'), el.getAttribute('data-title'),
                el.getAttribute('data-testid'), cls, el.id].join(' ').toLowerCase();
      };

      const findFullscreenButton = (video) => {
        const root = video.closest('[class*="player" i], [id*="player" i]') || document;
        const candidates = Array.from(root.querySelectorAll(
          'button, [role="button"], [aria-label], [title], [class*="full" i], [data-testid]'
        )).filter((el) => {
          const label = labelOf(el);
          return /full[\\s_-]?screen|maximi[sz]e/.test(label) && !/exit|minimi[sz]e/.test(label);
        });
        const visible = (el) => el.getClientRects().length > 0;
        const hit = candidates.find(visible) || candidates[0];
        return hit ? (hit.closest('button, [role="button"]') || hit) : null;
      };

      const requestOn = (target) => {
        const request = target.requestFullscreen || target.webkitRequestFullscreen;
        if (!request) { return false; }
        const result = request.call(target);
        if (result && result.catch) { result.catch(() => {}); }
        return true;
      };

      const playerContainer = (video) => {
        let target = video.parentElement || video;
        for (let n = video.parentElement; n && n !== document.body; n = n.parentElement) {
          if (!(n.clientWidth >= video.clientWidth && n.clientHeight >= video.clientHeight)) { break; }
          target = n;
          if (/player/i.test(labelOf(n))) { break; }
        }
        return target;
      };

      const toggleFullscreen = (video) => {
        if (isFullscreen()) {
          (document.exitFullscreen || document.webkitExitFullscreen).call(document);
          return;
        }
        const button = findFullscreenButton(video);
        if (button) {
          if (typeof button.click === 'function') { button.click(); }
          else { button.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, view: window })); }
        }
        if (!isFullscreen() && !button) {
          requestOn(playerContainer(video));
        }
        setTimeout(() => {
          if (!isFullscreen()) {
            if (button && requestOn(playerContainer(video))) {
              setTimeout(() => { if (!isFullscreen()) { send({ command: 'toggleFullScreen' }); } }, 600);
            } else {
              send({ command: 'toggleFullScreen' });
            }
          }
        }, 600);
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

        // Esc leaves the app's full screen (macOS doesn't do that by default).
        // Not swallowed, so the site can still use Esc for its own menus.
        if (event.key === 'Escape' && !isFullscreen()) {
          send({ command: 'exitFullScreen' });
          return;
        }

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
        guard message.name == PlayerShortcuts.messageName,
              let body = message.body as? [String: Any],
              let model = self.model
        else { return }

        if let text = body["toast"] as? String {
            model.showToast(text)
        }
        switch body["command"] as? String {
        case "toggleFullScreen"?:
            model.toggleFullScreen()
        case "exitFullScreen"?:
            model.exitFullScreen()
        default:
            break
        }
    }
}
