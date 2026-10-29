import AppKit
import SwiftUI
import WebKit

/// Builds the self-contained HTML page shown in the reader.
enum ReaderPage {
    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// A site name that opens that site's feed in the Reader (handled by HTMLView).
    static func siteLink(_ id: Int, isFeed: Bool = false, label: String) -> String {
        var c = URLComponents()
        c.scheme = "wpn"
        c.host = "site"
        c.path = "/\(id)"
        c.queryItems = [.init(name: "feed", value: isFeed ? "1" : "0"), .init(name: "name", value: label.plainText)]
        return "<a class=site href=\"\(escape(c.string ?? ""))\" title=\"Read this site\">\(escape(label.plainText))</a>"
    }

    /// `title` and `content` are HTML from WordPress.com; everything else is plain text.
    static func html(eyebrow: String?, title: String, author: String?, avatar: String?, date: String?,
                     url: String?, likers: [(name: String, avatar: String?)], content: String,
                     terms: [String], eyebrowHTML: String? = nil) -> String {
        let when = date.flatMap { ISO8601DateFormatter().date(from: $0) }
            .map { RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: .now) }
        let host = url.flatMap { URL(string: $0)?.host }?.replacingOccurrences(of: ".wordpress.com", with: "")

        // `person` elements open a hovercard (see `js` and HTMLView's "hovercard" handler).
        func person(_ name: String?, _ avatar: String?) -> String {
            gravatarHash(avatar) == nil ? ""
                : " data-person data-name=\"\(escape(name ?? ""))\" data-avatar=\"\(escape(avatar ?? ""))\""
        }
        let byline = [author.map { "<strong\(person($0, avatar))>\(escape($0))</strong>" }, host.map(escape), when]
            .compactMap { $0 }.joined(separator: "<span class=sep>·</span>")
        let avatarTag = avatar.map { "<img class=avatar src=\"\(escape($0))\"\(person(author, $0))>" } ?? ""
        let likersTag = likers.isEmpty ? "" : """
            <div class=likers>\(likers.prefix(12).map { p in
                "<span class=liker\(person(p.name, p.avatar))>\(p.avatar.map { "<img src=\"\(escape($0))\">" } ?? "")\(escape(p.name))</span>"
            }.joined())</div>
            """
        let termsJSON = (try? String(data: JSONEncoder().encode(terms), encoding: .utf8)) ?? "[]"

