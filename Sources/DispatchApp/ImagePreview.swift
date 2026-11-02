import AppKit
import Quartz

/// Images from the reader, in macOS's own Quick Look window: click one in a post and it opens there,
/// with the post's other images a ← / → away. Quick Look needs files, so each image is downloaded
/// first, with the app's token on *.wordpress.com so private P2 images come too (as `MediaLoader` does).
@MainActor
final class ImagePreview: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    static let shared = ImagePreview()

    private var items: [URL] = []
    private var showing = 0

    private let folder: URL = {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("dispatch-images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// `urls` are the post's images, as the page has them (https, or `wpn-media://` for private ones).
    func show(_ urls: [String], at index: Int, token: String?) {
        guard urls.indices.contains(index) else { return }
        Task {
            // The one you clicked first, so the window opens right away; the rest join it as they arrive.
            guard let first = await download(urls[index], token: token) else { return }
            items = [first]
            showing = 0
            present()
            var all: [URL?] = Array(repeating: nil, count: urls.count)
            all[index] = first
            await withTaskGroup(of: (Int, URL?).self) { group in
                for (i, u) in urls.enumerated() where i != index {
                    group.addTask { (i, await self.download(u, token: token)) }
                }
                for await (i, file) in group { all[i] = file }
            }
            let files = all.compactMap { $0 }
            guard files.count > 1, let panel = QLPreviewPanel.shared(), panel.isVisible else { return }
            let current = items.indices.contains(panel.currentPreviewItemIndex) ? items[panel.currentPreviewItemIndex] : first
            items = files
            panel.reloadData()
            panel.currentPreviewItemIndex = files.firstIndex(of: current) ?? 0
        }
    }

    private func present() {
        guard let panel = QLPreviewPanel.shared() else { return }
        NSApp.activate(ignoringOtherApps: true) // Dispatch's panel doesn't activate the app; Quick Look needs it
        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.currentPreviewItemIndex = showing
        panel.makeKeyAndOrderFront(nil)
        // Dispatch's panel floats at menu level; Quick Look has to sit above it, or it opens behind.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
    }

    private nonisolated func download(_ address: String, token: String?) async -> URL? {
        guard var parts = URLComponents(string: address) else { return nil }
        if parts.scheme == MediaLoader.scheme { parts.scheme = "https" }
        guard let url = parts.url, url.scheme == "https" else { return nil }
        var req = URLRequest(url: url)
        if let token, url.host()?.hasSuffix(".wordpress.com") == true {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        // Named for the image (Quick Look shows the name), kept apart so two "image.jpg"s don't collide.
        let name = url.lastPathComponent.isEmpty ? "image" : url.lastPathComponent
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dispatch-images/\(abs(address.hashValue))", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(name)
        guard (try? data.write(to: file)) != nil else { return nil }
        return file
    }

    // MARK: QLPreviewPanelDataSource

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated { items.count }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        MainActor.assumeIsolated { items.indices.contains(index) ? items[index] as NSURL : nil }
    }
}
