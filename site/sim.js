/* Dispatch simulation for the website.
 *
 * A working copy of the app's menu bar panel, filled with made-up people, blogs and P2s.
 * Every [data-dispatch-sim] element becomes its own stage. Its value names the tour chapters
 * it plays (all of them when empty), on a loop while it's on screen. Visitors can click and
 * use j/k/esc/s/o; a real click or key hands the stage over until Play is pressed again.
 * The stage's caption and Play button are found inside its [data-sim-row]. A stage with
 * data-sim-still="<scene>" skips the tour: it shows that scene and waits for clicks.
 *
 * Programmatic control lives on window.DispatchSims (one per stage; DispatchSim is the first):
 *   DispatchSim.play()               start (or restart) the tour
 *   DispatchSim.pause()
 *   DispatchSim.chapter("comments")  play one chapter: notifications, read, remind, keys, reader, saved, cards, xposts, comments, window
 *   DispatchSim.do.section("reader"), .feed("p2s"), .site("kettle"), .select("waits"), .move(1), .comments(), .likePost(), …
 */
(() => {
  const roots = document.querySelectorAll("[data-dispatch-sim]");
  if (!roots.length) return;
  const ICON = new URL("icon.png", document.currentScript.src).href; // the app icon, for the Dock and ⌘-Tab
  fetch(new URL("demo-data.json", document.currentScript.src))
    .then((r) => r.json())
    .then((data) => roots.forEach((root) => mount(root, data)));

  // One stage. Everything below, made-up data included, is per stage, so stages don't share likes or replies.
  function mount(root, data) {
    // ---------------------------------------------------------------- icons
    const svg = (d, w = 1.5) =>
      `<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
    const I = {
      w: `<svg viewBox="0 0 20 20" fill="currentColor"><path d="M10 1.2a8.8 8.8 0 1 0 0 17.6 8.8 8.8 0 0 0 0-17.6Zm-7.6 8.8c0-1.1.2-2.1.6-3.1l3.6 9.9A7.6 7.6 0 0 1 2.4 10Zm7.6 7.6c-.7 0-1.5-.1-2.1-.3l2.3-6.6 2.3 6.4.1.1c-.8.3-1.7.4-2.6.4Zm1-11.2c.5 0 .9-.1.9-.1.4 0 .4-.7 0-.7 0 0-1.2.1-2 .1-.8 0-2-.1-2-.1-.4 0-.5.7 0 .7l.8.1 1.2 3.2-1.7 5-2.8-8.2.9-.1c.4 0 .4-.7 0-.7 0 0-1.2.1-2 .1h-.5A7.6 7.6 0 0 1 15.3 4.6h-.1c-.8 0-1.3.7-1.3 1.4 0 .6.4 1.2.8 1.8.3.5.6 1.2.6 2.2 0 .7-.3 1.5-.6 2.6l-.8 2.7-2.9-8.9Zm2.8 10.2 2.3-6.7c.4-1.1.6-2 .6-2.7l-.1-.8a7.6 7.6 0 0 1-2.8 10.2Z"/></svg>`,
      refresh: svg(`<path d="M13.5 8a5.5 5.5 0 1 1-1.6-3.9M13.5 2.5v3h-3"/>`),
    signal: `<svg viewBox="0 0 11 9" fill="currentColor" class="bars"><rect x="0" y="5.76" width="1.6" height="3.24" rx=".8"/><rect x="3" y="3.87" width="1.6" height="5.13" rx=".8"/><rect x="6" y="1.89" width="1.6" height="7.11" rx=".8"/><rect x="9" y="0" width="1.6" height="9" rx=".8"/></svg>`, // SignalBars in Views.swift
    expand: svg(`<path d="M9.5 2.5h4v4M13.5 2.5 9 7M6.5 13.5h-4v-4M2.5 13.5 7 9"/>`),
    collapse: svg(`<path d="M13.5 6.5h-4v-4M9.5 6.5l4.5-4.5M2.5 9.5h4v4M6.5 9.5 2 14"/>`),
    alarm: svg(`<circle cx="8" cy="9" r="5.2"/><path d="M8 6.4V9l1.8 1.3M2.6 3.6l2-1.6M13.4 3.6l-2-1.6"/>`),
    alarmFill: `<svg viewBox="0 0 16 16" fill="currentColor"><circle cx="8" cy="9" r="5.8"/><path d="M8 6.2V9l1.9 1.4" stroke="#fff" stroke-width="1.5" fill="none" stroke-linecap="round"/><path d="M2.6 3.6l2-1.6M13.4 3.6l-2-1.6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>`,
    putBack: svg(`<rect x="1.5" y="1.5" width="13" height="13" rx="2.5"/><path d="M1.5 4.8h13M8 12V7.4M5.8 9.4 8 7.2l2.2 2.2"/>`),
    popout: svg(`<rect x="1.5" y="3.5" width="10" height="8" rx="1.5"/><path d="M4.5 1.5h8a2 2 0 0 1 2 2v6"/>`),
      more: `<svg viewBox="0 0 16 16" fill="currentColor"><circle cx="3" cy="8" r="1.3"/><circle cx="8" cy="8" r="1.3"/><circle cx="13" cy="8" r="1.3"/></svg>`,
      x: svg(`<path d="M4 4l8 8M12 4l-8 8"/>`),
      mark: svg(`<path d="M4 1.8h8v12.4l-4-2.8-4 2.8z"/>`),
      markFill: `<svg viewBox="0 0 16 16" fill="currentColor"><path d="M4 1.8h8v12.4l-4-2.8-4 2.8z"/></svg>`,
      safari: svg(`<circle cx="8" cy="8" r="6.3"/><path d="M10.6 5.4 9 9 5.4 10.6 7 7z"/>`),
      up: svg(`<path d="M4 10l4-4 4 4"/>`),
      down: svg(`<path d="M4 6l4 4 4-4"/>`),
      bubbles: `<svg class="bub" viewBox="0 0 16 16" fill="currentColor"><path d="M2 3.5A2.5 2.5 0 0 1 4.5 1h5A2.5 2.5 0 0 1 12 3.5v3A2.5 2.5 0 0 1 9.5 9H6l-3 2.3V8.6A2.5 2.5 0 0 1 2 6.5z"/><path opacity=".55" d="M13 5v2.5A3.5 3.5 0 0 1 9.5 11H7.4c.4.6 1.2 1 2.1 1H12l2.5 2v-2.3A2 2 0 0 0 15 10.5V7a2 2 0 0 0-2-2z"/></svg>`,
      chev: `<svg class="chev" viewBox="0 0 10 10" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M2 6.5 5 3.5l3 3"/></svg>`,
      star: svg(`<path stroke-linejoin="round" d="M8 1.4l1.95 4.06 4.45.57-3.27 3.08.84 4.41L8 11.4l-3.97 2.12.84-4.41L1.6 6.03l4.45-.57z"/>`),
      starFill: `<svg viewBox="0 0 16 16" fill="currentColor" stroke="currentColor" stroke-linejoin="round"><path d="M8 1.4l1.95 4.06 4.45.57-3.27 3.08.84 4.41L8 11.4l-3.97 2.12.84-4.41L1.6 6.03l4.45-.57z"/></svg>`,
      comment: svg(`<path stroke-linejoin="round" d="M2.5 4.2a2 2 0 0 1 2-2h7a2 2 0 0 1 2 2v4.6a2 2 0 0 1-2 2H7.2l-3.2 2.6v-2.6h.5a2 2 0 0 1-2-2z"/>`),
      plus: svg(`<path d="M3 3.5A2.5 2.5 0 0 1 5.5 1h5A2.5 2.5 0 0 1 13 3.5v4A2.5 2.5 0 0 1 10.5 10H7l-3 2.5V10A2.5 2.5 0 0 1 3 7.5zM8 3.8v3.4M6.3 5.5h3.4"/>`),
      send: `<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="12" fill="currentColor"/><path d="M12 17V7.5M7.8 11.5 12 7.3l4.2 4.2" stroke="#fff" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
      xpost: svg(`<path d="M3 3v5a2 2 0 0 0 2 2h8M10 7l3 3-3 3"/>`, 2.6),
      check: svg(`<circle cx="8" cy="8" r="6.3"/><path d="M5.3 8.2l1.8 1.8 3.6-3.9"/>`),
      back: svg(`<path d="M10 3.5 5.5 8l4.5 4.5"/>`, 2),
      pin: svg(`<path d="M8 14.5s4.5-4.2 4.5-8a4.5 4.5 0 0 0-9 0c0 3.8 4.5 8 4.5 8z"/><circle cx="8" cy="6.5" r="1.6"/>`),
      kind: {
        comment: `<svg viewBox="0 0 16 16" fill="currentColor"><path d="M2 4.2A2.7 2.7 0 0 1 4.7 1.5h6.6A2.7 2.7 0 0 1 14 4.2v4.6a2.7 2.7 0 0 1-2.7 2.7H7.4L4 14.5v-3A2.7 2.7 0 0 1 2 8.8z"/></svg>`,
        mention: `<b>@</b>`,
        like: `<svg viewBox="0 0 16 16" fill="currentColor"><path d="M8 .9l2.2 4.5 5 .7-3.6 3.5.9 4.9L8 12.2l-4.5 2.3.9-4.9L.8 6.1l5-.7z"/></svg>`,
        follow: `<svg viewBox="0 0 16 16" fill="currentColor"><circle cx="8" cy="4.6" r="3.3"/><path d="M1.5 15c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6z"/></svg>`,
      },
      cursor: `<svg viewBox="0 0 18 24"><path d="M1.5 1.5v17.2l4.4-4.1 2.9 6.6 2.9-1.3-2.8-6.4h6.2z" fill="#111" stroke="#fff" stroke-width="1.4" stroke-linejoin="round"/></svg>`,
    };

    const VERSION = "0.6.0"; // release.sh keeps this in step with the app
    const DESK_H = 690; // the desk (wallpaper, menu bar, panel and Dock) is 1000 wide; match .sim in sim.css

    // ---------------------------------------------------------------- made-up data
    // From demo-data.json, which the app's demo mode reads too (see tools/drift). Copied per stage.
    const D = structuredClone(data);
    const ME = D.me;
    const P = Object.fromEntries(Object.entries(D.people).map(([k, v]) => [k, [v.name, v.color]]));
    const CARD = D.people, S = D.sites, POSTS = D.posts, NOTES = D.notes, FEEDS = D.feeds;
    Object.values(POSTS).forEach((p) => { p.liked = false; p.comments.forEach((cm) => { cm.liked = false; }); });
    const c = (id, who, text, ago, likes = 0, depth = 0) => ({ id, who, text, ago, likes, liked: false, depth });

    // ---------------------------------------------------------------- state
    const st = {
      open: true, section: "notifications", filter: "all", feed: "blogs",
      sel: null, commentsOpen: false, replyTo: null, draft: "", typing: false,
      site: null, // the Reader showing one site's posts (from a hovercard, or a post's site name)
      menu: false, saved: new Set(), read: new Set(), unreadAgain: new Set(), seenPosts: new Set(), unseenAgain: new Set(), reminders: {}, // reminders: item key → "Tomorrow at 9:00 AM"
    };
    const items = () => {
      if (st.section === "notifications") return NOTES.filter((n) => st.filter === "all" || isUnread(n));
      if (st.section === "later") return laterKeys();
      if (st.site) return Object.keys(POSTS).filter((k) => POSTS[k].site === st.site && !POSTS[k].xpost);
      if (st.feed === "saved") return [...st.saved].reverse(); // newest save first, like WordPress.com
      return FEEDS[st.feed];
    };
    const postFor = (item) => (st.section === "notifications" ? POSTS[item.post] : POSTS[item]);
    const keyOf = (item) => (typeof item === "string" ? item : item.id);

    // ---------------------------------------------------------------- markup
    const esc = (s) => s.replace(/[&<>"]/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[ch]));
    const initials = (who) => P[who][0].split(" ").map((w) => w[0]).join("");
    // `data-card` opens a hovercard: person:<who> or site:<site>.
    // `data-drift` names a part for the drift check (tools/drift), matching a `driftTag` in the app.
    const dt = (name) => ` data-drift="${name}"`;
    const av = (who, cls = "sim-av", card = true, attrs = "") =>
      `<div class="${cls}" style="--c:${P[who][1]}"${card ? ` data-card="person:${who}"` : ""}${attrs}>${initials(who)}</div>`;
    const siteIcon = (site, extra = "", attrs = "") => `<div class="sim-site ${extra}" style="--c:${S[site].color}" data-card="site:${site}"${attrs}>${S[site].name.replace("+", "")[0].toUpperCase()}</div>`;
    const marked = (text) => esc(text).replace(/@robin|Robin/g, (m) => `<mark>${m}</mark>`);
    // Reader posts you haven't read, per WordPress.com (`unseen` in the data), less what you've opened.
    const seen = (k) => (st.unseenAgain.has(k) ? false : st.seenPosts.has(k) || !POSTS[k].unseen);
    const isUnread = (n) => (n.unread && !st.read.has(n.id)) || st.unreadAgain.has(n.id);
    const unreadCount = () => NOTES.filter(isUnread).length;
    const KIND = { comment: "#0a84ff", mention: "#ff9500", like: "#f5b000", follow: "#34c759" };

    root.innerHTML = `
      <div class="sim" tabindex="0" aria-label="Interactive demo of Dispatch">
        <div class="sim-menubar"><span class="apple"></span><b>Finder</b><span>File</span><span>Edit</span><span>View</span>
          <span class="spacer"></span><button class="sim-w on" data-a="toggle" title="Dispatch">${I.w}<span class="sim-wcount"></span></button><span>Tue 9:41</span></div>
        <div class="sim-panel">
          <div class="sim-detail" data-drift="detail"></div>
          <div class="sim-list" data-drift="list">
            <div class="sim-head"></div>
            <div class="sim-filters"></div>
            <div class="sim-rows"><div class="sim-rows-inner"></div></div>
          </div>
          <div class="sim-handle" data-drift="grip"></div>
          <div class="sim-keys" data-a="keysHelp"><div class="card">
          <b>Keyboard Shortcuts</b>
          <div class="cols">${[
            ["Lists", [["← →", "Previous or next list, across sections"], ["⇧← ⇧→", "Previous or next section"], ["⌘1 ⌘2 ⌘3", "Notifications, Reader, Later"], ["⇥ ⇧⇥", "Next or previous section"], ["↑ ↓", "Move through the list (or j, k)"], ["⌘↑", "Back to the top"], ["esc", "Back out: a site’s feed, the reader, the panel"]]],
            ["Reading", [["Space ⇧Space", "Page down or up"], ["l", "Like"], ["s", "Save"], ["m", "Remind me later"], ["o", "Open in the browser"], ["u", "Mark unread (or read)"], ["⌘+ ⌘−", "Bigger or smaller text (⌘0 resets)"], ["click", "An image, to open it in Quick Look"], ["c", "Comments"], ["f", "Comments full height"], ["r", "Reply"], ["⌘↩", "Send a comment"]]],
            ["Later", [["↑ ↓", "Highlight a reminder"], ["↩", "Open it"], ["⌫", "Done"]]],
          ].map(([title, rows]) => `<div><i>${title}</i>${rows.map(([keys, what]) => `<p><span>${keys.split(" ").map((x) => `<kbd>${x}</kbd>`).join("")}</span>${what}</p>`).join("")}</div>`).join("")}</div>
        </div></div>
        </div>
        <div class="sim-dock">${["#5ac8fa", "#ff9f0a", "#34c759", "#af52de", "#ff375f", "#8e8e93", "#3858e9", "#ffd60a"]
          .map((c) => `<span style="--c:${c}"></span>`).join("")}<img class="app" src="${ICON}" alt=""></div>
        <div class="sim-banner" data-a="openBanner"></div>

        <div class="sim-switcher">${["#5ac8fa", "#ff9f0a", "#34c759", "#af52de"].map((c) => `<span style="--c:${c}"></span>`).join("")}<img class="on" src="${ICON}" alt=""><b>Dispatch</b></div>
        <div class="sim-menu"></div>
        <div class="sim-card"></div>
        <div class="sim-key"></div>
        <div class="sim-cursor">${I.cursor}</div>
      </div>`;
    const $ = (s) => root.querySelector(s);
    const sim = $(".sim"), panel = $(".sim-panel"), detail = $(".sim-detail"), rows = $(".sim-rows-inner");
    const cursor = $(".sim-cursor"), keyHint = $(".sim-key"), menu = $(".sim-menu"), card = $(".sim-card");

    // A clock beside a row's time while it has a reminder.
    const clock = (key) => (st.reminders[key] ? `<span class="sim-clock" title="Reminder: ${st.reminders[key].label}">${I.alarmFill}</span>` : "");
    const laterKeys = () => Object.keys(st.reminders).sort((a, b) => st.reminders[a].due - st.reminders[b].due); // soonest first

    function renderHead() {
      const unread = unreadCount();
      const conversations = NOTES.filter((n) => isUnread(n) && (n.kind === "mention" || n.kind === "comment")).length;
      $(".sim-wcount").textContent = (st.count === "none" ? 0 : st.count === "conversations" ? conversations : unread) || "";
      $(".sim-head").innerHTML = `
        <button class="sim-tab ${st.section === "notifications" ? "on" : ""}" data-a="section" data-v="notifications"${dt("tab.notifications")}>Notifications${unread ? `<span class="sim-badge"${dt("badge.notifications")}>${unread}</span>` : ""}</button>
        <button class="sim-tab ${st.section === "reader" ? "on" : ""}" data-a="section" data-v="reader"${dt("tab.reader")}>Reader</button>
        ${(() => { const due = Object.values(st.reminders).filter((x) => x.due <= new Date()).length;
          return `<button class="sim-tab ${st.section === "later" ? "on" : ""}" data-a="section" data-v="later"${dt("tab.later")}>Later${due ? `<span class="sim-badge">${due}</span>` : ""}</button>`; })()}
        <span class="spacer"></span>
        <button class="sim-icon" data-a="toast" data-v="Refreshed" title="Refresh"${dt("btn.refresh")}>${I.refresh}</button>
        ${st.detached
          ? `<button class="sim-icon" data-a="attach" title="Put back in the menu bar">${I.putBack}</button>`
          : `<button class="sim-icon" data-a="detach" title="Pop out into a window (or drag the header)"${dt("btn.popout")}>${I.popout}</button>`}
        <button class="sim-icon more ${st.menu ? "on" : ""}" data-a="menu" title="More"${dt("btn.more")}>${I.more}</button>
        ${st.detached ? `<button class="sim-icon" data-a="closeWindow" title="Close (⌘W)">${I.x}</button>` : ""}`;
    }

    // The ⋯ menu, as in the app.
    // Remind Me's times, as in Reminders.choices: soon, later today, tomorrow, next week.
    function remindChoices(now = new Date()) {
      const at = (h, days = 0) => { const d = new Date(now); d.setDate(d.getDate() + days); d.setHours(h, 0, 0, 0); return d; };
      const list = [["In 1 Hour", new Date(+now + 3600e3)], ["In 3 Hours", new Date(+now + 3 * 3600e3)]];
      if (now.getHours() < 17) list.push(["This Evening", at(18)]);
      list.push(["Tomorrow Morning", at(9, 1)]);
      list.push(["Next Week", at(9, ((8 - now.getDay()) % 7) || 7)]);
      return list;
    }
    function describeWhen(d) {
      const time = d.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
      const day = new Date(); day.setHours(0, 0, 0, 0);
      const diff = Math.round((new Date(d).setHours(0, 0, 0, 0) - day) / 864e5);
      return `${diff === 0 ? "Today" : diff === 1 ? "Tomorrow" : d.toLocaleDateString("en-US", { weekday: "short" })} at ${time}`;
    }
    function renderMenu() {
      menu.classList.toggle("show", !!st.menu);
      menu.classList.toggle("remind", st.menu === "remind");
      if (!st.menu) return;
      if (st.menu === "remind") {
        const s = selected(), set = s && st.reminders[keyOf(s.item)];
        menu.innerHTML = (set ? `<div class="dim">Reminding you ${set.label}</div><hr>` : "")
          + remindChoices().map(([title, when], i) => `<button data-a="remindAt" data-v="${i}">${title} — ${describeWhen(when)}</button>`).join("")
          + (set ? `<hr><button data-a="remindCancel">Cancel Reminder</button>` : "");
        const b = detail.querySelector('[data-a="remindMenu"]'), base = sim.getBoundingClientRect(), r = b?.getBoundingClientRect();
        if (r) { menu.style.left = (r.left - base.left) / st.scale - 4 + "px"; menu.style.top = (r.bottom - base.top) / st.scale + 4 + "px"; menu.style.right = "auto"; }
        return;
      }
      menu.style.left = menu.style.top = menu.style.right = "";
      const item = (label, tip) => `<button data-a="menuItem" data-v="${tip}">${label}</button>`;
      const toggle = (key, label) => `<button class="check ${st[key] ? "on" : ""}" data-a="menuToggle" data-v="${key}">${label}</button>`;
      menu.innerHTML = item("Open on WordPress.com", "Opens WordPress.com in your browser") + "<hr>"
        + toggle("dock", "Show in Dock") + toggle("window", "Open as a Window")
        + `<div class="dim">Menu Bar Count</div>` + [["all", "All Unread"], ["conversations", "Mentions and Replies"], ["none", "Nothing"]]
          .map(([v, label]) => `<button class="check ${(st.count || "all") === v ? "on" : ""}" data-a="menuCount" data-v="${v}">${label}</button>`).join("") + "<hr>"
        + item("Check for Updates…", "You're on the latest version") + `<div class="dim">Dispatch ${VERSION}</div><hr>`
        + item("Sign out", "Signs out of WordPress.com") + item("Restart", "Restarts Dispatch") + item("Quit", "Quits Dispatch");
    }

    let thumb = null;
    function renderFilters() {
      const box = $(".sim-filters");
      if (st.section === "later") {
        const n = Object.keys(st.reminders).length;
        box.innerHTML = `<span class="sim-latercount">${n === 0 ? "No reminders" : n === 1 ? "1 reminder, soonest first" : `${n} reminders, soonest first`}</span>`;
        thumb = null;
        return;
      }
      if (st.section === "reader" && st.site) {
        box.innerHTML = `<div class="sim-sitebar"><button class="sim-back" data-a="siteBack" title="Back">${I.back}</button>
          ${siteIcon(st.site, "tiny")}<b>${esc(S[st.site].name)}</b></div>`;
        thumb = null;
        return;
      }
      const unread = unreadCount();
      const count = (n, quiet) => (n ? `<span class="sim-badge ${quiet ? "quiet" : ""}">${n}</span>` : "");
      const opts = st.section === "notifications"
        ? [["all", "All"], ["unread", `Unread${count(unread)}`]]
        : [["blogs", "Following"], ["p2s", "Automattic"], ["saved", `${I.markFill.replace("<svg", '<svg width="9" height="10"')} Saved${count(st.saved.size, true)}`]];
      const cur = st.section === "notifications" ? st.filter : st.feed;
      box.innerHTML = `<div class="sim-pills"${dt("pills")}><div class="sim-pill-thumb"></div>${opts.map(([v, label], i) =>
        `<button class="sim-pill ${v === cur ? "on" : ""}" data-a="${st.section === "notifications" ? "filter" : "feed"}" data-v="${v}"${dt(`pill.${i}`)}>${label}</button>`).join("")}</div>
        <span class="spacer"></span>
        ${st.section === "notifications" ? `<button class="sim-icon" data-a="markAll" title="Mark all as read"${dt("btn.markall")} ${unread ? "" : "disabled"}>${I.check}</button>` : ""}`;
      const on = box.querySelector(".sim-pill.on"), t = box.querySelector(".sim-pill-thumb");
      // Slide from where the thumb was, unless the pill set itself changed.
      if (thumb && thumb.section === st.section) { t.style.left = thumb.left + "px"; t.style.width = thumb.width + "px"; t.getBoundingClientRect(); }
      t.style.left = on.offsetLeft + "px"; t.style.width = on.offsetWidth + "px";
      thumb = { section: st.section, left: on.offsetLeft, width: on.offsetWidth };
    }

    function noteRow(n, i) {
      const r = (name) => dt(`row.${i}.${name}`);
      // A follow names a site, not a post, so like the app it all goes on one line with no title.
      const post = n.post && POSTS[n.post];
      const title = post ? post.title : null;
      const action = post ? n.action : `${n.action} ${S[n.site].name}`;
      const unread = isUnread(n);
      return `<div class="sim-row note ${unread ? "unread" : ""} ${st.sel === n.id ? "on" : ""}" data-a="select" data-v="${n.id}"${r("box")}>
        <div class="sim-dot"${unread ? r("dot") : ""}></div>
        <div class="sim-avwrap">${av(n.who, "sim-av big", true, r("icon"))}<span class="sim-kind" style="background:${KIND[n.kind]}"${r("kind")}>${I.kind[n.kind]}</span></div>
        <div class="main">
          <div class="top"><div class="who"><span${r("who")}><b>${P[n.who][0]}</b> <span>${esc(action)}</span></span></div>${clock(n.id)}<div class="time"${r("time")}>${n.ago}</div></div>
          ${title ? `<div class="title"><span${r("title")}>${esc(title)}</span></div>` : ""}
          ${n.text ? `<div class="ex"><span${r("excerpt")}>${esc(n.text)}</span></div>` : ""}
        </div>
      </div>`;
    }
    // A Later row, like LaterRow: the item's picture, when it's due, what it is, and Done.
    function laterRow(key, i) {
      const r = (name) => dt(`row.${i}.${name}`), rem = st.reminders[key];
      const n = NOTES.find((x) => x.id === key), p = n ? POSTS[n.post] : POSTS[key];
      const due = rem.due <= new Date();
      const pic = n ? `<div class="sim-avwrap">${av(n.who, "sim-av big", true, r("icon"))}<span class="sim-kind" style="background:${KIND[n.kind]}"${r("kind")}>${I.kind[n.kind]}</span></div>`
        : siteIcon(p.site, "", r("icon"));
      const title = n ? `${P[n.who][0]} ${n.action}` : p.title, sub = n ? (p ? p.title : S[n.site].name) : S[p.site].name;
      return `<div class="sim-row sim-later ${st.laterHL === key ? "on" : ""}" data-a="openLater" data-v="${key}"${r("box")}>
        ${pic}
        <div class="main">
          <div class="when ${due ? "due" : ""}"><span${r("when")}>${I.alarmFill}${due ? "Due · " : ""}${rem.label}</span></div>
          <div class="title"><span${r("title")}>${esc(title)}</span></div>
          <div class="ex"><span${r("excerpt")}>${esc(sub)}</span></div>
        </div>
        <button class="sim-icon" data-a="laterDone" data-v="${key}" title="Done"${r("done")}>${I.check}</button>
      </div>`;
    }
    function postRow(k, i) {
      const r = (name) => dt(`row.${i}.${name}`);
      const p = POSTS[k], on = st.sel === k ? "on" : "";
      const saved = st.saved.has(k) && st.feed !== "saved" ? `<span class="sim-saved">${I.markFill}</span>` : ""; // everything in Saved is saved
      if (p.xpost) {
        return `<div class="sim-row compact sim-xrow ${on} ${seen(k) ? "" : "unread"}" data-a="select" data-v="${k}"${r("box")}>
          <div class="sim-dot"${seen(k) ? "" : r("dot")}></div>
          <div class="sim-avwrap x">${siteIcon(p.xpost.from, "small", r("icon"))}<div class="sim-xbadge"${r("kind")}>${I.xpost}</div></div>
          <div class="main"><div class="top"${r("line")}><div class="who"><b>${S[p.xpost.from].name}</b> → ${S[p.xpost.to].name} ${saved}</div><div class="time"${r("time")}>${p.ago}</div></div>
          <div class="title"><span${r("title")}>${esc(p.title)}</span></div></div></div>`;
      }
      const unseen = !seen(k);
      return `<div class="sim-row ${on} ${unseen ? "unread" : ""}" data-a="select" data-v="${k}"${r("box")}>
        <div class="sim-dot"${unseen ? r("dot") : ""}></div>
        ${siteIcon(p.site, "", r("icon"))}
        <div class="main">
          <div class="top"><div class="who site"><span${r("who")}>${S[p.site].name}</span></div>${clock(k)}<div class="time"${r("time")}>${p.ago}</div></div>
          <div class="title"><span${r("title")}>${esc(p.title)}</span></div>
          <div class="ex"><span${r("excerpt")}>${esc(p.excerpt)}</span></div>
          <div class="foot"${r("foot")}><span>${P[p.author][0]}</span><span>${p.read}</span>${p.views ? `<span class="sim-likes" title="${p.views} views">${I.signal}${p.views}</span>` : ""}${p.likes ? `<span class="sim-likes ${p.liked ? "liked" : ""}">${p.liked ? I.starFill : I.star}${p.likes}</span>` : ""}${p.comments.length ? `<span class="sim-likes">${I.comment.replace("<svg", '<svg class="cm"')}${p.comments.length}</span>` : ""}${saved}</div>
        </div></div>`;
    }
    function renderRows(swap) {
      const list = items();
      const html = list.length
        ? list.map((it, i) => (st.section === "notifications" ? noteRow(it, i) : st.section === "later" ? laterRow(it, i) : postRow(it, i))).join("")
        : `<div class="sim-placeholder" style="height:300px">${st.section === "later" ? "Nothing for later.<br>Use the alarm in the reader to be reminded about something."
          : st.feed === "saved" ? "Nothing saved yet.<br>Press s on a post to save it." : "You're all caught up."}</div>`;
      if (!swap) { rows.innerHTML = html; return; }
      rows.classList.add("swap");
      setTimeout(() => { rows.innerHTML = html; rows.classList.remove("swap"); }, 140);
    }

    function selected() {
      const list = items();
      const i = list.findIndex((it) => keyOf(it) === st.sel);
      return i < 0 ? null : { item: list[i], index: i, count: list.length };
    }

    // The like star, with a one-off pop (or squash) right after it's toggled.
    function star(x) {
      const fx = x.pop ? ` ${x.pop}` : "";
      delete x.pop;
      return `<span class="sim-star${fx}">${x.liked ? I.starFill : I.star}</span>`;
    }

    function renderDetail() {
      const s = selected();
      if (!s) {
        detail.innerHTML = `<div class="sim-placeholder">${I.w}Pick something to read<small>${st.section === "reader"
          ? "↑ ↓ or j k to move · l to like · s to save · o to open" : "↑ ↓ or j k to move · o to open in browser"}</small></div>`;
        return;
      }
      const p = postFor(s.item), page = pageFor(s.item, p);
      if (page.thread) { renderThread(s, p, page); return; }
      const mentions = page.body.join(" ").match(/@robin|Robin/g)?.length ?? 0;
      const likers = page.likers.map((who) =>
        `<span class="sim-liker" data-card="person:${who}">${av(who, "sim-av mini", false)}${P[who][0]}</span>`).join("");
      const byline = [page.author && `${av(page.author, "sim-av tiny")} <b data-card="person:${page.author}">${P[page.author][0]}</b>`,
        page.host, longAgo(page.ago)].filter(Boolean).join("<i>·</i>");
      detail.innerHTML = toolbar(s, p) + `
        <div class="sim-article">
          <div class="head">
          <div class="eyebrow">${page.eyebrow}</div>
          <h3>${esc(page.title)}</h3>
          <div class="sim-byline">${byline}</div>
          <div class="sim-chips"><span class="sim-chip">${page.read}</span>${mentions
            ? `<button class="sim-chip me" data-a="jump">You’re mentioned${mentions > 1 ? ` ${mentions}×` : ""}  ↓</button>` : ""}</div>
          ${likers ? `<div class="sim-likers">${likers}</div>` : ""}
          </div>
          <div class="body">${page.body.map((t) => `<p>${marked(t)}</p>`).join("")}</div>
        </div>
        ${p ? `<div class="sim-comments ${st.commentsOpen ? "open" : ""}"></div>` : ""}`;
      renderComments(true);
    }
    // A comment notification, like ReaderPage.commentPage: the post (a preview, and the whole post a
    // click away), the comment it replies to, then the comment itself, highlighted.
    function renderThread(s, p, page) {
      const { parent, comment } = page.thread;
      const bubble = (cm, cls) => `<div class="sim-tcmt ${cls}">${av(cm.who)}<div class="sim-tbubble">
        <div class="who"><b data-card="person:${cm.who}">${P[cm.who][0]}</b><span>${longAgo(cm.ago)}</span></div>${marked(cm.text)}</div></div>`;
      const mentions = [parent, comment].filter(Boolean).map((cm) => cm.text).join(" ").match(/@robin|Robin/g)?.length ?? 0;
      const likers = page.likers.map((who) =>
        `<span class="sim-liker" data-card="person:${who}">${av(who, "sim-av mini", false)}${P[who][0]}</span>`).join("");
      detail.innerHTML = toolbar(s, p) + `
        <div class="sim-article">
          <div class="head">
          <div class="eyebrow">${page.eyebrow}</div>
          <h3>${esc(page.title)}</h3>
          <div class="sim-byline">${av(p.author, "sim-av tiny")} <b data-card="person:${p.author}">${P[p.author][0]}</b><i>·</i>${S[p.site].host}<i>·</i>${longAgo(p.ago)}</div>
          ${st.postOpen ? "" : `<p class="sim-peek">${esc(p.excerpt)}</p>`}
          <button class="sim-readpost" data-a="togglePost">Read the whole post ${st.postOpen ? "↑" : "↓"}</button>
          ${st.postOpen ? `<div class="sim-full">${p.body.map((t) => `<p>${marked(t)}</p>`).join("")}</div>` : ""}
          </div>
          <div class="sim-label">${P[comment.who][0]} ${parent ? `replied to ${P[parent.who][0]}` : "commented"}</div>
          <div class="sim-thread">${parent ? bubble(parent, "parent") : ""}${bubble(comment, "this")}</div>
          ${mentions ? `<div class="sim-chips"><button class="sim-chip me" data-a="jump">You’re mentioned${mentions > 1 ? ` ${mentions}×` : ""}  ↓</button></div>` : ""}
          ${likers ? `<div class="sim-likers">${likers}</div>` : ""}
        </div>
        <div class="sim-comments ${st.commentsOpen ? "open" : ""}"></div>`;
      renderComments(true);
    }

    // What the reader shows, built the way the app builds it (Store.buildPage, ReaderStore.page):
    // a comment notification shows the comment, a like or follow shows the notification itself,
    // a post shows the post, and an x-post shows the original under where it was cross-posted.
    function pageFor(item, p) {
      const siteLink = (site, label = S[site].name) => `<a data-a="site" data-v="${site}" title="Read this site">${esc(label)}</a>`;
      const readTime = (words) => (words < 120 ? "Quick read" : `${Math.max(1, Math.round(words / 230))} min read`);
      const page = (o) => ({ likers: [], body: [], ...o, read: readTime(o.body?.join(" ").split(/\s+/).length ?? 0) });
      if (st.section === "reader") {
        const read = p.read === "2 min" || p.read === "3 min" ? "Quick read" : `${p.read} read`;
        const eyebrow = p.xpost ? `Cross-posted ${siteLink(p.xpost.from)} → ${siteLink(p.xpost.to)}` : siteLink(p.site);
        return { ...page({ eyebrow, title: p.title, author: p.author, host: S[p.site].host, ago: p.ago, body: p.body }), read };
      }
      const n = item;
      const comment = n.kind === "comment"
        ? p.comments.find((x) => x.who === n.who && x.text === n.text) ?? { who: n.who, text: n.text, ago: n.ago, depth: 0 }
        : n.comment && p.comments.find((x) => x.id === n.comment);
      if (comment) {
        // A reply's parent is the closest comment above it, one level up.
        const above = p.comments.slice(0, p.comments.indexOf(comment));
        const parent = comment.depth ? above.reverse().find((x) => x.depth === comment.depth - 1) : null;
        return page({ eyebrow: `Comment on ${siteLink(p.site, S[p.site].host)}`, title: p.title,
          thread: { parent, comment }, likers: n.people ?? [] });
      }
      if (p && n.kind !== "like") {
        return page({ eyebrow: siteLink(p.site, S[p.site].host), title: p.title, author: p.author, host: S[p.site].host, ago: p.ago, body: p.body });
      }
      // Likes on a post, follows: the notification is the whole story.
      return page({ eyebrow: `${P[n.who][0]} ${n.action}`, title: p ? p.title : S[n.site].name, ago: n.ago, host: S[p ? p.site : n.site].host,
        likers: n.kind === "like" ? n.people : [] });
    }
    const longAgo = (ago) => {
      const n = parseInt(ago), unit = { m: "minute", h: "hour", d: "day" }[ago.slice(-1)];
      return `${n} ${unit}${n === 1 ? "" : "s"} ago`;
    };
    function toolbar(s, p) {
      const reader = st.section === "reader" && p;
      return `<div class="sim-dhead">
        <button class="sim-icon" data-a="close" title="Close (esc)"${dt("detail.close")}>${I.x}</button>
        ${reader ? `<button class="sim-like ${p.liked ? "liked" : ""}" data-a="likePost" title="Like (l)"${dt("detail.like")}>${star(p)}${p.likes ? `<span>${p.likes}</span>` : ""}</button>
        <button class="sim-icon ${st.saved.has(s.item) ? "on" : ""}" data-a="save" title="Save (s)"${dt("detail.save")}>${st.saved.has(s.item) ? I.markFill : I.mark}</button>` : ""}
        ${(() => { const r = st.reminders[keyOf(s.item)]; return `<button class="sim-icon ${r ? "on" : ""}" data-a="remindMenu" title="${r ? `Reminder: ${r.label}` : "Remind me about this later"}"${dt("detail.remind")}>${r ? I.alarmFill : I.alarm}</button>`; })()}
        <button class="sim-icon" data-a="toast" data-v="Opens in your browser" title="Open in browser (o)"${dt("detail.open")}>${I.safari}</button>
        <span class="spacer"></span>
        <span class="sim-pos"${dt("detail.pos")}>${s.index + 1} of ${s.count}</span>
        <button class="sim-icon" data-a="move" data-v="-1" title="Previous (k)"${dt("detail.prev")}>${I.up}</button>
        <button class="sim-icon" data-a="move" data-v="1" title="Next (j)"${dt("detail.next")}>${I.down}</button>
      </div>`;
    }

    function renderComments(first) {
      const box = detail.querySelector(".sim-comments");
      const s = selected();
      if (!box || !s) return;
      const p = postFor(s.item);
      const list = p.comments;
      const n = list.length;
      box.classList.toggle("open", st.commentsOpen);
      detail.classList.toggle("cexp", st.commentsOpen && !!st.commentsExpanded); // comments over the whole reader
      const head = `<button class="sim-chead" data-a="comments"${dt("comments.head")}>${I.bubbles}<span>${n === 0 ? "Add a comment" : n === 1 ? "1 comment" : n + " comments"}</span><span class="spacer"></span>${I.chev}</button>${st.commentsOpen
        ? `<button class="sim-icon sim-cexpand" data-a="expandComments" title="${st.commentsExpanded ? "Show the post too" : "Comments full height"}"${dt("comments.expand")}>${st.commentsExpanded ? I.collapse : I.expand}</button>` : ""}`;
      if (!st.commentsOpen) {
        box.innerHTML = head + (n ? `<div class="sim-strip">${list.map((cm, i) =>
          `<div class="sim-cmt" style="animation-delay:${first ? i * 45 : 0}ms"${dt(`comments.bubble.${i}`)}>${av(cm.who)}<div class="sim-bubble"><span class="clamp">${esc(cm.text)}</span></div></div>`).join("")}
          <button class="sim-add" data-a="reply" data-v="" title="Add a comment"${dt("comments.add")}>${I.plus}</button></div>` : "");
        return;
      }
      box.innerHTML = head + `<div class="sim-clist"${dt("comments.list")}>${list.map((cm) => `
        <div style="padding-left:${Math.min(cm.depth, 3) * 24}px">
          <div class="sim-cmt ${cm.fresh ? "" : "settled"}" style="${cm.fresh ? "" : "animation:none"}">${av(cm.who)}<div class="sim-bubble"><div class="name">${P[cm.who][0]}<span>${cm.ago}</span></div>${marked(cm.text)}</div></div>
          <div class="sim-acts"><button class="${cm.liked ? "liked" : ""}" data-a="like" data-v="${cm.id}">${star(cm)}${cm.likes ? cm.likes : ""}</button>
          <button class="${st.replyTo === cm.id ? "replying" : ""}" data-a="reply" data-v="${cm.id}">Reply</button></div>
        </div>`).join("")}</div>
        <div class="sim-composer">
          ${st.replyTo ? `<div class="sim-replyto">↩ Replying to ${P[list.find((x) => x.id === st.replyTo).who][0]}</div>` : ""}
          <div class="sim-field"><div${dt("comments.field")} class="sim-input ${st.typing ? "typing" : ""}">${st.draft ? esc(st.draft) : st.typing ? "" : st.replyTo ? "Write a reply…" : "Add a comment…"}</div>
          <button class="sim-send ${st.draft ? "ready" : ""}" data-a="send" title="Send (⌘↩)">${I.send}</button></div>
        </div>`;
      list.forEach((cm) => delete cm.fresh);
      const cl = box.querySelector(".sim-clist");
      if (cl) cl.scrollTop = st.scrollTo === "end" ? cl.scrollHeight : 0;
      st.scrollTo = null;
    }

    function render(swapRows) {
      panel.classList.toggle("hidden", !st.open);
      $(".sim-w").classList.toggle("on", st.open && !st.detached);
      panel.classList.toggle("window", !!st.detached);
      $(".sim-dock").classList.toggle("running", !!(st.detached || st.dock));
      // Like the app's status item: the W, then the unread count beside it.
      renderHead();
      panel.classList.toggle("wide", st.sel !== null || !!st.detached); // a window always has room for the reader
      renderHead(); renderFilters(); renderRows(swapRows); renderDetail(); renderMenu();
      if (cardFor && !sim.contains(cardFor)) hideCard();
      fit();
    }

    // ---------------------------------------------------------------- actions
    let toastTimer;
    function hint(html, ms = 1300) {
      keyHint.innerHTML = html; keyHint.classList.add("show");
      clearTimeout(toastTimer); toastTimer = setTimeout(() => keyHint.classList.remove("show"), ms);
    }
    const A = {
      toggle() { st.open = !st.open; if (!st.open) { st.sel = null; st.commentsOpen = false; } render(); },
      section(v) { if (st.section === v) return; st.section = v; st.sel = null; st.commentsOpen = false; render(true); },
      filter(v) { st.filter = v; renderFilters(); renderRows(true); },
      feed(v) { st.feed = v; st.site = null; st.sel = null; render(true); },
      // ←/→ walk every list in one row, across sections, as in the app: All, Unread, Following,
      // Automattic, Saved, Later.
      tab(d) {
        const stops = ["n:all", "n:unread", "r:blogs", "r:p2s", "r:saved", "later"];
        const here = st.section === "notifications" ? `n:${st.filter}` : st.section === "reader" ? `r:${st.feed}` : "later";
        const next = stops[Math.min(Math.max(stops.indexOf(here) + d, 0), stops.length - 1)];
        if (next === here && !st.site) return;
        const [kind, v] = next.split(":");
        if (kind === "n") { if (st.section !== "notifications") A.section("notifications"); if (st.filter !== v) A.filter(v); }
        else if (kind === "r") { st.site = null; if (st.section !== "reader") { st.feed = v; A.section("reader"); } else A.feed(v); }
        else A.section("later");
      },
      // ⇥ / ⇧⇥: the next section.
      nextSection(d) {
        const all = ["notifications", "reader", "later"];
        A.section(all[(all.indexOf(st.section) + d + 3) % 3]);
      },
      // ⇧←/⇧→: the next section, without wrapping.
      jumpSection(d) {
        const all = ["notifications", "reader", "later"], i = all.indexOf(st.section);
        const next = all[Math.min(Math.max(i + d, 0), 2)];
        if (next !== st.section) A.section(next);
      },
      // u: a notification back to unread, or read again.
      unreadKey() {
        const s = selected();
        if (st.section === "reader" && s) {
          if (seen(s.item)) { st.seenPosts.delete(s.item); st.unseenAgain.add(s.item); } else { st.seenPosts.add(s.item); st.unseenAgain.delete(s.item); }
          renderRows(); hint(seen(s.item) ? "Marked as read" : "Marked as unread"); return;
        }
        if (st.section !== "notifications" || !s) return;
        const id = s.item.id;
        if (isUnread(s.item)) { st.read.add(id); st.unreadAgain.delete(id); } else { st.read.delete(id); st.unreadAgain.add(id); }
        renderHead(); renderFilters(); renderRows();
        hint(isUnread(s.item) ? "Marked as unread" : "Marked as read");
      },
      keysHelp() { sim.querySelector(".sim-keys").classList.toggle("show"); },
      commentsKey() { if (st.sel !== null && postFor(selected()?.item)) A.comments(); },
      fullKey() { if (st.sel === null || !postFor(selected()?.item)) return; if (!st.commentsOpen) { st.commentsOpen = true; st.commentsExpanded = true; } else st.commentsExpanded = !st.commentsExpanded; renderComments(true); },
      replyKey() { if (st.sel !== null && postFor(selected()?.item)) A.reply(""); },
      remindKey() { if (st.sel !== null) A.remindMenu(); },
      page(d) { const a = detail.querySelector(".sim-article"); if (a) a.scrollBy({ top: d * a.clientHeight * 0.85, behavior: "smooth" }); },
      laterMove(d) {
        const keys = laterKeys(); if (!keys.length) return;
        const i = keys.indexOf(st.laterHL);
        st.laterHL = keys[Math.max(0, Math.min(keys.length - 1, i < 0 ? 0 : i + d))]; renderRows();
      },
      laterOpen() { if (st.laterHL) A.openLater(st.laterHL); },
      laterDoneKey() { if (st.laterHL) { const k = st.laterHL; A.laterMove(1); if (st.laterHL === k) st.laterHL = null; A.laterDone(k); } },
      togglePost() { st.postOpen = !st.postOpen; renderDetail(); },
      select(v) {
        st.sel = v; st.commentsOpen = false; st.replyTo = null; st.draft = ""; st.postOpen = false;
        if (st.section === "notifications") { st.read.add(v); st.unreadAgain.delete(v); }
      else { st.seenPosts.add(v); st.unseenAgain.delete(v); }
        render();
      },
      move(d) {
        const list = items(); if (!list.length || st.section === "later") return;
        const i = list.findIndex((it) => keyOf(it) === st.sel);
        const next = Math.max(0, Math.min(list.length - 1, i < 0 ? 0 : i + Number(d)));
        A.select(keyOf(list[next]));
      },
      close() {
        if (st.sel !== null) { st.sel = null; st.commentsOpen = false; render(); }
        else if (!st.detached) { st.open = false; render(); }
      },
      // Pop out into a window, and back. As a window Dispatch is in the Dock and ⌘-Tab.
      detach() { Object.assign(st, { detached: true, menu: false }); hideCard(); render(); },
      attach() { st.detached = false; render(); },
      closeWindow() { Object.assign(st, { detached: false, open: false, sel: null, commentsOpen: false }); render(); },
      switcher(on) { sim.querySelector(".sim-switcher").classList.toggle("show", !!on); },
      comments() { st.commentsOpen = !st.commentsOpen; st.replyTo = null; renderComments(true); },
      expandComments() { st.commentsExpanded = !st.commentsExpanded; renderComments(); },
      like(v) {
        const s = selected(); const cm = s && postFor(s.item).comments.find((x) => x.id === Number(v)); if (!cm) return;
        cm.liked = !cm.liked; cm.likes += cm.liked ? 1 : -1; cm.pop = cm.liked ? "pop" : "unpop"; renderComments();
      },
      reply(v) {
        st.replyTo = v ? Number(v) : null; st.typing = true;
        if (!st.commentsOpen) st.commentsOpen = true;
        st.scrollTo = "end"; renderComments(true);
      },
      type(text) { st.typing = true; st.draft = text; st.scrollTo = "end"; renderComments(); },
      send() {
        const s = selected(); if (!s || !st.draft.trim()) return;
        const list = postFor(s.item).comments;
        const parent = list.find((x) => x.id === st.replyTo);
        const cm = c(Date.now(), "robin", st.draft.trim(), "now", 0, parent ? parent.depth + 1 : 0);
        cm.fresh = true;
        if (parent) {
          let at = list.indexOf(parent) + 1;
          while (at < list.length && list[at].depth > parent.depth) at++;
          list.splice(at, 0, cm);
        } else list.push(cm);
        st.draft = ""; st.replyTo = null; st.typing = false; st.scrollTo = "end";
        renderDetail();
      },
      likePost() {
        const s = selected(); const p = s && postFor(s.item); if (!p || st.section !== "reader") return;
        p.liked = !p.liked; p.likes += p.liked ? 1 : -1; p.pop = p.liked ? "pop" : "unpop";
        renderRows(); renderDetail();
      },
      save() {
        const s = selected(); if (!s || st.section !== "reader") return;
        st.saved.has(s.item) ? st.saved.delete(s.item) : st.saved.add(s.item);
        hint(st.saved.has(s.item) ? "Saved" : "Removed from Saved"); renderFilters(); renderRows(); renderDetail();
      },
      markAll() { NOTES.forEach((n) => st.read.add(n.id)); renderHead(); renderFilters(); renderRows(); hint("All caught up"); },
      // One site's posts: from a post's site name, or Read on its hovercard.
      site(v) {
        hideCard();
        Object.assign(st, { section: "reader", site: v, sel: null, commentsOpen: false });
        render(true);
      },
      siteBack() { st.site = null; st.sel = null; render(true); },
      jump() {
        const m = detail.querySelector(".sim-article mark"); if (!m) return;
        m.classList.remove("on"); m.getBoundingClientRect(); m.classList.add("on");
      },
      menu() { st.menu = !st.menu; renderHead(); renderMenu(); },
      // Later: open the item where it lives (the reminder stays until Done), or mark it done.
      openLater(key) {
        const n = NOTES.find((x) => x.id === key);
        Object.assign(st, { section: n ? "notifications" : "reader", site: null, sel: null, commentsOpen: false });
        if (!n) st.feed = FEEDS.p2s.includes(key) ? "p2s" : "blogs";
        A.select(key);
      },
      laterDone(key) { delete st.reminders[key]; renderHead(); renderFilters(); renderRows(); },
      remindMenu() { st.menu = st.menu === "remind" ? false : "remind"; renderMenu(); },
      remindAt(i) {
        const s = selected(); if (!s) return;
        const [, when] = remindChoices()[Number(i)];
        st.reminders[keyOf(s.item)] = { due: when, label: describeWhen(when) };
        st.menu = false; renderMenu(); renderRows(); renderDetail();
        hint(`Reminding you ${describeWhen(when)}`, 1800);
      },
      remindCancel() {
        const s = selected(); if (s) delete st.reminders[keyOf(s.item)];
        st.menu = false; renderMenu(); renderRows(); renderDetail();
      },
      // A reminder coming due, as a Mac notification banner in the corner of the desk.
      banner(key) {
        const b = sim.querySelector(".sim-banner");
        if (!key) { b.classList.remove("show"); return; }
        const n = NOTES.find((x) => x.id === key), p = n ? POSTS[n.post] : POSTS[key];
        b.dataset.v = key;
        b.innerHTML = `<img src="${ICON}" alt=""><div><b>${n ? `${P[n.who][0]} ${n.action}` : esc(p.title)}</b>
          <span>${esc(p ? p.title : S[n.site].name)}</span><small>You asked to be reminded about this.</small></div><em>now</em>`;
        b.classList.add("show");
      },
      openBanner(v) { A.banner(null); delete st.reminders[v]; if (st.sel !== v) A.select(v); else { renderRows(); renderDetail(); } },
      menuItem(v) { st.menu = false; renderHead(); renderMenu(); hint(v, 1800); },
      menuCount(v) { st.count = v; st.menu = false; render(); },
      menuToggle(v) {
        st[v] = !st[v]; st.menu = false; renderHead(); renderMenu();
        hint(v === "dock" ? (st.dock ? "Dispatch keeps a Dock icon" : "Dock icon only while it's a window")
          : (st.window ? "Dispatch opens as a window" : "Dispatch opens in the menu bar"), 1800);
      },
      toast(v) { hideCard(); hint(v, 1800); },
    };

    // Clicks: real ones pause the tour; the tour's own are synthetic (isTrusted false).
    sim.addEventListener("click", (e) => {
      const el = e.target.closest("[data-a]");
      if (e.isTrusted) stopTour();
      if (st.menu && !["menu", "menuItem", "menuToggle", "remindMenu", "remindAt", "remindCancel"].includes(el?.dataset.a)) A.menu();
      if (!el) return;
      A[el.dataset.a](el.dataset.v);
    });
    sim.addEventListener("keydown", (e) => {
      hideCard();
      // The comment box takes real typing once it's open.
      if (st.typing && st.commentsOpen && e.isTrusted) {
        stopTour();
        if (e.key === "Escape") { st.typing = false; st.replyTo = null; st.draft = ""; renderComments(); }
        else if (e.key === "Enter") A.send();
        else if (e.key === "Backspace") A.type(st.draft.slice(0, -1));
        else if (e.key.length === 1 && !e.metaKey && !e.ctrlKey) A.type(st.draft + e.key);
        else return;
        e.preventDefault();
        return;
      }
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      if (st.menu && e.key === "Escape") { A.menu(); e.preventDefault(); return; }
      const help = sim.querySelector(".sim-keys");
      if (help.classList.contains("show") && (e.key === "Escape" || e.key === "?")) { A.keysHelp(); e.preventDefault(); return; }
      const later = st.section === "later";
      const k = {
        j: later ? ["laterMove", 1] : ["move", 1], ArrowDown: later ? ["laterMove", 1] : ["move", 1],
        k: later ? ["laterMove", -1] : ["move", -1], ArrowUp: later ? ["laterMove", -1] : ["move", -1],
        ArrowLeft: e.shiftKey ? ["jumpSection", -1] : ["tab", -1], ArrowRight: e.shiftKey ? ["jumpSection", 1] : ["tab", 1],
        Tab: ["nextSection", e.shiftKey ? -1 : 1],
        Escape: st.site && st.sel === null ? ["siteBack"] : ["close"], "?": ["keysHelp"],
        Enter: later ? ["laterOpen"] : null, Backspace: later ? ["laterDoneKey"] : null,
        " ": ["page", e.shiftKey ? -1 : 1], c: ["commentsKey"], f: ["fullKey"], r: ["replyKey"], m: ["remindKey"],
        s: ["save"], l: ["likePost"], o: later ? ["laterOpen"] : ["toast", "Opens in your browser"], u: ["unreadKey"],
      }[e.key];
      if (!k) return;
      e.preventDefault();
      if (e.isTrusted) stopTour();
      A[k[0]](k[1]);
    });

    // ---------------------------------------------------------------- hovercards
    // Like the app: rest on a face or a site icon and a card opens beside it. Row icons put
    // it to the left, comment avatars above, the byline below.
    let cardFor = null, cardTimer;
    function cardHTML(kind, k) {
      if (kind === "person") {
        const x = CARD[k];
        return `<div class="sim-cardtop">${av(k, "sim-av huge")}<div><div class="nm">${P[k][0]} <span>${x.pronouns}</span></div>
          <div class="sub">${x.work}</div><div class="sub">${I.pin}${x.place}</div></div></div>
          <p>${x.bio}</p><div class="sim-cardlinks"><button data-a="toast" data-v="Opens their profile in your browser">View profile</button></div>`;
      }
      const x = S[k];
      const stats = [x.subs && `${x.subs.toLocaleString("en-US")} subscribers`, `${x.posts} posts`].filter(Boolean).join(" · ");
      return `<div class="sim-cardtop">${siteIcon(k, "big")}<div><div class="nm">${esc(x.name)}</div><div class="sub">${x.host}</div></div></div>
        <p>${esc(x.about)}</p><div class="sub">${stats}</div>
        <div class="sim-cardlinks"><button data-a="site" data-v="${k}">Read</button><button data-a="toast" data-v="Opens ${x.host} in your browser">Visit site</button></div>`;
    }
    function showCard(el) {
      clearTimeout(cardTimer);
      const [kind, k] = el.dataset.card.split(":");
      cardFor = el;
      card.innerHTML = cardHTML(kind, k);
      const r = el.getBoundingClientRect(), base = sim.getBoundingClientRect(), sc = st.scale;
      const a = { x: (r.left - base.left) / sc, y: (r.top - base.top) / sc, w: r.width / sc, h: r.height / sc };
      const w = 290, h = card.offsetHeight, gap = 8;
      const edge = el.closest(".sim-comments") ? "top" : el.closest(".sim-byline") ? "bottom" : "leading";
      const v = st.view; // on phones, only part of the desk is on screen
      let x, y;
      if (edge === "leading") { x = a.x - gap - w; y = a.y - 6; if (x < v.x + 4) { x = a.x - 6; y = a.y + a.h + gap; } }
      else { x = a.x - 6; y = edge === "top" ? a.y - gap - h : a.y + a.h + gap; if (y < 30) y = a.y + a.h + gap; }
      card.style.left = Math.min(Math.max(x, v.x + 4), v.x + v.w - w - 4) + "px";
      card.style.top = Math.min(Math.max(y, 30), 600 - h - 4) + "px";
      card.classList.add("show");
    }
    function hideCard() { clearTimeout(cardTimer); cardFor = null; card.classList.remove("show"); }
    sim.addEventListener("mouseover", (e) => {
      if (card.contains(e.target)) { clearTimeout(cardTimer); return; }
      const el = e.target.closest("[data-card]");
      if (!el) return;
      if (el === cardFor) { clearTimeout(cardTimer); return; }
      clearTimeout(cardTimer);
      cardTimer = setTimeout(() => showCard(el), cardFor ? 120 : 550);
    });
    sim.addEventListener("mouseout", (e) => {
      const from = card.contains(e.target) ? card : e.target.closest("[data-card]");
      if (!from) return;
      const to = e.relatedTarget;
      if (to && (from.contains(to) || card.contains(to) || cardFor?.contains(to))) return;
      clearTimeout(cardTimer);
      if (cardFor) cardTimer = setTimeout(hideCard, 220);
    });

    // ---------------------------------------------------------------- scale to fit
    // Stages 900px and wider show the top 1000×600 of the desk. The page's columns get a fixed
    // frame the shape of the whole screen: a close-up of the menu bar and list, then the camera
    // pulls back to the whole screen when the reader opens. Phones are too narrow for that wide shot, so their camera follows the action
    // instead: the list, then the reader.
    const CAMERA = { list: { x: 570, y: 26, w: 420, h: 570 }, reader: { x: 30, y: 26, w: 560, h: 570 } };
    const SHOT = { list: { x: 570, y: 0, w: 420, h: 520 }, panel: { x: 0, y: 0, w: 1000, h: DESK_H } };
    function fit() {
      const width = root.clientWidth;
      let scale, x = 0, y = 0, h;
      if (width >= 900) {
        scale = Math.min(1, width / 1000); h = 600 * scale;
        st.view = { x: 0, w: 1000 };
      } else if (width >= 560) {
        const wide = st.open && (st.sel !== null || !!st.detached), f = wide ? SHOT.panel : SHOT.list;
        h = width * DESK_H / 1000;
        scale = wide ? width / f.w : h / f.h;
        const w = width / scale, tall = h / scale;
        const left = Math.min(Math.max(f.x + f.w / 2 - w / 2, 0), 1000 - w);
        const top = Math.min(Math.max(f.y + f.h / 2 - tall / 2, 0), DESK_H - tall);
        x = -left * scale; y = -top * scale;
        st.view = { x: left, w };
      } else {
        // Centered on the list or reader; a stage with room to spare shows more desk, never past its edges.
        const r = st.open && st.sel !== null ? CAMERA.reader : CAMERA.list;
        scale = Math.min(1.1, width / r.w); h = r.h * scale;
        const w = width / scale, left = Math.min(Math.max(r.x + r.w / 2 - w / 2, 0), 1000 - w);
        x = -left * scale; y = -r.y * scale;
        st.view = { x: left, w };
      }
      keyHint.style.left = st.view.x + st.view.w / 2 + "px"; // key hints stay in shot
      sim.style.transform = `translate(${x}px, ${y}px) scale(${scale})`;
      root.style.height = h + "px";
      st.scale = scale;
    }
    new ResizeObserver(() => fit()).observe(root);
    fit();
    requestAnimationFrame(() => sim.classList.add("ready")); // animate the camera only after the first fit

    // ---------------------------------------------------------------- tour
    // Each stage plays its chapters on a loop while it's on screen. A real click or key
    // hands it over to the visitor until they press Play again.
    const scope = root.closest("[data-sim-row]") || document;
    const captionEl = scope.querySelector("[data-sim-caption]");
    const playBtn = scope.querySelector("[data-sim-play]");
    const NAMES = root.dataset.dispatchSim ? root.dataset.dispatchSim.split(/[\s,]+/) : null;
    // A still sets up one scene and leaves it for visitors to click around in, with no tour.
    const STILL = root.dataset.simStill;
    const SCENES = {
      notifications() {},
      xposts() { Object.assign(st, { section: "reader", feed: "p2s", sel: "train" }); },
      // The rest are for the drift check (tools/drift), which renders the app in the same states.
      "note-open"() { st.sel = "n2"; st.read.add("n2"); },
      keys() { setTimeout(() => sim.querySelector(".sim-keys").classList.add("show")); },
      later() {
        const when = remindChoices(), tomorrow = when.find(([t]) => t === "Tomorrow Morning")[1];
        st.reminders = { n2: { due: tomorrow, label: describeWhen(tomorrow) }, waits: { due: when[1][1], label: describeWhen(when[1][1]) } };
        st.section = "later";
      },
      "comments-full"() { Object.assign(st, { sel: "n1", commentsOpen: true, commentsExpanded: true }); st.read.add("n1"); },
      "reply-open"() { st.sel = "n4"; st.read.add("n4"); },
      "comments-open"() { Object.assign(st, { sel: "n1", commentsOpen: true }); st.read.add("n1"); },
      reader() { st.section = "reader"; },
      "reader-post"() { Object.assign(st, { section: "reader", sel: "waits" }); st.seenPosts.add("waits"); },
    };
    let token = 0, playing = false, visible = false, handedOver = false;
    const Cancel = Symbol("cancel");
    const sleep = (ms, t) => new Promise((ok, fail) => setTimeout(() => (t === token ? ok() : fail(Cancel)), ms));

    function caption(text) {
      if (!captionEl) return;
      captionEl.classList.add("fade");
      setTimeout(() => { captionEl.textContent = text; captionEl.classList.remove("fade"); }, 220);
    }
    function setPlaying(on) {
      playing = on;
      if (playBtn) {
        playBtn.innerHTML = on
          ? `<svg viewBox="0 0 12 12" fill="currentColor"><rect x="2" y="1.5" width="3" height="9" rx="1"/><rect x="7" y="1.5" width="3" height="9" rx="1"/></svg>`
          : `<svg viewBox="0 0 12 12" fill="currentColor"><path d="M3 1.5v9l7.5-4.5z"/></svg>`;
        playBtn.setAttribute("aria-label", on ? "Pause" : "Play");
      }
      cursor.classList.toggle("show", on);
    }
    function halt() { token++; setPlaying(false); }
    function stopTour() { handedOver = true; if (!playing) return; halt(); caption("Your turn. Click around, or use j, k, l, s and esc."); }

    // Pretend cursor: glide to an element, ripple, then click it for real.
    let cx = 700, cy = 300;
    async function point(sel, t, { click = true, dx = 0, dy = 0 } = {}) {
      const el = typeof sel === "string" ? sim.querySelector(sel) : sel;
      if (!el) return;
      const r = el.getBoundingClientRect(), base = sim.getBoundingClientRect();
      cx = (r.left - base.left) / st.scale + Math.min(r.width / st.scale / 2, 60) + dx;
      cy = (r.top - base.top) / st.scale + r.height / st.scale / 2 + dy;
      cursor.style.transform = `translate(${cx - 2}px, ${cy - 2}px)`;
      await sleep(760, t);
      if (!click) return;
      const ripple = document.createElement("div");
      ripple.className = "sim-ripple"; ripple.style.left = cx + "px"; ripple.style.top = cy + "px";
      sim.appendChild(ripple); setTimeout(() => ripple.remove(), 500);
      el.click();
      await sleep(260, t);
    }
    async function key(k, t) {
      hint(`<kbd>${k === "Escape" ? "esc" : k}</kbd>`, 700);
      sim.dispatchEvent(new KeyboardEvent("keydown", { key: k, bubbles: true }));
      await sleep(650, t);
    }
    async function typeOut(text, t) {
      for (let i = 1; i <= text.length; i++) { A.type(text.slice(0, i)); await sleep(32 + Math.random() * 40, t); }
    }
    function reset() {
      Object.assign(st, { open: true, section: "notifications", filter: "all", feed: "blogs", site: null, menu: false, sel: null, commentsOpen: false, replyTo: null, draft: "", typing: false, detached: false });
      hideCard(); A.switcher(false); A.banner(null); st.reminders = {}; st.laterHL = null;
      sim.querySelector(".sim-keys")?.classList.remove("show");
      st.read.clear(); st.saved.clear(); st.unreadAgain.clear(); st.seenPosts.clear(); st.unseenAgain.clear();
      Object.values(POSTS).forEach((p) => { if (p.liked) { p.liked = false; p.likes--; } });
      POSTS.inbox.comments = POSTS.inbox.comments.filter((x) => x.id < 1000);
      POSTS.inbox.comments.forEach((x) => { if (x.liked) { x.liked = false; x.likes--; } });
      render();
    }
    const rowSel = (v) => `.sim-row[data-v="${v}"]`;

    const CHAPTERS = {
      async notifications(t) {
        caption("Comments, likes, mentions and follows from WordPress.com, right in your menu bar.");
        if (!st.open) await point(".sim-w", t);
        if (st.section !== "notifications") await point('.sim-tab[data-v="notifications"]', t);
        await sleep(1200, t);
        await point('.sim-pill[data-v="unread"]', t); await sleep(1400, t);
        await point('.sim-pill[data-v="all"]', t); await sleep(600, t);
      },
      async read(t) {
        caption("Click anything to read it right there. The reader slides out beside the list.");
        if (st.section !== "notifications") await point('.sim-tab[data-v="notifications"]', t);
        await point(rowSel("n2"), t); await sleep(2200, t);
        caption("Mentions of you are highlighted, so you can spot why it landed in your lap.");
        await point(".sim-chip.me", t); await sleep(1800, t);
      },
      async keys(t) {
        caption("Skim with the keyboard: j and k move through the list, esc closes the reader.");
        if (st.sel === null) await point(rowSel("n1"), t);
        await key("j", t); await key("j", t); await key("k", t); await sleep(400, t);
        await key("Escape", t); await sleep(400, t);
        caption("← and → walk every list, from Notifications through the Reader’s tabs to Later.");
        for (let i = 0; i < 4; i++) await key("ArrowRight", t);
        await sleep(600, t);
        caption("And ? shows them all.");
        await key("?", t); await sleep(2600, t); await key("?", t);
      },
      async reader(t) {
        caption("The Reader: the blogs you follow, with reading times so you know what you're getting into.");
        await point('.sim-tab[data-v="reader"]', t); await sleep(900, t);
        await point(rowSel("waits"), t); await sleep(1500, t);
        caption("Like a post with a click (or l), the same as liking it on WordPress.com.");
        await point('[data-a="likePost"]', t); await sleep(1600, t);
      },
      async saved(t) {
        st.saved.add("focaccia"); render(); // saved the other day, so the list isn't empty
        caption("Save a post with s, and it's on your WordPress.com saved list.");
        await point('.sim-tab[data-v="reader"]', t); await sleep(800, t);
        await point(rowSel("sourdough"), t); await sleep(1300, t);
        await key("s", t); await sleep(700, t);
        caption("Saved keeps it until you have a minute, here or on the web.");
        await point('.sim-pill[data-v="saved"]', t); await sleep(2400, t);
      },
      async remind(t) {
        caption("Read it now, deal with it later: Remind Me brings it back when you're ready.");
        if (st.section !== "notifications") await point('.sim-tab[data-v="notifications"]', t);
        await point(rowSel("n2"), t); await sleep(1400, t);
        await point('[data-a="remindMenu"]', t); await sleep(900, t);
        await point('[data-a="remindAt"][data-v="' + (remindChoices().length - 2) + '"]', t); await sleep(1300, t);
        caption("The row keeps a clock until then.");
        await point(".sim-clock", t, { click: false }); await sleep(1600, t);
        caption("When it's time, a notification brings it back. Click it to pick up where you left off.");
        await key("Escape", t);
        hint("Tomorrow, 9:00 AM", 1400); await sleep(900, t);
        A.banner("n2"); await sleep(1800, t);
        await point(".sim-banner", t); await sleep(1800, t);
      },
      async window(t) {
        caption("Drag Dispatch off the menu bar and it becomes a window.");
        await point(".sim-head .spacer", t, { click: false });
        A.detach();
        cy += 68; cursor.style.transform = `translate(${cx - 2}px, ${cy - 2}px)`; // carried along with the header
        await sleep(1400, t);
        caption("It's in the Dock and ⌘-Tab, like any other app.");
        await point(".sim-dock .app", t, { click: false }); await sleep(900, t);
        hint("<kbd>⌘</kbd><kbd>Tab</kbd>", 1500); A.switcher(true); await sleep(1700, t); A.switcher(false);
        await sleep(500, t);
        caption("Close it, and it tucks back into the menu bar.");
        await point('[data-a="closeWindow"]', t); await sleep(1400, t);
      },
      async cards(t) {
        caption("Rest on a face or a site icon and a card tells you who they are.");
        if (st.section !== "reader") await point('.sim-tab[data-v="reader"]', t);
        if (st.site || st.feed !== "blogs") await point(st.site ? ".sim-back" : '.sim-pill[data-v="blogs"]', t);
        const icon = sim.querySelector(`${rowSel("sourdough")} .sim-site`);
        await point(icon, t, { click: false }); showCard(icon); await sleep(2200, t);
        caption("Read shows just that site's posts.");
        await point('.sim-card [data-a="site"]', t); await sleep(1600, t);
        await point(".sim-back", t); await sleep(600, t);
      },
      async xposts(t) {
        caption("P2s live under Automattic. X-posts show where they came from and open the original post.");
        if (st.section !== "reader") await point('.sim-tab[data-v="reader"]', t);
        await point('.sim-pill[data-v="p2s"]', t); await sleep(900, t);
        await point(rowSel("train"), t); await sleep(2400, t);
      },
      async comments(t) {
        caption("Comments come along. Open the drawer for the whole thread.");
        if (st.section !== "notifications") await point('.sim-tab[data-v="notifications"]', t);
        if (st.sel !== "n1") await point(rowSel("n1"), t);
        await sleep(1200, t);
        await point(".sim-chead", t); await sleep(1000, t);
        caption("Like a comment, or reply without leaving the app.");
        await point('[data-a="like"][data-v="3"]', t); await sleep(700, t);
        await point('[data-a="reply"][data-v="3"]', t);
        await typeOut("Mostly! I pin one tab and close the rest at lunch.", t);
        await sleep(400, t);
        await point('[data-a="send"]', t); await sleep(2200, t);
      },
    };
    const ORDER = ["notifications", "read", "remind", "keys", "reader", "saved", "cards", "xposts", "comments", "window"];

    async function runTour(names, loop) {
      const t = ++token;
      setPlaying(true);
      try {
        do {
          reset(); await sleep(500, t);
          for (const name of names) await CHAPTERS[name](t);
          if (names.length > 1) caption("That's Dispatch. Your turn: click around, or use j, k, l, s and esc.");
          await sleep(names.length > 1 ? 3000 : 2200, t);
        } while (loop);
        setPlaying(false);
      } catch (e) { if (e !== Cancel) throw e; }
    }
    const play = () => { handedOver = false; runTour(NAMES || ORDER, true); };

    playBtn?.addEventListener("click", () => (playing ? stopTour() : play()));

    // Play while on screen, rest while off it. Reduced motion means no autoplay; Play still works.
    const calm = matchMedia("(prefers-reduced-motion: reduce)").matches;
    new IntersectionObserver((entries) => {
      const now = entries[entries.length - 1].isIntersecting;
      if (now === visible) return;
      visible = now;
      if (STILL) return;
      if (visible && !handedOver && !calm) runTour(NAMES || ORDER, true);
      else if (!visible && playing) halt();
    }, { threshold: 0.45 }).observe(root);

    if (STILL) SCENES[STILL]();
    render();
    setPlaying(false);
    const api = { play, pause: stopTour, chapter: (n) => runTour([n], false), do: A, state: st };
    (window.DispatchSims ||= []).push(api);
    window.DispatchSim ||= api;
  }
})();