        return """
        <!doctype html><html><head><meta charset=utf-8>
        <meta name=viewport content="width=device-width">
        <style>\(css)</style></head><body>
        <header>
          \((eyebrowHTML ?? eyebrow.map(escape)).map { "<div class=eyebrow>\($0)</div>" } ?? "")
          <h1>\(title)</h1>
          <div class=byline>\(avatarTag)<span>\(byline)</span></div>
          <div class=chips><span id=time class=chip></span><button id=jump class="chip me" hidden></button></div>
          \(likersTag)
        </header>
        <article id=content>\(content)</article>
        <script>const TERMS = \(termsJSON);\(js)</script>
        </body></html>
        """
    }

    private static let css = """
    :root { color-scheme: light dark; --fg:#1d1d1f; --muted:#6e6e73; --faint:#e6e6ea; --chip:#f0f0f3;
            --link:#0a66d8; --mark:rgba(255,196,0,.42); --markOn:rgba(255,150,0,.75); }
    @media (prefers-color-scheme: dark) {
      :root { --fg:#f2f2f5; --muted:#9a9aa2; --faint:#34343a; --chip:#2a2a30; --link:#5aa8ff;
              --mark:rgba(255,204,0,.30); --markOn:rgba(255,170,0,.65); }
    }
    * { box-sizing:border-box; }
    html, body { background:transparent; margin:0; }
    body { font:13.5px/1.55 -apple-system, system-ui; color:var(--fg); padding:18px 24px 48px; max-width:720px; margin:0 auto;
           -webkit-font-smoothing:antialiased; overflow-wrap:anywhere; }
    header { margin-bottom:18px; padding-bottom:16px; border-bottom:1px solid var(--faint); }
    .eyebrow { font-size:11.5px; color:var(--muted); margin-bottom:4px; }
    .eyebrow a.site { color:var(--muted); font-weight:600; }
    .eyebrow a.site::after { content:" ›"; opacity:.6; }
    .eyebrow a.site:hover { color:var(--link); text-decoration:none; }
    h1 { font-size:18px; line-height:1.3; font-weight:650; margin:0 0 10px; letter-spacing:-.01em; }
    .byline { display:flex; align-items:center; gap:8px; font-size:12px; color:var(--muted); }
    .byline strong { color:var(--fg); font-weight:600; }
    .avatar { width:20px; height:20px; border-radius:50%; }
    .sep { margin:0 6px; opacity:.6; }
    .chips { display:flex; gap:6px; margin-top:12px; }
    .chips:empty, .chip:empty { display:none; }
    .chip { font:500 11px -apple-system; padding:3px 9px; border-radius:20px; background:var(--chip);
            color:var(--muted); border:0; }
    .chip.me { background:var(--mark); color:var(--fg); cursor:pointer; }
    .likers { display:flex; flex-wrap:wrap; gap:6px; margin-top:12px; }
    .liker { display:flex; align-items:center; gap:6px; font-size:12px; padding:3px 9px 3px 3px;
             border-radius:20px; background:var(--chip); }
    .liker img { width:18px; height:18px; border-radius:50%; }
    article h1, article h2 { font-size:15.5px; margin:1.6em 0 .5em; }
    article h3, article h4, article h5 { font-size:14px; margin:1.4em 0 .4em; }
    article p, article ul, article ol { margin:0 0 .85em; }
    article ul, article ol { padding-left:1.3em; }
    article li { margin:.2em 0; }
    article [class*="-font-size"] { font-size:inherit !important; }
    a { color:var(--link); text-decoration:none; }
    a:hover { text-decoration:underline; }
    img, video, iframe { max-width:100%; height:auto; border-radius:6px; }
    figure { margin:1em 0; }
    figcaption { font-size:11.5px; color:var(--muted); margin-top:4px; }
    blockquote { margin:1em 0; padding:2px 0 2px 12px; border-left:3px solid var(--faint); color:var(--muted); }
    pre, code { font:12px ui-monospace, Menlo; background:var(--chip); border-radius:4px; }
    code { padding:1px 4px; } pre { padding:10px; overflow:auto; }
    table { border-collapse:collapse; display:block; overflow-x:auto; font-size:12.5px; }
    td, th { border:1px solid var(--faint); padding:4px 8px; text-align:left; }
    hr { border:0; border-top:1px solid var(--faint); margin:1.5em 0; }
    .notice { font-size:12.5px; padding:10px 12px; margin:0 0 16px; border-radius:8px; background:var(--chip); }
    mark.me { background:var(--mark); color:inherit; border-radius:3px; padding:0 2px; transition:background .3s; }
    mark.me.on { background:var(--markOn); }
    .sharedaddy, .jp-relatedposts, .wpcom-reblog-snapshot { display:none !important; }
    """

    private static let js = """
    // Hovercards: tell the app where a person is, so it can open their card beside them.
    const hc = window.webkit?.messageHandlers?.hovercard;
    if (hc) {
      for (const el of document.querySelectorAll('[data-person]')) {
        el.addEventListener('mouseenter', () => {
          const r = el.getBoundingClientRect();
          hc.postMessage({ enter: true, name: el.dataset.name, avatar: el.dataset.avatar,
                           x: r.left, y: r.top, w: r.width, h: r.height });
        });
        el.addEventListener('mouseleave', () => hc.postMessage({ enter: false }));
      }
      addEventListener('scroll', () => hc.postMessage({ enter: false }), { passive: true });
    }
    const content = document.getElementById('content');
    const words = content.innerText.split(/\\s+/).filter(Boolean).length;
    document.getElementById('time').textContent =
      words < 120 ? 'Quick read' : Math.max(1, Math.round(words / 230)) + ' min read';

    const esc = s => s.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&');
    const terms = TERMS.slice().sort((a, b) => b.length - a.length);
    const marks = [];
    if (terms.length) {
      const re = new RegExp(terms.map(t => (/^\\w/.test(t) ? '\\\\b' : '') + esc(t) + '\\\\b').join('|'), 'gi');
      const walker = document.createTreeWalker(content, NodeFilter.SHOW_TEXT);
      const nodes = [];
      while (walker.nextNode()) nodes.push(walker.currentNode);
      for (const node of nodes) {
        const text = node.nodeValue;
        re.lastIndex = 0;
        if (!re.test(text)) continue;
        re.lastIndex = 0;
        const frag = document.createDocumentFragment();
        let last = 0, m;
        while ((m = re.exec(text))) {
          frag.append(text.slice(last, m.index));
          const mark = document.createElement('mark');
          mark.className = 'me';
          mark.textContent = m[0];
          frag.append(mark);
          marks.push(mark);
          last = m.index + m[0].length;
        }
        frag.append(text.slice(last));
        node.replaceWith(frag);
      }
    }

    const jump = document.getElementById('jump');
    let at = -1;
    if (marks.length) {
      jump.hidden = false;
      const label = () => jump.textContent = (marks.length === 1 ? 'You’re mentioned' :
        `You’re mentioned ${marks.length}×`) + (at >= 0 ? `  ${at + 1}/${marks.length}` : '') + '  ↓';
      label();
      jump.onclick = () => {
        marks[at]?.classList.remove('on');
        at = (at + 1) % marks.length;
        marks[at].classList.add('on');
        marks[at].scrollIntoView({ behavior: 'smooth', block: 'center' });
        label();
      };
    }
    """
}

