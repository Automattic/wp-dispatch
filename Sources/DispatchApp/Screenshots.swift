import AppKit

/// Stages the panel for website screenshots: `DISPATCH_SCENE=reader|post|comments open Dispatch.app`.
/// Only public blogs (the Reader's Blogs feed) — never notifications or P2s.
@MainActor
enum Screenshots {
    static func stage(_ controller: PanelController) {
        guard let scene = ProcessInfo.processInfo.environment["DISPATCH_SCENE"] else { return }
        Task {
            try? await Task.sleep(for: .seconds(1))
            controller.showPanel()
            controller.switchSection(.reader)
            controller.reader.show(.blogs)
            guard scene == "post" || scene == "comments" else { return }
            for _ in 0..<40 where controller.reader.posts.isEmpty {
                try? await Task.sleep(for: .milliseconds(250))
            }
            if let post = controller.reader.posts.first(where: { !$0.isXPost }) {
                controller.select(post)
            }
            if scene == "comments" {
                try? await Task.sleep(for: .seconds(2))
                controller.commentsOpen = true
            }
        }
    }
}
