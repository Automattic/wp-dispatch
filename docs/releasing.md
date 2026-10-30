# Releasing

Dispatch ships as a zip on its website and updates itself with [Sparkle](https://sparkle-project.org) 2.10.0.

## The moving parts

| Piece | Where |
|---|---|
| Website, downloads, update feed | Spacefast Space `dispatchapp`, id `spc_6f81e0c2ca994ef597cc94eb55f421d5`, in team **Shaun's Team** (`shaun-team`). It's public at https://dispatchapp.space.fast. |
| Site source | `site/`: `index.html`, the interactive demo (`sim.js` and `sim.css`), `appcast.xml`, `_redirects` and `releases/`. |
| Update feed | `https://dispatchapp.space.fast/appcast.xml`, set as `SUFeedURL` in `Info.plist`. It's generated, so don't edit it by hand. |
| Download button | `/download`, a 302 redirect in `site/_redirects` that `release.sh` rewrites for each release. |
| Release zips and deltas | `site/releases/`. They're gitignored and published with the site. The appcast keeps 5 versions. |
| Update signing key | EdDSA private key in the login Keychain, under the account `dispatch`. The public key is `SUPublicEDKey` in `Info.plist`. |
| Sparkle tools | `.build/artifacts/sparkle/Sparkle/bin/` (`generate_keys`, `generate_appcast`, `sign_update`), available after the first build. |

## Ship an update

1. Commit your change and make sure it runs:
   ```bash
   ./build.sh --install
   ```
2. Optionally, write release notes in `site/releases/Dispatch-<version>.html`, for example `<h2>Dispatch 0.2.0</h2><ul><li>…</li></ul>`. Sparkle shows them in the update window.
3. Release:
   ```bash
   ./release.sh 0.2.0
   ```
   The script:
   - checks the signing key,
   - downloads the current release's zip if it's missing,
   - bumps `CFBundleShortVersionString` and `CFBundleVersion` (+1),
   - builds, zips and signs the app,
   - regenerates `appcast.xml`, including a delta from the previous build,
   - rewrites `/download`,
   - publishes `site/` to the Space.

   The first run on a Mac may show a Keychain prompt for `generate_appcast`. Click **Always Allow**.
4. Check that it's live:
   ```bash
   curl -s https://dispatchapp.space.fast/appcast.xml | grep shortVersionString
   ```
   ```bash
   curl -sI https://dispatchapp.space.fast/download | grep -i location
   ```
5. Commit what the release changed and push:
   ```bash
   git add Info.plist site/appcast.xml site/_redirects site/index.html site/sim.js site/releases/*.html
   ```
   ```bash
   git commit -m "Release 0.2.0"
   ```
   ```bash
   git push
   ```

Use `./release.sh 0.2.0 --no-publish` to do everything except publishing. If the build fails partway through, `Info.plist` stays bumped, so fix the problem and run the same command again. The build number keeps counting up, which is harmless.

Versions use `MAJOR.MINOR.PATCH`. Sparkle decides what's newer by `CFBundleVersion` (the build number), so never lower it or reuse one.

## Releasing from another Mac or a fresh clone

1. **The signing key.** Export it on a Mac that has it, then import it on the new one. The file is a secret, so never commit or share it, and delete it after importing.
   ```bash
   .build/artifacts/sparkle/Sparkle/bin/generate_keys --account dispatch -x dispatch-sparkle.key
   ```
   ```bash
   .build/artifacts/sparkle/Sparkle/bin/generate_keys --account dispatch -f dispatch-sparkle.key
   ```
   If the key is lost for good, current installs can't verify new updates. Everyone would have to download a new build by hand, and that build would need a new key in `SUPublicEDKey`. Keep a backup in a password manager.
2. **Spacefast.** Run `sf login` with an account that's a member of Shaun's Team. `release.sh` always publishes to the Space ID above (`site/.spacefast/space.json` names the same Space, `dispatchapp`), so it can't accidentally create a new Space.
3. **Previous zips.** `release.sh` downloads the current release's zip if `site/releases/` doesn't have it. Older zips aren't needed.

## Testing an update

To check that installed copies really update:

1. Install the current release from its zip:
   ```bash
   ditto -x -k site/releases/Dispatch-<old>.zip ~/Applications/
   ```
   Then launch it.
2. Release a new version.
3. Make Sparkle check right away and install when the app quits:
   ```bash
   defaults write com.shaunandrews.dispatch SULastCheckTime -date "2020-01-01 00:00:00 +0000"
   ```
   ```bash
   defaults write com.shaunandrews.dispatch SUAutomaticallyUpdate -bool true
   ```
4. Restart the app, wait about 20 seconds, then quit it normally:
   ```bash
   osascript -e 'tell application id "com.shaunandrews.dispatch" to quit'
   ```
5. Check the installed version:
   ```bash
   defaults read ~/Applications/Dispatch.app/Contents/Info.plist CFBundleShortVersionString
   ```
6. Undo the test setting:
   ```bash
   defaults delete com.shaunandrews.dispatch SUAutomaticallyUpdate
   ```

The 0.1.0 → 0.1.1 test on 2026-10-28 passed. It installed a 1.3 KB delta, the signature stayed valid, and macOS didn't flag the app as downloaded.

## Website

`site/index.html` is one hand-written page: a download button, then one row per benefit (copy on one side, a live demo on the other, alternating), then the install steps. Lead each row with what it does for people, and the feature second.

**The demo** (`sim.js` and `sim.css`) is a working HTML copy of the panel, filled with made-up content:
- Visitors can click and use `j`, `k`, `←`, `→`, `l`, `s`, `o` and `esc`.
- Every `[data-dispatch-sim]` element is its own stage with its own made-up data. Its value names the tour chapter it plays, for example `data-dispatch-sim="comments"`.
- A stage plays its chapter on a loop with a pretend cursor while it's on screen, and rests when it scrolls away.
- The demo can also pop out into a window (`detach`/`attach`/`closeWindow`), which puts Dispatch in the desk's Dock, and show a ⌘-Tab switcher (`switcher`), for the Window row.
- Use motion only where it shows something a still can't. A stage with `data-sim-still="<scene>"` skips the tour and shows one scene (see `SCENES` in `sim.js`) that visitors can click around in. Notifications and P2s are stills.
- Copy the app exactly: sizes, weights and colors from the SwiftUI views, and reader pages built the way `Store.buildPage` and `ReaderStore.page` build them. The drift check (below) holds the layout to that.
- The made-up people, sites, posts and notifications live in `site/demo-data.json`. The app's demo mode reads the same file.
- Hovering a made-up person or site opens a hovercard, as in the app.
- The page's columns frame the whole screen: a close-up on the menu bar and list, and when the reader opens the camera pulls back to show the full panel, menu bar and Dock. Phone-width stages are too narrow for that wide shot, so their camera follows the list or the reader instead.
- A real click or key hands that stage to the visitor until they press its play button.
- It can be driven from code through `window.DispatchSims` (one per stage; `window.DispatchSim` is the first): `play()`, `pause()`, `chapter(name)`, and `do.*` for individual actions. See the header comment in `sim.js`.

When the app gains or changes a visible feature, update the demo data, its actions and the tour, and give it a row if it's worth one.

### The drift check

`./tools/drift/check.sh` checks that the demo still matches the app, and `release.sh` runs it first and won't ship if it fails:

1. It renders the real app's views from `site/demo-data.json` in demo mode, offscreen (see `Demo.swift`). No network, no menu bar item, no window on screen, and nothing touches the installed app or its data.
2. It renders the same scenes of the website demo in headless Chromium (`tools/drift/measure.mjs`, using `tools/drift/stage.html`).
3. It compares where every tagged part landed (`tools/drift/compare.mjs`): within 1.5pt for layout, with a little more slack for text widths. The report, with both renders side by side and the differences outlined, is `build/drift/report.html`.

Parts are tagged with `.driftTag("name")` in the SwiftUI views and `data-drift="name"` in `sim.js`, using the same names. Rows are scoped by position (`row.0.title`). The scenes are `Demo.scenes` in `Demo.swift` and `SCENES` in `sim.js`; keep the two lists in step. When you add a visible part to the app, tag it on both sides.

It measures positions and sizes, not colors or the reader's article text, so still look at the report's renders. It needs Playwright: it uses `~/.cache/pr-screenshots` if that has it, or run `npm install` and `npx playwright install chromium-headless-shell` in `tools/drift` once.

**Cache busting:** `index.html` loads `sim.css?v=…` and `sim.js?v=…`, where the value is the file's content hash. After editing either file, run `./bust-site.sh`. `release.sh` runs it too, after setting `VERSION` in `sim.js` (shown in the demo's ⋯ menu) to the release. To update the site without a release:

```bash
cd site && sf publish --space spc_6f81e0c2ca994ef597cc94eb55f421d5 --yes --wait
```

To preview it locally, run any static server on `site/`, for example `python3 -m http.server -d site`. The `_redirects` file only works on Spacefast.

Never put real notifications, P2 content or anything internal to Automattic on the site. The demo's people and blogs are made up.

## Not done yet

- **Developer ID signing and notarization.** Builds are ad-hoc signed, so a first install from the website shows macOS's "can't verify" warning, and the user has to click System Settings → Privacy & Security → **Open Anyway**. Sparkle updates after that don't hit the warning. To fix it:
  1. Get a Developer ID Application certificate.
  2. Build with `SIGN_IDENTITY="Developer ID Application: …" ./build.sh`.
  3. Add `xcrun notarytool submit … --wait` and `xcrun stapler staple` to `release.sh`, between building and zipping.
  4. Remove the "Open Anyway" step from the site.
- **Automattic-owned OAuth client.** The app signs in with Shaun's WordPress.com app, 151672. See [auth.md](auth.md).
