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
   git add Info.plist site/appcast.xml site/_redirects site/releases/*.html
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

`site/index.html` is one hand-written page with a download button, an interactive demo, the features and the install steps.

**The demo** (`sim.js` and `sim.css`) is a working HTML copy of the panel, filled with made-up content:
- Visitors can click and use `j`, `k`, `l`, `s`, `o` and `esc`.
- A guided tour drives the same UI with a pretend cursor. Each feature in the list plays its own chapter.
- Phone-width screens get a camera that follows the list or the reader.
- Real clicks pause the tour.
- It can be driven from code through `window.DispatchSim`: `play()`, `pause()`, `chapter(name)`, and `do.*` for individual actions. See the header comment in `sim.js`.

When the app gains or changes a visible feature, update the demo data, its actions and the tour.

**Cache busting:** `index.html` loads `sim.css?v=…` and `sim.js?v=…`. After editing either file, bump the number. `release.sh` sets it to the build number. To update the site without a release:

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
