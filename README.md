# Dispatch for WordPress.com

A macOS menu bar app for skimming WordPress.com. Your notifications and the Reader (blogs and P2s) sit in a panel under the W icon, with an in-app reader so you can tell whether something is worth your time before you open a browser.

**Website and download:** https://dispatchapp.space.fast · **Current version:** see `CFBundleShortVersionString` in `Info.plist`.

## Features

- **Notifications.** Choose All or Unread. Opening a note marks it read.
- **Reader.** Feeds for Blogs, P2s, Starred sites and Saved posts. Click a site name to read that site's feed.
- **X-posts.** Shown as compact rows (origin → destination) that open the original post, with a fallback when you can't access the origin P2.
- **Reader pane.** Clean typography, an estimated reading time, and highlighting of mentions of you.
- **Comments.** When closed, the drawer shows a horizontal strip of avatars and chat bubbles. When open, it becomes a threaded list where you can like comments, reply to them, or comment on the post.
- **Panel.** Drag the bottom edge to resize. Drag the header to tear it off into a resizable window.
- **Keyboard.** `↑`/`↓` or `j`/`k` move between items, `o` opens in the browser, `s` saves, `esc` closes the reader, and `⌘W` closes the window.
- **Updates.** Dispatch checks for updates once a day, or on demand from ⋯ → Check for Updates…

## Quick start

Requires macOS 14+ and Swift 5.10+ (Xcode or the Command Line Tools).

```bash
./build.sh --install
```

```bash
open ~/Applications/Dispatch.app
```

To ship an update to everyone who has it installed:

```bash
./release.sh 0.2.0
```

## Docs

| Doc | For |
|---|---|
| [docs/development.md](docs/development.md) | Setup, build commands, checking changes, the traps. |
| [docs/architecture.md](docs/architecture.md) | How the app is put together, file by file. |
| [docs/auth.md](docs/auth.md) | WordPress.com sign-in, and the approaches that don't work. |
| [docs/releasing.md](docs/releasing.md) | Shipping updates, the signing key, the website, testing an update. |
| [AGENTS.md](AGENTS.md) | Rules for coding agents (Claude Code reads it through `CLAUDE.md`). |

## Project layout

```
Package.swift          SwiftPM manifest: one executable target (DispatchApp) plus Sparkle
Info.plist             Bundle info, version, Sparkle feed URL and public key
build.sh               Builds, embeds and signs Dispatch.app (--install puts it in ~/Applications)
release.sh             Versions, builds, signs and publishes an update
Sources/DispatchApp/   The app (see docs/architecture.md)
site/                  The website and update feed, published to Spacefast
docs/                  Everything else worth knowing
```

| Source file | What it does |
|---|---|
| `main.swift`, `App.swift` | Plain AppKit entry point and startup. |
| `PanelController.swift` | Status item, attached panel, detached window, sizing, animations, keyboard. |
| `Views.swift` | All SwiftUI views. |
| `Store.swift` | Sign-in state, notifications, REST helper, session expiry. |
| `ReaderStore.swift` | Reader feeds, stars and saves, x-posts, comments. |
| `Reader.swift` | Reader HTML template, `WKWebView` wrapper, W logo. |
| `OAuth.swift` | WordPress.com sign-in over a localhost listener. |
| `Credentials.swift` | Data folder, token file, migration from the old name. |
| `Updates.swift` | Sparkle updater and version label. |
| `Screenshots.swift` | `DISPATCH_SCENE` staging for screenshots and checking the UI. |
