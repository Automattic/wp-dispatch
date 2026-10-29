# Architecture

Dispatch is one AppKit process with a SwiftUI interface. It has about 2,800 lines of Swift in `Sources/DispatchApp/` and no dependencies besides Sparkle.

## Startup

`main.swift` creates `AppDelegate` with the `.accessory` activation policy. At launch, `AppDelegate`:

1. runs `AppData.migrateFromOldName()`, which carries over data from the old "WP Notifications" build,
2. creates `PanelController(store: Store())`,
3. starts `Updates.shared` (Sparkle),
4. runs `Screenshots.stage`, which does nothing unless `DISPATCH_SCENE` is set.

## Windows: `PanelController.swift`

The interface lives in one `NSHostingView` (`sizingOptions = []`) that moves between two homes:

- **Attached panel.** A borderless, non-activating `NSPanel` hanging under the status item. The list (380pt) is centered under the icon, and the reader (540pt) grows out to its left. The window frame animates with `NSAnimationContext`. A global mouse-down monitor closes the panel on outside clicks. You drag the bottom edge to set the height, which is saved as `panelHeight`.
- **Detached window.** A titled `NSWindow` with a full-size content view and hidden traffic lights. You tear it off by dragging the header (`dragWindow`), or with the pop-out button. ⌘W or the close button puts it back in the menu bar.

Both homes share an `NSVisualEffectView` background with a stretchable rounded mask. `PanelController` also owns:
- the section (Notifications or Reader),
- the selection and `showDetail`,
- the comments drawer state,
- keyboard handling, through a local `keyDown` monitor that returns `nil` for handled keys so there's no beep:
  - `↑`/`↓`, `j`/`k`: move the selection
  - `o`: open in the browser
  - `s`: save the post
  - `esc`: close the reader or the panel
  - `⌘W`: put the detached window back in the menu bar

## Data

**`Store.swift`**
- Sign-in state and the generic `request(_:version:method:body:)` helper for `public-api.wordpress.com/rest/v1.x`.
- Notifications, polled every 120 seconds.
- Optimistic mark-as-read.
- Mention terms from `/me`, used to highlight mentions.
- Session expiry: a 401 or `invalid_token` signs out and shows "Session expired". A 403 from a private P2 doesn't.

**`ReaderStore.swift`**
- Feeds: `.blogs` (`read/following`), `.p2s` (`read/a8c`), `.starred` (merged per-site streams), `.saved` (local), and `.site(id, isFeed:)` (`read/sites/{id}/posts`, or `read/feed/{id}/posts` for RSS-only feeds).
- Each feed is cached, with pagination through `before=`.
- The response decoding is lenient because the API is inconsistent:
  - `site_ID` is sometimes a string.
  - `site_icon` is sometimes `[]`.
- X-posts are resolved from `xpost_origin` metadata. When you can't access the origin, the reader shows a fallback notice.
- Comments come from `sites/{site}/posts/{post}/replies`, with `like_count` and `i_like`, and are ordered into threads.
- Writing:
  - `setLike` posts to `comments/{id}/likes/new` or `likes/mine/delete`.
  - `postComment` posts to `posts/{post}/replies/new` for a comment on the post, or `comments/{id}/replies/new` for a reply.
- `Store.request` throws `APIError` when a write (non-GET) fails. Reads still fail quietly.
- Stars and saves persist to `reader.json`.

**`Credentials.swift`** stores the token as a JSON file and defines `AppData.directory`.

## Views

**`Views.swift`**
- `RootView` lays out the reader and list side by side, trailing-aligned and clipped, so the reader slides out from behind the list.
- `ListPane` has two rows: the section tabs plus chrome buttons, then the filters.
- Notification rows, post rows and compact `XPostRow`s.
- `DetailPane`: a toolbar, the web content, and the comments drawer.
- The comments drawer shows Like and Reply under each comment in the open list. A comment box at the bottom sends with ⌘↩, and a "+" bubble at the end of the strip opens it. While the box has focus, the panel's keyboard shortcuts are off.
- The comments drawer has two states that morph into each other with `matchedGeometryEffect`:
  - Closed: a horizontal strip of avatars and chat bubbles. The mouse wheel scrolls it sideways.
  - Open: a threaded list.
- `SetupView` is the screen shown before you connect.

**`Reader.swift`**
- `ReaderPage.html(...)` renders posts and notes into one HTML template, with reading time and mention highlighting.
- `HTMLView` is the `WKWebView` wrapper. It catches `wpn://site/<id>` links, which open a site's feed in the list, and sends every other link to the browser.
- The W logo is rendered as a template image.

## Sign-in and updates

- **Sign-in:** an implicit-grant OAuth flow over a localhost listener. See [auth.md](auth.md).
- **Updates:** `Updates.swift` wraps `SPUStandardUpdaterController`. The feed URL and public key are in `Info.plist`. See [releasing.md](releasing.md).
