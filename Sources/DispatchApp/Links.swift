import AppKit

/// Opens a link from a post, a profile or WordPress.com's data in the browser (or Mail). Anything
/// else, like `file://` or another app's URL scheme, is refused: those links come from whoever
/// wrote the post.
@MainActor
func openLink(_ url: URL) {
    guard ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") else {
        NSSound.beep()
        return
    }
    NSWorkspace.shared.open(url)
}
