# Development

Everything you need to build, run, change and check Dispatch on your own Mac.

## Setup

1. macOS 14 or later, with Xcode or the Command Line Tools installed (Swift 5.10 or later).
2. Clone the repo:
   ```bash
   git clone https://github.com/shaunandrews/dispatch-for-wordpress-com.git
   ```
3. Build and install it:
   ```bash
   ./build.sh --install
   ```
   The first build fetches Sparkle through SwiftPM.
4. Run it:
   ```bash
   open ~/Applications/Dispatch.app
   ```
5. Click the W in the menu bar, then **Connect** to sign in.

There's no Xcode project. It's a SwiftPM executable (`Package.swift`) that `build.sh` wraps into an app bundle.

## Build commands

| Command | What it does |
|---|---|
| `swift build` | Compile only, to check for errors fast. |
| `./build.sh` | Universal (Apple silicon and Intel) release build into `build/Dispatch.app`, with Sparkle embedded and signed. |
| `./build.sh --install` | The same, then moves it into `~/Applications` and registers it with LaunchServices. A running copy keeps the old build until it restarts: use ⋯ → **Restart**. |
| `SIGN_IDENTITY="Developer ID Application: …" ./build.sh` | Signs with a real certificate and the hardened runtime instead of ad-hoc. |

After installing, restart the running copy. Find its exact PID first and kill only that PID, never a name pattern (`pkill -f Dispatch` could hit other apps):

```bash
pgrep -fl "Dispatch.app/Contents/MacOS/Dispatch"
```

```bash
kill <pid>; open ~/Applications/Dispatch.app
```

## Things that will trip you up

- **The Swift module is `DispatchApp`, not `Dispatch`.** `Dispatch` is Apple's GCD module, and a target with that name causes a dependency cycle. The executable is renamed to `Dispatch` inside the bundle.
- **The app is ad-hoc signed.** Every rebuild changes its code identity, so anything stored in the Keychain prompts for a password after each build. That's why the sign-in token is in a 0600 file (`Credentials.swift`) instead.
- **It's an accessory app.** `LSUIElement` is set, so it has no Dock icon or menu bar menus. Its status item isn't reachable through System Events or computer-use tools.
- **No SwiftUI `App`.** `main.swift` starts AppKit directly. A SwiftUI `App` needs a scene, and the `Settings` scene opens an empty window.
- **Warnings about the Swift 6 language mode are expected.** The package builds in Swift 5 mode, and those warnings don't block the build.
- **SwiftUI layout gotcha.** When content is wider than the window, `.frame(maxWidth: .infinity, alignment:)` grows to fit the content, and the window then centers it. Use `minWidth: 0` to keep the frame at the window's width. See the comment in `RootView`.
- **Don't sign Sparkle with `--deep`.** `build.sh` signs its XPC services, `Autoupdate`, `Updater.app`, the framework and then the app, in that order.

## Data on disk

| Where | What |
|---|---|
| `~/Library/Application Support/Dispatch/credentials.json` | Sign-in token and its expiry (0600). |
| `~/Library/Application Support/Dispatch/reader.json` | Saved posts. |
| `defaults read com.shaunandrews.dispatch` | Panel height, window frame, last section, the Unread filter, Sparkle's state (`SU*`). |

To sign out completely, use ⋯ → **Sign out**, or delete `credentials.json`. Never print the token in logs or chat.

## Checking your change

- **Logic or API:** run the app and use it. The API calls are in `Store.swift` and `ReaderStore.swift`, and there are no unit tests.
- **Layout:** stage the panel and capture its window. This doesn't need anyone to click.
  ```bash
  DISPATCH_SCENE=post ~/Applications/Dispatch.app/Contents/MacOS/Dispatch &
  ```
  `reader` opens the Reader's Following feed, `post` also opens its first post, and `comments` also opens its comments drawer. See `Screenshots.swift`. Then capture the window by its ID (find it with `CGWindowListCopyWindowInfo`, owner name "Dispatch"):
  ```bash
  screencapture -l<windowID> -x shot.png
  ```
  Afterwards, restart the app normally.
- **The website demo:** `./tools/drift/check.sh` renders the app in demo mode and compares it with `site/sim.js`. See "The drift check" in [releasing.md](releasing.md).
- **Sign-in:** sign out, then Connect. The flow and its constraints are in [auth.md](auth.md).
- **Updates:** see "Testing an update" in [releasing.md](releasing.md).

## Committing

- Branch: `trunk`. Remote: `shaunandrews/dispatch-for-wordpress-com`, which is private.
- Never commit `build/`, `.build/`, release zips or deltas, or `site/.spacefast/state.json`. All of these are in `.gitignore`.
- Screenshots for PRs or issues don't belong in the repo: upload those through GitHub.
