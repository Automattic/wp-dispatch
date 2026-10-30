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
  - `←`/`→`: switch Reader tabs (Following, Automattic, Saved); not in a single site's feed
  - `⌘↑`: scroll the list back to the top, unless the article has focus (then the article scrolls). The ↑ button beside the filters does the same, and shows once the list has scrolled (`ListTop` reports it).
  - `o`: open in the browser
  - `s`: save the post
  - `l`: like the post
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
- Feeds: `.blogs` (`read/following`), `.p2s` (`read/a8c`), `.saved` (local), and `.site(id, isFeed:)` (`read/sites/{id}/posts`, or `read/feed/{id}/posts` for RSS-only feeds).
- Each feed shows a story once (`oneCopyEach`). A post x-posted to several P2s you follow keeps the newest spot, and becomes the original post once that has loaded.
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
- Post likes are real WordPress.com likes:
  - `toggleLike` posts to `sites/{site}/posts/{post}/likes/new` or `likes/mine/delete`.
  - The feeds carry `like_count` and `i_like`. Both are loose types, so they're decoded leniently.
  - `likes` holds what's changed since a feed loaded.
  - X-posts like the original post and fetch its count on open.
  - RSS-only posts can't be liked.
- Saved posts persist to `reader.json`. There used to be a local "Starred sites" feature; it was removed because it was easy to mistake for likes. Old `starred` entries in the file are ignored.

**`Credentials.swift`** stores the token as a JSON file and defines `AppData.directory`.

## Views

**`Views.swift`**
- `RootView` lays out the reader and list side by side, trailing-aligned and clipped, so the reader slides out from behind the list.
- `ListPane` has two rows: the section tabs plus chrome buttons, then the filters.
- Notification rows, post rows and compact `XPostRow`s.
- `DetailPane`: a toolbar, the web content, and the comments drawer.
- The comments drawer shows Like and Reply under each comment in the open list. A comment box at the bottom sends with ⌘↩, and a "+" bubble at the end of the strip opens it. While the box has focus, the panel's keyboard shortcuts are off.
- The drawer is one view for the whole reading session. Moving to another post swaps its thread in place (`.task(id:)`), so it only slides up and pops its bubbles in the first time. `ReaderStore.prefetch` also loads the next post's comments, so `j` usually swaps instantly.
- The comments drawer has two states that morph into each other with `matchedGeometryEffect`:
  - Closed: a horizontal strip of avatars and chat bubbles. The mouse wheel scrolls it sideways.
  - Open: a threaded list.
- `SetupView` is the screen shown before you connect.

**`Reader.swift`**
- `ReaderPage.html(...)` renders posts and notes into one HTML template, with reading time and mention highlighting.
- `HTMLView` is the `WKWebView` wrapper. It catches `wpn://site/<id>` links, which open a site's feed in the list, and sends every other link to the browser.
- The W logo is rendered as a template image.

## Images on private sites

Private P2 images (`*.wordpress.com/wp-content/…`) return 403 without a signed-in session, and the reader's web view has no WordPress.com cookies. `MediaLoader.route` rewrites `src`/`srcset` URLs on `*.wordpress.com` to `wpn-media://…`, and `MediaLoader` (a `WKURLSchemeHandler`) fetches them over https with the app's token. The token is only ever sent to `*.wordpress.com`.

## Hovercards: `Hovercards.swift`

- `.hovercard(edge:) { … }` on any view opens a card beside it after a ~0.5s hover (instantly when one is already open). The card lives in its own borderless, non-activating `NSPanel` that can't become key, so the list keeps keyboard focus and the card isn't clipped by the panel.
- Moving onto the card keeps it open; leaving both closes it after a short grace. Any key press and `hidePanel()` close it too.
- `PersonCard` loads the public Gravatar profile (`api.gravatar.com/v3/profiles/<hash>`, no auth). The hash comes from the avatar URL WordPress.com already gives us (`gravatarHash`). `SiteCard` loads `read/sites/{id}`. Both are cached in `ReaderStore`, including misses.
- In the article, elements with `data-person` post their rect to the `hovercard` script handler in `HTMLView`, and the card anchors to that rect inside the web view.
- Likes are stars (`LikeStar`): liking spins and pops the star with a burst of sparks, unliking squashes it. Only real toggles animate.

## Sign-in and updates

- **Sign-in:** an implicit-grant OAuth flow over a localhost listener. See [auth.md](auth.md).
- **Updates:** `Updates.swift` wraps `SPUStandardUpdaterController`. The feed URL and public key are in `Info.plist`. See [releasing.md](releasing.md).
