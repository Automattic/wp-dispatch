/* Dispatch simulation for the website.
 *
 * A working copy of the app's menu bar panel, filled with made-up people, blogs and P2s.
 * Visitors can click and use j/k/esc/s/o, and a guided tour drives the same UI with a
 * pretend cursor. Real clicks or keys pause the tour.
 *
 * Programmatic control lives on window.DispatchSim:
 *   DispatchSim.play()               start (or restart) the tour
 *   DispatchSim.pause()
 *   DispatchSim.chapter("comments")  play one chapter: notifications, read, keys, reader, xposts, comments
 *   DispatchSim.do.section("reader"), .feed("p2s"), .select("waits"), .move(1), .comments(), .likePost(), …
 */
(() => {
  const root = document.querySelector("[data-dispatch-sim]");
  if (!root) return;

  // ---------------------------------------------------------------- icons
  const svg = (d, vb = "0 0 16 16") =>
    `<svg viewBox="${vb}" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
  const I = {
    w: `<svg viewBox="0 0 20 20" fill="currentColor"><path d="M10 1.2a8.8 8.8 0 1 0 0 17.6 8.8 8.8 0 0 0 0-17.6Zm-7.6 8.8c0-1.1.2-2.1.6-3.1l3.6 9.9A7.6 7.6 0 0 1 2.4 10Zm7.6 7.6c-.7 0-1.5-.1-2.1-.3l2.3-6.6 2.3 6.4.1.1c-.8.3-1.7.4-2.6.4Zm1-11.2c.5 0 .9-.1.9-.1.4 0 .4-.7 0-.7 0 0-1.2.1-2 .1-.8 0-2-.1-2-.1-.4 0-.5.7 0 .7l.8.1 1.2 3.2-1.7 5-2.8-8.2.9-.1c.4 0 .4-.7 0-.7 0 0-1.2.1-2 .1h-.5A7.6 7.6 0 0 1 15.3 4.6h-.1c-.8 0-1.3.7-1.3 1.4 0 .6.4 1.2.8 1.8.3.5.6 1.2.6 2.2 0 .7-.3 1.5-.6 2.6l-.8 2.7-2.9-8.9Zm2.8 10.2 2.3-6.7c.4-1.1.6-2 .6-2.7l-.1-.8a7.6 7.6 0 0 1-2.8 10.2Z"/></svg>`,
    refresh: svg(`<path d="M13.5 8a5.5 5.5 0 1 1-1.6-3.9M13.5 2.5v3h-3"/>`),
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
    heart: svg(`<path d="M8 13.5S2 10 2 5.8A3 3 0 0 1 8 4.3a3 3 0 0 1 6 1.5C14 10 8 13.5 8 13.5z"/>`),
    heartFill: `<svg viewBox="0 0 16 16" fill="currentColor"><path d="M8 13.5S2 10 2 5.8A3 3 0 0 1 8 4.3a3 3 0 0 1 6 1.5C14 10 8 13.5 8 13.5z"/></svg>`,
    plus: svg(`<path d="M3 3.5A2.5 2.5 0 0 1 5.5 1h5A2.5 2.5 0 0 1 13 3.5v4A2.5 2.5 0 0 1 10.5 10H7l-3 2.5V10A2.5 2.5 0 0 1 3 7.5zM8 3.8v3.4M6.3 5.5h3.4"/>`),
    send: `<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="12" fill="currentColor"/><path d="M12 17V7.5M7.8 11.5 12 7.3l4.2 4.2" stroke="#fff" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
    xpost: svg(`<path d="M3 3v5a2 2 0 0 0 2 2h8M10 7l3 3-3 3"/>`),
    cursor: `<svg viewBox="0 0 18 24"><path d="M1.5 1.5v17.2l4.4-4.1 2.9 6.6 2.9-1.3-2.8-6.4h6.2z" fill="#111" stroke="#fff" stroke-width="1.4" stroke-linejoin="round"/></svg>`,
  };

  // ---------------------------------------------------------------- made-up data
  const ME = { name: "Robin Park", handle: "robin" };
  const P = {
    maya: ["Maya Chen", "#e5397a"], theo: ["Theo Brandt", "#2f9e72"], priya: ["Priya Raman", "#d9822b"],
    sam: ["Sam Ortiz", "#7a5af8"], jules: ["Jules Okafor", "#0e9fb5"], ana: ["Ana Lima", "#c0503a"],
    robin: ["Robin Park", "#3858e9"], lena: ["Lena Vogel", "#8a6d3b"], kofi: ["Kofi Mensah", "#4a7bd0"],
  };
  const S = {
    field: { name: "Field Notes", host: "fieldnotes.blog", color: "#3858e9" },
    slow: { name: "The Slow Web", host: "theslowweb.com", color: "#2f9e72" },
    kettle: { name: "Kettle & Crumb", host: "kettleandcrumb.com", color: "#d9822b" },
    orbit: { name: "Orbit Weekly", host: "orbitweekly.net", color: "#7a5af8" },
    design: { name: "+design", host: "design.p2", color: "#e5397a" },
    mobile: { name: "+mobile", host: "mobile.p2", color: "#0e9fb5" },
  };
  const c = (id, who, text, ago, likes = 0, depth = 0) => ({ id, who, text, ago, likes, liked: false, depth });

  const POSTS = {
    inbox: {
      likes: 12, liked: false,
      site: "field", title: "Notes on a quieter inbox", author: "robin", ago: "2h", read: "3 min",
      excerpt: "For a month I only opened notifications twice a day. Here's what changed, and what I'd keep.",
      body: ["For a month I only opened notifications twice a day: once with coffee, once before signing off. Everything else waited.",
        "The surprise wasn't how much I missed. It was how little. Most things that felt urgent at 10am were already answered by noon.",
        "What I'd keep: skim first, read second. If a headline and two lines don't earn a click, the post can wait for the weekend."],
      comments: [c(1, "maya", "Love this. The bit about batching replies changed my mornings already.", "1h", 3),
        c(2, "robin", "Glad it helped! Coffee and notifications is a strong combo.", "48m", 1, 1),
        c(3, "ana", "Do you keep the browser closed the rest of the day? That's where I slip.", "30m", 2),
        c(4, "sam", "Same question. My tabs are a crime scene.", "12m", 0, 1)],
    },
    crit: {
      likes: 4, liked: false,
      site: "design", title: "Design crit, week 42", author: "theo", ago: "3h", read: "2 min",
      excerpt: "Agenda for Thursday: onboarding illustrations, the new empty states, and menu bar sketches.",
      body: ["Agenda for Thursday's crit, in order:", "1. Onboarding illustrations, final pass. 2. Empty states for search and saved items.",
        "3. @robin can you share the menu bar sketches before Thursday? Rough is fine. We mostly want to talk about density."],
      comments: [c(11, "lena", "I'll bring the empty states. Two directions, one weird.", "2h", 4), c(12, "robin", "Sketches coming tomorrow morning.", "1h", 2, 1)],
    },
    sourdough: {
      likes: 23, liked: false,
      site: "kettle", title: "Sourdough, but lazier", author: "jules", ago: "1d", read: "4 min",
      excerpt: "No stretch-and-folds, no schedule. A loaf that forgives you for forgetting about it.",
      body: ["Every sourdough recipe wants you home all day. This one doesn't. Mix, leave it in the fridge, forget about it for two days.",
        "The long cold rest does the work you'd normally do by hand. You lose a little height and gain a lot of flavor.",
        "Bake it in a hot pot with the lid on for twenty minutes, then lid off until it's darker than you think it should be."],
      comments: [c(21, "priya", "Made it this weekend. My kitchen smells like a bakery and I did nothing.", "20h", 6),
        c(22, "robin", "Does it work with whole wheat?", "8h", 0), c(23, "jules", "Yes! Add a splash more water.", "6h", 3, 1)],
    },
    waits: {
      likes: 9, liked: false,
      site: "slow", title: "The case for software that waits", author: "kofi", ago: "5h", read: "3 min",
      excerpt: "Not every update needs a badge. Some of the best tools just wait until you come back.",
      body: ["Not every update needs a badge. The tools I keep longest are the ones that wait patiently until I come back.",
        "Waiting is a design choice. It says: you decide when this matters. The opposite is a slot machine with a settings page.",
        "Try it for a week: turn the badges off and check in on your own schedule. You can always turn them back on."],
      comments: [c(31, "ana", "Badges off is the best productivity tip nobody wants to hear.", "3h", 5)],
    },
    scopes: {
      likes: 2, liked: false,
      site: "orbit", title: "Seven small telescopes, ranked", author: "lena", ago: "1d", read: "6 min",
      excerpt: "Under 3kg, under $500, and all of them will show you Saturn's rings from a balcony.",
      body: ["Every one of these fits in a backpack, sets up in under five minutes, and will show you Saturn's rings from a city balcony.",
        "The winner isn't the sharpest. It's the one you'll actually carry outside on a weeknight."],
      comments: [],
    },
    train: {
      likes: 6, liked: false,
      site: "mobile", title: "Release train 4.2 is boarding", author: "sam", ago: "4h", read: "2 min",
      excerpt: "Code freeze Friday. Release notes due Monday. Here's the checklist.",
      body: ["Code freeze is Friday at noon. Anything not merged by then rides the next train, no hard feelings.",
        "Release notes are due Monday. If your change is user-visible, a single plain sentence is perfect."],
      comments: [c(41, "kofi", "Notes for the offline mode fix are in the doc.", "2h", 1)],
      xpost: { from: "mobile", to: "design" },
    },
    icons: {
      likes: 3, liked: false,
      site: "design", title: "Icon refresh: round two", author: "lena", ago: "6h", read: "2 min",
      excerpt: "Thinner strokes, rounder joins. Feedback welcome until Wednesday.",
      body: ["Round two of the icon refresh is up. Strokes are thinner and the joins are rounder.", "Feedback welcome until Wednesday."],
      comments: [],
    },
  };

  const NOTES = [
    { id: "n1", kind: "comment", who: "maya", action: "commented on", post: "inbox", ago: "1h", text: "Love this. The bit about batching replies changed my mornings already.", unread: true },
    { id: "n2", kind: "mention", who: "theo", action: "mentioned you on", post: "crit", ago: "3h", text: "…@robin can you share the menu bar sketches before Thursday?", unread: true },
    { id: "n3", kind: "like", who: "priya", action: "and 4 others liked", post: "inbox", ago: "4h", text: "", unread: true },
    { id: "n4", kind: "comment", who: "jules", action: "replied to you on", post: "sourdough", ago: "6h", text: "Yes! Add a splash more water.", unread: false },
    { id: "n5", kind: "follow", who: "ana", action: "followed", site: "field", ago: "1d", text: "", unread: false },
    { id: "n6", kind: "like", who: "sam", action: "liked your comment on", post: "crit", ago: "1d", text: "", unread: false },
  ];
  const FEEDS = {
    blogs: ["waits", "sourdough", "scopes", "inbox"],
    p2s: ["train", "crit", "icons"],
  };

  // ---------------------------------------------------------------- state
  const st = {
    open: true, section: "notifications", filter: "all", feed: "blogs",
    sel: null, commentsOpen: false, replyTo: null, draft: "", typing: false,
    saved: new Set(), read: new Set(),
  };
  const items = () => {
    if (st.section === "notifications") return NOTES.filter((n) => st.filter === "all" || (n.unread && !st.read.has(n.id)));
    if (st.feed === "saved") return [...st.saved];
    return FEEDS[st.feed];
  };
  const postFor = (item) => (st.section === "notifications" ? POSTS[item.post] : POSTS[item]);
  const keyOf = (item) => (typeof item === "string" ? item : item.id);

  // ---------------------------------------------------------------- markup
  const esc = (s) => s.replace(/[&<>"]/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[ch]));
  const av = (who, cls = "sim-av") => `<div class="${cls}" style="background:${P[who][1]}">${P[who][0].split(" ").map((w) => w[0]).join("")}</div>`;
  const siteIcon = (site, extra = "") => `<div class="sim-site ${extra}" style="background:${S[site].color}">${S[site].name.replace("+", "")[0].toUpperCase()}</div>`;
  const marked = (text) => esc(text).replace(/@robin|Robin/g, (m) => `<mark>${m}</mark>`);

  root.innerHTML = `
    <div class="sim" tabindex="0" aria-label="Interactive demo of Dispatch">
      <div class="sim-menubar"><span class="apple"></span><b>Finder</b><span>File</span><span>Edit</span><span>View</span>
        <span class="spacer"></span><button class="sim-w on" data-a="toggle" title="Dispatch">${I.w}</button><span>Tue 9:41</span></div>
      <div class="sim-panel">
        <div class="sim-detail"></div>
        <div class="sim-list">
          <div class="sim-head"></div>
          <div class="sim-filters"></div>
          <div class="sim-rows"><div class="sim-rows-inner"></div></div>
        </div>
        <div class="sim-handle"></div>
      </div>
      <div class="sim-key"></div>
      <div class="sim-cursor">${I.cursor}</div>
    </div>`;
  const $ = (s) => root.querySelector(s);
  const sim = $(".sim"), panel = $(".sim-panel"), detail = $(".sim-detail"), rows = $(".sim-rows-inner");
  const cursor = $(".sim-cursor"), keyHint = $(".sim-key");

  function renderHead() {
    const unread = NOTES.filter((n) => n.unread && !st.read.has(n.id)).length;
    $(".sim-head").innerHTML = `
      <button class="sim-tab ${st.section === "notifications" ? "on" : ""}" data-a="section" data-v="notifications">Notifications${unread ? `<span class="sim-badge">${unread}</span>` : ""}</button>
      <button class="sim-tab ${st.section === "reader" ? "on" : ""}" data-a="section" data-v="reader">Reader</button>
      <span class="spacer"></span>
      <button class="sim-icon" data-a="toast" data-v="Refreshed" title="Refresh">${I.refresh}</button>
      <button class="sim-icon" data-a="toast" data-v="Pops out into its own window" title="Pop out">${I.popout}</button>
      <button class="sim-icon" data-a="toast" data-v="Open on WordPress.com · Check for Updates… · Sign out" title="More">${I.more}</button>`;
  }

  let thumb = null;
  function renderFilters() {
    const opts = st.section === "notifications"
      ? [["all", "All"], ["unread", "Unread"]]
      : [["blogs", "Following"], ["p2s", "Automattic"], ["saved", `${I.markFill.replace("<svg", '<svg width="9" height="10"')} Saved`]];
    const cur = st.section === "notifications" ? st.filter : st.feed;
    const box = $(".sim-filters");
    box.innerHTML = `<div class="sim-pills"><div class="sim-pill-thumb"></div>${opts.map(([v, label]) =>
      `<button class="sim-pill ${v === cur ? "on" : ""}" data-a="${st.section === "notifications" ? "filter" : "feed"}" data-v="${v}">${label}</button>`).join("")}</div>`;
    const on = box.querySelector(".sim-pill.on"), t = box.querySelector(".sim-pill-thumb");
    // Slide from where the thumb was, unless the pill set itself changed.
    if (thumb && thumb.section === st.section) { t.style.left = thumb.left + "px"; t.style.width = thumb.width + "px"; t.getBoundingClientRect(); }
    t.style.left = on.offsetLeft + "px"; t.style.width = on.offsetWidth + "px";
    thumb = { section: st.section, left: on.offsetLeft, width: on.offsetWidth };
  }

  function noteRow(n) {
    const post = n.post && POSTS[n.post];
    const title = post ? post.title : S[n.site].name;
    const unread = n.unread && !st.read.has(n.id);
    return `<div class="sim-row ${unread ? "unread" : ""} ${st.sel === n.id ? "on" : ""}" data-a="select" data-v="${n.id}">
      ${av(n.who)}
      <div class="main">
        <div class="top"><div class="who"><b>${P[n.who][0]}</b> <span>${n.action}</span></div><div class="time">${n.ago}</div></div>
        <div class="title">${esc(title)}</div>
        ${n.text ? `<div class="ex">${marked(n.text)}</div>` : ""}
      </div>
      <div class="sim-dot ${unread ? "" : "read"}"></div>
    </div>`;
  }
  function postRow(k) {
    const p = POSTS[k], on = st.sel === k ? "on" : "";
    if (p.xpost) {
      return `<div class="sim-row compact sim-xrow ${on}" data-a="select" data-v="${k}">
        <div style="position:relative">${siteIcon(p.xpost.from, "small")}<div class="sim-xbadge">${I.xpost}</div></div>
        <div class="main"><div class="top"><div class="who"><b>${S[p.xpost.from].name}</b> → ${S[p.xpost.to].name}</div><div class="time">${p.ago}</div></div>
        <div class="title" style="font-size:12px">${esc(p.title)}</div></div></div>`;
    }
    return `<div class="sim-row ${on}" data-a="select" data-v="${k}">
      ${siteIcon(p.site)}
      <div class="main">
        <div class="top"><div class="who"><b>${S[p.site].name}</b></div><div class="time">${p.ago}</div></div>
        <div class="title">${esc(p.title)}</div>
        <div class="ex">${esc(p.excerpt)}</div>
        <div class="foot">${P[p.author][0]} · ${p.read}${p.likes ? ` · <span class="sim-likes ${p.liked ? "liked" : ""}">${p.liked ? I.heartFill : I.heart}${p.likes}</span>` : ""}</div>
      </div></div>`;
  }
  function renderRows(swap) {
    const list = items();
    const html = list.length
      ? list.map((it) => (st.section === "notifications" ? noteRow(it) : postRow(it))).join("")
      : `<div class="sim-placeholder" style="height:300px">${st.feed === "saved" ? "Nothing saved yet.<br>Press s on a post to save it." : "You're all caught up."}</div>`;
    if (!swap) { rows.innerHTML = html; return; }
    rows.classList.add("swap");
    setTimeout(() => { rows.innerHTML = html; rows.classList.remove("swap"); }, 140);
  }

  function selected() {
    const list = items();
    const i = list.findIndex((it) => keyOf(it) === st.sel);
    return i < 0 ? null : { item: list[i], index: i, count: list.length };
  }

  function renderDetail() {
    const s = selected();
    if (!s) { detail.innerHTML = `<div class="sim-placeholder">Pick something to read</div>`; return; }
    const p = postFor(s.item);
    if (!p) { // a follow: there's no post to read
      detail.innerHTML = toolbar(s, null) + `<div class="sim-article"><div class="eyebrow">${S[s.item.site].name}</div><h3>${P[s.item.who][0]} followed your blog</h3><div class="sim-byline">${av(s.item.who)} <b>${P[s.item.who][0]}</b></div></div>`;
      return;
    }
    const origin = p.xpost ? `<div class="sim-notice">X-post from <b>${S[p.xpost.from].name}</b>. You're reading the original.</div>` : "";
    detail.innerHTML = toolbar(s, p) + `
      <div class="sim-article">
        ${origin}
        <div class="eyebrow"><a>${S[p.site].name}</a></div>
        <h3>${esc(p.title)}</h3>
        <div class="sim-byline">${av(p.author)} <b>${P[p.author][0]}</b> · ${S[p.site].host} · ${p.ago} ago</div>
        <span class="sim-chip">${p.read === "2 min" || p.read === "3 min" ? "Quick read" : p.read + " read"}</span>
        <div class="body">${p.body.map((t) => `<p>${marked(t)}</p>`).join("")}</div>
      </div>
      <div class="sim-comments ${st.commentsOpen ? "open" : ""}"></div>`;
    renderComments(true);
  }
  function toolbar(s, p) {
    const reader = st.section === "reader" && p;
    return `<div class="sim-dhead">
      <button class="sim-icon" data-a="close" title="Close (esc)">${I.x}</button>
      ${reader ? `<button class="sim-like ${p.liked ? "liked" : ""}" data-a="likePost" title="Like (l)">${p.liked ? I.heartFill : I.heart}${p.likes ? `<span>${p.likes}</span>` : ""}</button>
      <button class="sim-icon ${st.saved.has(s.item) ? "on" : ""}" data-a="save" title="Save (s)">${st.saved.has(s.item) ? I.markFill : I.mark}</button>` : ""}
      <button class="sim-icon" data-a="toast" data-v="Opens in your browser" title="Open in browser (o)">${I.safari}</button>
      <span class="spacer"></span>
      <span class="sim-pos">${s.index + 1} of ${s.count}</span>
      <button class="sim-icon" data-a="move" data-v="-1" title="Previous (k)">${I.up}</button>
      <button class="sim-icon" data-a="move" data-v="1" title="Next (j)">${I.down}</button>
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
    const head = `<button class="sim-chead" data-a="comments">${I.bubbles}<span>${n === 0 ? "Add a comment" : n === 1 ? "1 comment" : n + " comments"}</span><span class="spacer"></span>${I.chev}</button>`;
    if (!st.commentsOpen) {
      box.innerHTML = head + (n ? `<div class="sim-strip">${list.map((cm, i) =>
        `<div class="sim-cmt" style="animation-delay:${first ? i * 45 : 0}ms">${av(cm.who)}<div class="sim-bubble"><span class="clamp">${esc(cm.text)}</span></div></div>`).join("")}
        <button class="sim-add" data-a="reply" data-v="" title="Add a comment">${I.plus}</button></div>` : "");
      return;
    }
    box.innerHTML = head + `<div class="sim-clist">${list.map((cm) => `
      <div style="padding-left:${Math.min(cm.depth, 3) * 24}px">
        <div class="sim-cmt ${cm.fresh ? "" : "settled"}" style="${cm.fresh ? "" : "animation:none"}">${av(cm.who)}<div class="sim-bubble"><div class="name">${P[cm.who][0]}<span>${cm.ago}</span></div>${marked(cm.text)}</div></div>
        <div class="sim-acts"><button class="${cm.liked ? "liked" : ""}" data-a="like" data-v="${cm.id}">${cm.liked ? I.heartFill : I.heart}${cm.likes ? cm.likes : ""}</button>
        <button class="${st.replyTo === cm.id ? "replying" : ""}" data-a="reply" data-v="${cm.id}">Reply</button></div>
      </div>`).join("")}</div>
      <div class="sim-composer">
        ${st.replyTo ? `<div class="sim-replyto">↩ Replying to ${P[list.find((x) => x.id === st.replyTo).who][0]}</div>` : ""}
        <div class="sim-field"><div class="sim-input ${st.typing ? "typing" : ""}">${st.draft ? esc(st.draft) : st.typing ? "" : st.replyTo ? "Write a reply…" : "Add a comment…"}</div>
        <button class="sim-send ${st.draft ? "ready" : ""}" data-a="send" title="Send (⌘↩)">${I.send}</button></div>
      </div>`;
    list.forEach((cm) => delete cm.fresh);
    const cl = box.querySelector(".sim-clist");
    if (cl) cl.scrollTop = st.scrollTo === "end" ? cl.scrollHeight : 0;
    st.scrollTo = null;
  }

  function render(swapRows) {
    panel.classList.toggle("hidden", !st.open);
    $(".sim-w").classList.toggle("on", st.open);
    panel.classList.toggle("wide", st.sel !== null);
    renderHead(); renderFilters(); renderRows(swapRows); renderDetail();
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
    feed(v) { st.feed = v; st.sel = null; render(true); },
    tab(d) {
      if (st.section !== "reader") return;
      const tabs = ["blogs", "p2s", "saved"], next = tabs[Math.min(Math.max(tabs.indexOf(st.feed) + d, 0), 2)];
      if (next !== st.feed) A.feed(next);
    },
    select(v) {
      st.sel = v; st.commentsOpen = false; st.replyTo = null; st.draft = "";
      if (st.section === "notifications") st.read.add(v);
      render();
    },
    move(d) {
      const list = items(); if (!list.length) return;
      const i = list.findIndex((it) => keyOf(it) === st.sel);
      const next = Math.max(0, Math.min(list.length - 1, i < 0 ? 0 : i + Number(d)));
      A.select(keyOf(list[next]));
    },
    close() {
      if (st.sel !== null) { st.sel = null; st.commentsOpen = false; render(); }
      else { st.open = false; render(); }
    },
    comments() { st.commentsOpen = !st.commentsOpen; st.replyTo = null; renderComments(true); },
    like(v) {
      const s = selected(); const cm = s && postFor(s.item).comments.find((x) => x.id === Number(v)); if (!cm) return;
      cm.liked = !cm.liked; cm.likes += cm.liked ? 1 : -1; renderComments();
    },
    reply(v) {
      st.replyTo = v ? Number(v) : null; st.typing = true;
      sim.focus({ preventScroll: true });
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
      p.liked = !p.liked; p.likes += p.liked ? 1 : -1;
      renderRows(); renderDetail();
    },
    save() {
      const s = selected(); if (!s || st.section !== "reader") return;
      st.saved.has(s.item) ? st.saved.delete(s.item) : st.saved.add(s.item);
      hint(st.saved.has(s.item) ? "Saved" : "Removed from Saved"); renderDetail();
    },
    toast(v) { hint(v, 1800); },
  };

  // Clicks: real ones pause the tour; the tour's own are synthetic (isTrusted false).
  sim.addEventListener("click", (e) => {
    const el = e.target.closest("[data-a]");
    if (e.isTrusted) stopTour();
    if (!el) return;
    A[el.dataset.a](el.dataset.v);
  });
  sim.addEventListener("keydown", (e) => {
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
    const k = { j: ["move", 1], ArrowDown: ["move", 1], k: ["move", -1], ArrowUp: ["move", -1], ArrowLeft: ["tab", -1], ArrowRight: ["tab", 1], Escape: ["close"], s: ["save"], l: ["likePost"], o: ["toast", "Opens in your browser"] }[e.key];
    if (!k) return;
    e.preventDefault();
    if (e.isTrusted) stopTour();
    A[k[0]](k[1]);
  });

  // ---------------------------------------------------------------- scale to fit
  // Wide screens show the whole 1000×600 desk. Phones get a camera that follows the
  // action: the list, then the reader when something is open.
  const CAMERA = { list: { x: 570, y: 26, w: 420, h: 570 }, reader: { x: 30, y: 26, w: 560, h: 570 } };
  function fit() {
    const width = root.clientWidth;
    let scale, x = 0, y = 0, h;
    if (width >= 700) {
      scale = Math.min(1, width / 1000); h = 600 * scale;
    } else {
      const r = st.open && st.sel !== null ? CAMERA.reader : CAMERA.list;
      scale = width / r.w; x = -r.x * scale; y = -r.y * scale; h = r.h * scale;
    }
    sim.style.transform = `translate(${x}px, ${y}px) scale(${scale})`;
    root.style.height = h + "px";
    st.scale = scale;
  }
  new ResizeObserver(() => fit()).observe(root);
  fit();
  requestAnimationFrame(() => sim.classList.add("ready")); // animate the camera only after the first fit

  // ---------------------------------------------------------------- tour
  const captionEl = document.querySelector("[data-sim-caption]");
  const playBtn = document.querySelector("[data-sim-play]");
  let token = 0, playing = false, started = false;
  const Cancel = Symbol("cancel");
  const sleep = (ms, t) => new Promise((ok, fail) => setTimeout(() => (t === token ? ok() : fail(Cancel)), ms));

  function caption(text) {
    if (!captionEl) return;
    captionEl.classList.add("fade");
    setTimeout(() => { captionEl.textContent = text; captionEl.classList.remove("fade"); }, 220);
  }
  function setPlaying(on) {
    playing = on;
    if (playBtn) playBtn.innerHTML = on
      ? `<svg viewBox="0 0 12 12" fill="currentColor"><rect x="2" y="1.5" width="3" height="9" rx="1"/><rect x="7" y="1.5" width="3" height="9" rx="1"/></svg> Pause tour`
      : `<svg viewBox="0 0 12 12" fill="currentColor"><path d="M3 1.5v9l7.5-4.5z"/></svg> Play tour`;
    cursor.classList.toggle("show", on);
    document.querySelectorAll("[data-chapter]").forEach((li) => li.classList.toggle("playing", false));
  }
  function stopTour() { started = true; if (!playing) return; token++; setPlaying(false); caption("Your turn. Click around, or use j, k, l, s and esc."); }

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
    Object.assign(st, { open: true, section: "notifications", filter: "all", feed: "blogs", sel: null, commentsOpen: false, replyTo: null, draft: "", typing: false });
    st.read.clear(); st.saved.clear();
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
      await point(".sim-article mark", t, { click: false }); await sleep(1800, t);
    },
    async keys(t) {
      caption("Skim with the keyboard: j and k move through the list, esc closes the reader.");
      if (st.sel === null) await point(rowSel("n1"), t);
      await key("j", t); await key("j", t); await key("k", t); await sleep(500, t);
      await key("Escape", t); await sleep(500, t);
    },
    async reader(t) {
      caption("The Reader: the blogs you follow, with reading times so you know what you're getting into.");
      await point('.sim-tab[data-v="reader"]', t); await sleep(900, t);
      await point(rowSel("waits"), t); await sleep(1500, t);
      caption("Like a post with a click (or l). Save it for later with s.");
      await point('[data-a="likePost"]', t); await sleep(900, t);
      await point('[data-a="save"]', t); await sleep(900, t);
      await point('.sim-pill[data-v="saved"]', t); await sleep(1200, t);
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
  const ORDER = ["notifications", "read", "keys", "reader", "xposts", "comments"];

  async function runTour(names, loop) {
    started = true;
    const t = ++token;
    setPlaying(true);
    try {
      do {
        reset(); await sleep(500, t);
        for (const name of names) {
          document.querySelectorAll("[data-chapter]").forEach((li) => li.classList.toggle("playing", li.dataset.chapter === name));
          await CHAPTERS[name](t);
        }
        caption("That's Dispatch. Your turn: click around, or use j, k, l, s and esc.");
        await sleep(3000, t);
      } while (loop);
      setPlaying(false);
    } catch (e) { if (e !== Cancel) throw e; }
  }

  playBtn?.addEventListener("click", () => (playing ? stopTour() : runTour(ORDER, true)));
  document.querySelectorAll("[data-chapter]").forEach((li) =>
    li.addEventListener("click", () => {
      token++;
      root.scrollIntoView({ behavior: "smooth", block: "center" });
      runTour([li.dataset.chapter], false);
    }));

  // Start the tour the first time the demo scrolls into view (unless someone got there first).
  new IntersectionObserver((entries) => {
    if (!started && entries.some((e) => e.isIntersecting)) {
      started = true;
      if (!matchMedia("(prefers-reduced-motion: reduce)").matches) runTour(ORDER, true);
    }
  }, { threshold: 0.5 }).observe(root);

  render();
  setPlaying(false);
  window.DispatchSim = { play: () => runTour(ORDER, true), pause: stopTour, chapter: (n) => runTour([n], false), do: A, state: st };
})();
