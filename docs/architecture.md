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

- **Attached panel.** A borderless, non-activating `NSPanel` hanging under the status item. The list (380pt) is centered under the icon, and the reader (`detailWidth`, 540pt to start; drag the divider between them to change it, `beginWidthResize`) grows out to its left. The window frame animates with `NSAnimationContext`. A global mouse-down monitor closes the panel on outside clicks. You drag the bottom edge to set the height, which is saved as `panelHeight`.
- **Detached window.** A titled `NSWindow` with a full-size content view and hidden traffic lights. You tear it off by dragging the header (`dragWindow`), or with the pop-out button. ⌘W or the close button puts it back in the menu bar.

Dispatch is an accessory app (no Dock icon, not in ⌘-Tab) while it's in the menu bar, and a regular app while it's a window, so the window shows up in the Dock, ⌘-Tab and Mission Control like any other (`updateDockIcon`). Two settings in the ⋯ menu and the app menu change that: **Show in Dock** (`showInDock`) keeps the Dock icon in menu bar mode too, and **Open as a Window** (`opensAsWindow`) detaches at launch (`applyLaunchMode`). A Dock click or ⌘-Tab with nothing showing calls `reopen()`, which brings back the window or opens the panel. `AppDelegate` builds the menu bar (Dispatch, Edit, Window), seen whenever Dispatch is a regular app.

