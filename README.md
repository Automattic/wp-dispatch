# WP Notifications

A macOS menu bar app for skimming WordPress.com. It shows your notifications and the Reader (blogs and P2s) in a panel under the W icon, with an in-app reader so you can tell whether something is worth your time before you open a browser.

## Features

- **Notifications.** Choose All or Unread. Opening a note marks it read.
- **Reader.** Feeds for Blogs, P2s, Starred sites and Saved posts. Click a site name to read that site's feed.
- **X-posts.** Shown as compact rows (origin → destination) that open the original post, with a fallback when you can't access the origin P2.
- **Reader pane.** Clean typography, an estimated reading time, and highlighting of mentions of you.
- **Comments drawer.** When closed it shows a horizontal strip of avatars and chat bubbles. When open it becomes a threaded list.
- **Panel.** Drag the bottom edge to resize. Drag the panel off the menu bar to tear it into its own resizable window.
- **Keyboard.** `↑`/`↓` or `j`/`k` move between items, `o` opens in the browser, `s` saves, `esc` closes the reader, and `⌘W` closes the window.

## Build

Requires macOS 14+ and Swift 5.10+ (Xcode or the command-line tools).

```bash
./build.sh            # builds build/WP Notifications.app
./build.sh --install  # builds, then moves it to ~/Applications
```

`build.sh` bundles the SwiftPM executable with `Info.plist` and ad-hoc signs it. There's no Xcode project.

## Project layout

| File | What it does |
|---|---|
| `main.swift`, `App.swift` | Plain AppKit entry point (no SwiftUI `App`, whose Settings scene opens a stray window). |
| `PanelController.swift` | Status item, the attached panel, the detached window, sizing and animations, keyboard handling. |
| `Views.swift` | All SwiftUI views: list and reader panes, rows, pickers, comments drawer, setup screen. |
| `Store.swift` | Sign-in state, notifications, REST helper, session expiry. |
| `ReaderStore.swift` | Reader feeds, pagination, stars and saves, x-post resolution, comments. |
| `Reader.swift` | HTML template for the reader pane, `WKWebView` wrapper, the W logo. |
| `OAuth.swift` | WordPress.com sign-in (see [docs/auth.md](docs/auth.md)). |
| `Credentials.swift` | Token storage in a 0600 JSON file. |

Local data lives in `~/Library/Application Support/WPNotifications/`:
- `credentials.json` holds the token.
- `reader.json` holds stars and saves.

## Docs

- [docs/auth.md](docs/auth.md): how sign-in works and why it's built this way.