/// Transparent WKWebView that opens every link in the default browser.
struct HTMLView: NSViewRepresentable {
    let html: String
    let baseURL: URL?
    @EnvironmentObject var reader: ReaderStore
    @EnvironmentObject var c: PanelController

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "hovercard")
        let view = WKWebView(frame: .zero, configuration: config)
        context.coordinator.anchor.view = view
        view.navigationDelegate = context.coordinator
        view.setValue(false, forKey: "drawsBackground")
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.reader = reader
        context.coordinator.panel = c
        guard context.coordinator.loaded != html else { return }
        context.coordinator.loaded = html
        view.loadHTMLString(html, baseURL: baseURL)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var loaded: String?
        let anchor = Hovercard.Anchor()
        var reader: ReaderStore?
        var panel: PanelController?

        /// `{enter, name, avatar, x, y, w, h}` from the page's hover listeners (rect in page points).
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            MainActor.assumeIsolated {
                guard let body = message.body as? [String: Any] else { return }
                guard body["enter"] as? Bool == true, let reader, let panel else { return Hovercard.shared.leave(anchor) }
                func n(_ k: String) -> CGFloat { CGFloat((body[k] as? NSNumber)?.doubleValue ?? 0) }
                anchor.rect = NSRect(x: n("x"), y: n("y"), width: n("w"), height: n("h"))
                let card = PersonCard(avatar: body["avatar"] as? String, name: body["name"] as? String)
                    .environmentObject(reader).environmentObject(panel)
                Hovercard.shared.hover(AnyView(card), from: anchor, edge: .bottom)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated, let url = action.request.url {
                if url.scheme == "wpn" {
                    NotificationCenter.default.post(name: .openSite, object: url)
                } else {
                    NSWorkspace.shared.open(url)
                }
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

/// The WordPress "W" as a template image for the menu bar.
enum WordPressLogo {
    static let image: NSImage = {
        let svg = """
        <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path d="M21.469 6.825c.84 1.537 1.318 3.3 1.318 5.175 0 3.979-2.156 7.456-5.363 9.325l3.295-9.527c.615-1.54.82-2.771.82-3.864 0-.405-.026-.78-.07-1.11m-7.981.105c.647-.03 1.232-.105 1.232-.105.582-.075.514-.93-.067-.899 0 0-1.755.135-2.88.135-1.064 0-2.85-.15-2.85-.15-.585-.03-.661.855-.075.885 0 0 .54.061 1.125.09l1.68 4.605-2.37 7.08L5.354 6.9c.649-.03 1.234-.1 1.234-.1.585-.075.516-.93-.065-.896 0 0-1.746.138-2.874.138-.2 0-.438-.008-.69-.015C4.911 3.15 8.235 1.215 12 1.215c2.809 0 5.365 1.072 7.286 2.833-.046-.003-.091-.009-.141-.009-1.06 0-1.812.923-1.812 1.914 0 .89.513 1.643 1.06 2.531.411.72.89 1.643.89 2.977 0 .915-.354 1.994-.821 3.479l-1.075 3.585-3.9-11.61.001.014zM12 22.784c-1.059 0-2.081-.153-3.048-.437l3.237-9.406 3.315 9.087c.024.053.05.101.078.149-1.12.393-2.325.609-3.582.609M1.211 12c0-1.564.336-3.05.935-4.39L7.29 21.709C3.694 19.96 1.212 16.271 1.211 12M12 0C5.385 0 0 5.385 0 12s5.385 12 12 12 12-5.385 12-12S18.615 0 12 0"/></svg>
        """
        // Draw the SVG through a handler; SVG-backed images render blank in the status bar.
        let svgImage = NSImage(data: Data(svg.utf8))
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { rect in
            svgImage?.draw(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }()
}

extension Notification.Name {
    /// Posted with a `wpn://site/<id>?feed=0|1` URL when a site name is clicked in the reader.
    static let openSite = Notification.Name("WPNOpenSite")
}