Both homes share an `NSVisualEffectView` background with a stretchable rounded mask. `PanelController` also owns:
- the section (Notifications or Reader),
- the selection and `showDetail`,
- the comments drawer state (`commentsOpen`, and `commentsExpanded`, which folds the article away so the open thread takes the reader's full height; both stick while you move between posts),
- keyboard handling (`handleKey`), through a local `keyDown` monitor that returns `nil` for handled keys so there's no beep. `KeyboardHelp` (`?`, or ⋯ → Keyboard Shortcuts) lists them all; keep it in step:
  - **Lists:** `←`/`→` walk every list in one row, across sections (All, Unread, Following, Automattic, Saved, Later; `step`). `⇧←`/`⇧→`, `⌘1`–`⌘3` and `⇥`/`⇧⇥` jump between sections (⌘1–3 are also in the Go menu; ⇥ wraps around, ⇧arrows don't). `↑`/`↓` or `j`/`k` move within a list. `⌘↑` goes back to the top, unless the article has focus. `esc` backs out: a single site's feed, then the reader, then the panel.
  - **The open item:** `Space`/`⇧Space` page the article (`article`, the reader's web view). `l` likes, `s` saves, `m` opens Remind Me as a menu, `o` opens in the browser, `u` marks a notification unread (or read again; `Store.markUnread` sends WordPress.com a count of -1, as its own panel does). `⌘+`/`⌘−`/`⌘0` set the text size (`textZoom`; also in the View menu): the article's `pageZoom`, and list rows and comments through `ts(_:)`, which scales their font sizes. `c` toggles comments, `f` full height, `r` opens the composer (bumps `replyRequest`; a comment notification replies to its comment).
  - **Later:** `↑`/`↓` move a highlight (`laterHighlight`) rather than opening, `↩` or `o` opens, `⌫` is Done.
  - Keys pass through while typing a comment, and the article keeps its own scrolling keys when it has focus.

## Data

**`Store.swift`**
- Sign-in state and the generic `request(_:version:method:body:)` helper for `public-api.wordpress.com/rest/v1.x`.
- Notifications, polled every 120 seconds.
- Optimistic mark-as-read.
- The number beside the menu bar icon (`PanelController.menuBarCount`, ⋯ → Menu Bar Count): all unread, only mentions and replies, or nothing.
- Mention terms from `/me`, used to highlight mentions.
- Reader pages for notifications (`buildPage`): a comment, a reply or a comment mention gets `ReaderPage.commentPage`, which shows the post first (a three-line preview, with the whole post in a "Read the whole post" disclosure), then the comment it replies to (`parent`), then the comment itself, highlighted. A post mention shows the post; likes and follows show the notification with its likers.
- Session expiry: a 401 or `invalid_token` signs out and shows "Session expired". A 403 from a private P2 doesn't.

**`ReaderStore.swift`**
- Feeds: `.blogs` (`read/following`), `.p2s` (`read/a8c`), `.saved` (`read/saved`, paged by `page_handle`), and `.site(id, isFeed:)` (`read/sites/{id}/posts`, or `read/feed/{id}/posts` for RSS-only feeds).
- Each feed shows a story once (`oneCopyEach`). A post x-posted to several P2s you follow keeps the newest spot, and becomes the original post once that has loaded.
- Each feed is cached, with pagination through `before=`.
- Rows show the reading time, views, likes and comments. Following posts usually carry `views` ("19K"); for the rest (P2s, Saved) `loadViews` asks `sites/{id}/stats/post/{id}?fields=views` once per post and caches it in `viewCounts`, misses included.
- The response decoding is lenient because the API is inconsistent:
  - `site_ID` is sometimes a string.
  - `site_icon` is sometimes `[]`.
- X-posts are resolved from `xpost_origin` metadata. When you can't access the origin, the reader shows a fallback notice.
- Comments come from `sites/{site}/posts/{post}/replies` (100 a page by `offset`, up to 500), with `like_count` and `i_like`, and are ordered into threads. They're cached per post for an instant first look, but the drawer always fetches the thread again (`comments(fresh: true)`) and swaps in anything new: a cached thread can be far behind.
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
- Saves are WordPress.com's "Save to read later", shared with the web Reader and the Chrome extension (the mobile apps still save locally until they move over). `wpcom/v2/read/saved/keys` says what's saved, `…/new` and `…/delete` change it, and the Saved tab lists `rest/v1.2/read/saved`. A post is keyed by blog and post ID, an RSS post by its feed item ID, and an x-post by its original. These endpoints are undocumented and new, so check them if saves break. `toggleSave` flips the bookmark right away and puts it back if WordPress.com says no. The Saved list and keys are cached in `reader.json`, so the tab opens instantly and offline; the first launch after the switch uploads that file's older, local-only saves once (`uploaded` marks it done). There used to be a local "Starred sites" feature; it was removed because it was easy to mistake for likes. Old `starred` entries in the file are ignored.

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

## Images

Click an image in the reader (or a link straight to one) and it opens in macOS's Quick Look window, with the post's other images a ←/→ away. The page posts their URLs to the `image` script handler (`data-orig-file` first, then the largest `srcset` candidate); `ImagePreview` downloads them to a temporary folder (with the token on `*.wordpress.com`, as `MediaLoader` does), opens the clicked one as soon as it's in, and adds the rest as they arrive.

## Images on private sites

Private P2 images (`*.wordpress.com/wp-content/…`) return 403 without a signed-in session, and the reader's web view has no WordPress.com cookies. `MediaLoader.route` rewrites `src`/`srcset` URLs on `*.wordpress.com` to `wpn-media://…`, and `MediaLoader` (a `WKURLSchemeHandler`) fetches them over https with the app's token. The token is only ever sent to `*.wordpress.com`.

## Mac notifications and reminders: `Alerts.swift`, `Reminders.swift`

- **Banners.** After each notifications refresh, `Alerts.announce` posts a Mac notification for each unread notification newer than the last one it saw (`alertedThrough` in UserDefaults), so a launch never replays the backlog; five or more become one summary. The kinds are settings (⋯ → Notify Me About): mentions and comments on, likes and follows off.
- **Actions on the banner.** Comments and mentions get Reply (a text field; it posts a reply to the comment, or a comment on the post), Mark as Read and Remind Me in 1 Hour. Clicking a banner opens that notification (`PanelController.open(_:)`).
- **Reminders.** Remind Me (the alarm in the reader toolbar, or right-click on a row) offers in 1 hour, in 3 hours, this evening, tomorrow morning and next week. A `Reminder` keeps what it takes to reopen the item (the note's ID, or the whole `ReaderPost`) in `reminders.json`, and schedules a local notification for its time, so it arrives even if Dispatch isn't running. Its banner has Remind Me in 1 Hour and Done; clicking it opens the item and clears the reminder. Rows with a reminder show a clock.
- **Later.** A third section (`Section.later`, `LaterList`) lists every reminder, notifications and posts together, soonest first, with due ones marked; its tab's badge counts what's due. Clicking a row opens the item in its own section (`open(_:clear: false)`), so the reminder stays until you click Done (or reschedule it from the right-click menu).
- `UNUserNotificationCenter` can't exist outside an app bundle, so `Alerts` creates it lazily and never in demo mode.

## Rough edges, handled

- **Errors** in a list show as `ErrorBanner`: what happened in words (`friendly(_:)`: offline, timed out, couldn't reach WordPress.com) and Try Again. A post that hasn't loaded after 10 seconds offers Try Again and Open in Browser.
- **Comment drafts** are kept per thread (`ReaderStore.drafts`) when you move to another post or close the panel; the drawer's header says "Draft" while one waits.
- **Expired sign-ins** (they last about two weeks and can't renew) post a Mac notification, so Dispatch doesn't just go quiet.
- **Seen posts.** Reader rows show a dot until you've read them, from WordPress.com's `is_seen` (shared with the web Reader). Opening one marks it seen (`wpcom/v2/seen-posts/seen/blog/new`, or `seen-posts/seen/new` for RSS; `…/delete` undoes it with `u`). The API only accepts WordPress.com's own app names as `source`, so Dispatch sends `reader-web`.
- **First run.** `FirstRunTips` shows three cards once (`tipsSeen`): the keyboard, reminders, and `?`.
- **VoiceOver** reads each icon button's help text, not its symbol name.

## Hovercards: `Hovercards.swift`

- `.hovercard(edge:) { … }` on any view opens a card beside it after a ~0.5s hover (instantly when one is already open). The card lives in its own borderless, non-activating `NSPanel` that can't become key, so the list keeps keyboard focus and the card isn't clipped by the panel.
- Moving onto the card keeps it open; leaving both closes it after a short grace. Any key press and `hidePanel()` close it too.
- `PersonCard` loads the public Gravatar profile (`api.gravatar.com/v3/profiles/<hash>`, no auth). The hash comes from the avatar URL WordPress.com already gives us (`gravatarHash`). `SiteCard` loads `read/sites/{id}`. Both are cached in `ReaderStore`, including misses.
- In the article, elements with `data-person` post their rect to the `hovercard` script handler in `HTMLView`, and the card anchors to that rect inside the web view.
- Likes are stars (`LikeStar`): liking spins and pops the star with a burst of sparks, unliking squashes it. Only real toggles animate.

## Demo mode: `Demo.swift`

For the website's drift check. `DISPATCH_DEMO=<site/demo-data.json>` makes `Store.request` answer from `DemoAPI`, which turns the website's made-up data into WordPress.com-shaped responses, so the app's real decoding and views run on it. App data (sign-in, saves) goes to a temporary folder, and Sparkle is off. `DISPATCH_RENDER=<folder>` also skips the status item, draws each scene in `Demo.scenes` into an offscreen window, and writes `<scene>.png` plus `<scene>.json`, the frames of every `.driftTag`. `driftTag` and `driftScope` do nothing in a normal run.

## Sign-in and updates

- **Sign-in:** an implicit-grant OAuth flow over a localhost listener. See [auth.md](auth.md).
- **Updates:** `Updates.swift` wraps `SPUStandardUpdaterController`. The feed URL and public key are in `Info.plist`. See [releasing.md](releasing.md).
