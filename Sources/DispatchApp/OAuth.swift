import AppKit
import Foundation
import Network

/// WordPress.com sign-in with the implicit grant: no client secret, same as Studio and the
/// WordPress.com desktop app. The token comes back in the URL *fragment*, which browsers never
/// send to a server, so the callback serves a tiny page that forwards it to `/token`.
///
/// Custom schemes (myapp://) only work for WordPress.com's own apps — they're hardcoded in
/// wpcom's `OAuth2::CUSTOM_PROTOCOLS` — so this listens on localhost instead.
@MainActor
final class OAuth {
    /// Shaun's WordPress.com app (developer.wordpress.com/apps). Client IDs aren't secret and the
    /// implicit grant needs nothing else, so it ships in the app. Swap for an Automattic-owned app
    /// before wide distribution.
    static let clientID = "151672"
    /// The app's registered redirect URL. WordPress.com accepts any redirect that starts with it
    /// on the same host, so each sign-in can use whatever free port macOS hands out.
    static let registeredRedirect = "http://localhost"

    struct Token { let value: String; let expires: Date? }

    private var listener: NWListener?
    private var abandon: (() -> Void)?

    func authorize(clientID: String = OAuth.clientID) async throws -> Token {
        // A second Connect click replaces an abandoned attempt.
        abandon?()
        let state = UUID().uuidString
        let redirect = Self.registeredRedirect

        // Port 0: macOS picks a free ephemeral port, so nothing else can be sitting on it.
        // Loopback only, so nothing on the network can reach the listener.
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: .any)
        let listener = try NWListener(using: params)
        self.listener = listener

        return try await withCheckedThrowingContinuation { cont in
            var finished = false
            func finish(_ result: Result<Token, Error>) {
                guard !finished else { return }
                finished = true
                listener.cancel()
                cont.resume(with: result)
            }
            abandon = { finish(.failure(OAuthError.denied("Sign-in was restarted."))) }
            // Don't leave a listener open for good if the browser tab is abandoned.
            DispatchQueue.main.asyncAfter(deadline: .now() + 600) {
                finish(.failure(OAuthError.denied("Sign-in timed out. Click Connect to try again.")))
            }

            listener.newConnectionHandler = { conn in
                conn.start(queue: .main)
                conn.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { data, _, _, _ in
                    let request = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    // First line looks like: GET /token?access_token=…&state=… HTTP/1.1
                    let path = request.split(separator: " ").dropFirst().first.map(String.init) ?? ""
                    let items = URLComponents(string: "http://localhost\(path)")?.queryItems ?? []
                    func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
                    func reply(_ body: String) {
                        conn.send(content: Self.http(body), completion: .contentProcessed { _ in conn.cancel() })
                    }

                    // Only a reply carrying this attempt's state can finish it. Anything else (another
                    // page on this Mac poking at the port) gets an error page and is otherwise ignored.
                    let ours = value("state") == state
                    if path.hasPrefix("/callback") {
                        // Denied requests come back as a query; approvals as a fragment.
                        if let error = value("error") {
                            let why = value("error_description") ?? error
                            reply(Self.message("Couldn’t connect", why))
                            if ours { finish(.failure(OAuthError.denied(why))) }
                        } else {
                            reply(Self.bridge)
                        }
                    } else if path.hasPrefix("/token") {
                        if ours, let token = value("access_token") {
                            reply(Self.message("Connected to WordPress.com", "You can close this tab."))
                            let expires = value("expires_in").flatMap(Double.init).map { Date.now.addingTimeInterval($0) }
                            finish(.success(Token(value: token, expires: expires)))
                        } else {
                            let why = value("error_description") ?? value("error") ?? "Missing token or state mismatch."
                            reply(Self.message("Couldn’t connect", why))
                            if ours { finish(.failure(OAuthError.denied(why))) }
                        }
                    } else {
                        reply(Self.message("Not found", ""))
                    }
                }
            }
            listener.stateUpdateHandler = { s in
                switch s {
                case .ready:
                    guard let port = listener.port?.rawValue else { return }
                    var c = URLComponents(string: "https://public-api.wordpress.com/oauth2/authorize")!
                    c.queryItems = [
                        .init(name: "client_id", value: clientID),
                        .init(name: "redirect_uri", value: "\(redirect):\(port)/callback"),
                        .init(name: "response_type", value: "token"),
                        .init(name: "scope", value: "global"),
                        .init(name: "state", value: state),
                    ]
                    NSWorkspace.shared.open(c.url!)
                case .failed(let e):
                    finish(.failure(e))
                default: break
                }
            }
            listener.start(queue: .main)
        }
    }

    /// Reads `#access_token=…` and hands it to the app's listener as a query string.
    private static let bridge = """
        <h2>Connecting…</h2>
        <script>
          const p = new URLSearchParams(location.hash.slice(1));
          if (p.get('access_token') || p.get('error')) location.replace('/token?' + p.toString());
          else document.body.innerHTML = '<h2>Couldn’t connect</h2><p>WordPress.com didn’t return a token.</p>';
        </script>
        """

    /// Escaped: `detail` can be text from the request, which anything on this Mac could send.
    private static func message(_ title: String, _ detail: String) -> String {
        "<h2>\(ReaderPage.escape(title))</h2><p>\(ReaderPage.escape(detail))</p>"
    }

    nonisolated private static func http(_ body: String) -> Data {
        let html = "<!doctype html><html><body style='font:15px -apple-system;padding:40px'>\(body)</body></html>"
        return Data("HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n\(html)".utf8)
    }
}

enum OAuthError: LocalizedError {
    case denied(String)
    var errorDescription: String? {
        switch self { case .denied(let m): return m }
    }
}
