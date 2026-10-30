/* Dispatch simulation for the website.
 *
 * A working copy of the app's menu bar panel, filled with made-up people, blogs and P2s.
 * Every [data-dispatch-sim] element becomes its own stage. Its value names the tour chapters
 * it plays (all of them when empty), on a loop while it's on screen. Visitors can click and
 * use j/k/esc/s/o; a real click or key hands the stage over until Play is pressed again.
 * The stage's caption and Play button are found inside its [data-sim-row].
 *
 * Programmatic control lives on window.DispatchSims (one per stage; DispatchSim is the first):
 *   DispatchSim.play()               start (or restart) the tour
 *   DispatchSim.pause()
 *   DispatchSim.chapter("comments")  play one chapter: notifications, read, keys, reader, cards, xposts, comments
 *   DispatchSim.do.section("reader"), .feed("p2s"), .site("kettle"), .select("waits"), .move(1), .comments(), .likePost(), …
 */
(() => {
  document.querySelectorAll("[data-dispatch-sim]").forEach(mount);

  // One stage. Everything below, made-up data included, is per stage, so stages don't share likes or replies.
  function mount(root) {
    // ---------------------------------------------------------------- icons
    const svg = (d, w = 1.5) =>
      `<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round">${d}</svg>`;
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
        mention: `<svg viewBox="0 0 16 16" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"><circle cx="8" cy="8" r="2.6"/><path d="M10.6 5.6v3.3c0 1.3 1 2 2 2s1.9-.9 1.9-2.9A6.5 6.5 0 1 0 11 13.7"/></svg>`,
        like: `<svg viewBox="0 0 16 16" fill="currentColor"><path d="M8 .9l2.2 4.5 5 .7-3.6 3.5.9 4.9L8 12.2l-4.5 2.3.9-4.9L.8 6.1l5-.7z"/></svg>`,
        follow: `<svg viewBox="0 0 16 16" fill="currentColor"><circle cx="8" cy="4.6" r="3.3"/><path d="M1.5 15c0-3.6 2.9-6 6.5-6s6.5 2.4 6.5 6z"/></svg>`,
      },
      cursor: `<svg viewBox="0 0 18 24"><path d="M1.5 1.5v17.2l4.4-4.1 2.9 6.6 2.9-1.3-2.8-6.4h6.2z" fill="#111" stroke="#fff" stroke-width="1.4" stroke-linejoin="round"/></svg>`,
    };

    const VERSION = "0.4.0"; // release.sh keeps this in step with the app
    const DESK_H = 690; // the desk (wallpaper, menu bar, panel and Dock) is 1000 wide; match .sim in sim.css

    // ---------------------------------------------------------------- made-up data
    const ME = { name: "Robin Park", handle: "robin" };
    const P = {
      maya: ["Maya Chen", "#e5397a"], theo: ["Theo Brandt", "#2f9e72"], priya: ["Priya Raman", "#d9822b"],
      sam: ["Sam Ortiz", "#7a5af8"], jules: ["Jules Okafor", "#0e9fb5"], ana: ["Ana Lima", "#c0503a"],
      robin: ["Robin Park", "#3858e9"], lena: ["Lena Vogel", "#8a6d3b"], kofi: ["Kofi Mensah", "#4a7bd0"],
    };
    // What a hovercard shows: a Gravatar-style profile, or a site's Reader info.
    const CARD = {
      maya: { pronouns: "she/her", work: "Product designer", place: "Lisbon", bio: "Draws interfaces, bakes bread, answers email twice a day." },
      theo: { pronouns: "he/him", work: "Design lead", place: "Berlin", bio: "Runs Thursday crit. Bring sketches, not slides." },
      priya: { pronouns: "she/her", work: "Engineer", place: "Bengaluru", bio: "Writes code in the morning and about food at night." },
      sam: { pronouns: "they/them", work: "Release manager", place: "Austin", bio: "Keeps the trains running on time." },
      jules: { pronouns: "he/him", work: "Baker, writer", place: "Dublin", bio: "Kettle & Crumb. Lazy loaves for busy people." },
      ana: { pronouns: "she/her", work: "Researcher", place: "São Paulo", bio: "Studies how people actually use their tabs." },
      robin: { pronouns: "they/them", work: "Designer", place: "Portland", bio: "Writes Field Notes. Trying to make software quieter." },
      lena: { pronouns: "she/her", work: "Illustrator", place: "Vienna", bio: "Icons, empty states and the occasional telescope review." },
      kofi: { pronouns: "he/him", work: "Writer", place: "Accra", bio: "Essays about calm technology at The Slow Web." },
    };
    const S = {
      field: { name: "Field Notes", host: "fieldnotes.blog", color: "#3858e9", about: "Notes on working calmly, by Robin Park.", subs: 1284, posts: 212 },
      slow: { name: "The Slow Web", host: "theslowweb.com", color: "#2f9e72", about: "Essays on software that respects your attention.", subs: 18420, posts: 340 },
      kettle: { name: "Kettle & Crumb", host: "kettleandcrumb.com", color: "#d9822b", about: "Forgiving recipes for people who forget about their dough.", subs: 6310, posts: 158 },
      orbit: { name: "Orbit Weekly", host: "orbitweekly.net", color: "#7a5af8", about: "Backyard astronomy, one clear night at a time.", subs: 2975, posts: 96 },
      design: { name: "+design", host: "design.p2", color: "#e5397a", about: "Crit notes, sketches and decisions from the design team.", posts: 640 },
      mobile: { name: "+mobile", host: "mobile.p2", color: "#0e9fb5", about: "Release trains and mobile app news.", posts: 412 },
    };
    const c = (id, who, text, ago, likes = 0, depth = 0) => ({ id, who, text, ago, likes, liked: false, depth });

    const POSTS = {
      inbox: {
        likes: 12, liked: false, likers: ["maya", "priya", "ana", "theo"],
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
        likes: 4, liked: false, likers: ["lena", "sam"],
        site: "design", title: "Design crit, week 42", author: "theo", ago: "3h", read: "2 min",
        excerpt: "Agenda for Thursday: onboarding illustrations, the new empty states, and menu bar sketches.",
        body: ["Agenda for Thursday's crit, in order:", "1. Onboarding illustrations, final pass. 2. Empty states for search and saved items.",
          "3. @robin can you share the menu bar sketches before Thursday? Rough is fine. We mostly want to talk about density."],
        comments: [c(11, "lena", "I'll bring the empty states. Two directions, one weird.", "2h", 4), c(12, "robin", "Sketches coming tomorrow morning.", "1h", 2, 1)],
      },
      sourdough: {
        likes: 23, liked: false, likers: ["priya", "maya", "kofi", "ana"],
        site: "kettle", title: "Sourdough, but lazier", author: "jules", ago: "1d", read: "4 min",
        excerpt: "No stretch-and-folds, no schedule. A loaf that forgives you for forgetting about it.",
        body: ["Every sourdough recipe wants you home all day. This one doesn't. Mix, leave it in the fridge, forget about it for two days.",
          "The long cold rest does the work you'd normally do by hand. You lose a little height and gain a lot of flavor.",
          "Bake it in a hot pot with the lid on for twenty minutes, then lid off until it's darker than you think it should be."],
        comments: [c(21, "priya", "Made it this weekend. My kitchen smells like a bakery and I did nothing.", "20h", 6),
          c(22, "robin", "Does it work with whole wheat?", "8h", 0), c(23, "jules", "Yes! Add a splash more water.", "6h", 3, 1)],
      },
      waits: {
        likes: 9, liked: false, likers: ["ana", "jules", "maya"],
        site: "slow", title: "The case for software that waits", author: "kofi", ago: "5h", read: "3 min",
        excerpt: "Not every update needs a badge. Some of the best tools just wait until you come back.",
        body: ["Not every update needs a badge. The tools I keep longest are the ones that wait patiently until I come back.",
          "Waiting is a design choice. It says: you decide when this matters. The opposite is a slot machine with a settings page.",
          "Try it for a week: turn the badges off and check in on your own schedule. You can always turn them back on."],
        comments: [c(31, "ana", "Badges off is the best productivity tip nobody wants to hear.", "3h", 5)],
      },
      scopes: {
        likes: 2, liked: false, likers: ["kofi", "theo"],
        site: "orbit", title: "Seven small telescopes, ranked", author: "lena", ago: "1d", read: "6 min",
        excerpt: "Under 3kg, under $500, and all of them will show you Saturn's rings from a balcony.",
        body: ["Every one of these fits in a backpack, sets up in under five minutes, and will show you Saturn's rings from a city balcony.",
          "The winner isn't the sharpest. It's the one you'll actually carry outside on a weeknight."],
        comments: [],
      },
      train: {
        likes: 6, liked: false, likers: ["kofi", "theo"],
        site: "mobile", title: "Release train 4.2 is boarding", author: "sam", ago: "4h", read: "2 min",
        excerpt: "Code freeze Friday. Release notes due Monday. Here's the checklist.",
        body: ["Code freeze is Friday at noon. Anything not merged by then rides the next train, no hard feelings.",
          "Release notes are due Monday. If your change is user-visible, a single plain sentence is perfect."],
        comments: [c(41, "kofi", "Notes for the offline mode fix are in the doc.", "2h", 1)],
        xpost: { from: "mobile", to: "design" },
      },
      icons: {
        likes: 3, liked: false, likers: ["theo", "maya"],
        site: "design", title: "Icon refresh: round two", author: "lena", ago: "6h", read: "2 min",
        excerpt: "Thinner strokes, rounder joins. Feedback welcome until Wednesday.",
        body: ["Round two of the icon refresh is up. Strokes are thinner and the joins are rounder.", "Feedback welcome until Wednesday."],
        comments: [],
      },
    };

    // Older posts, only seen when the Reader shows one site.
    Object.assign(POSTS, {
      focaccia: {
        likes: 14, liked: false, likers: ["maya", "sam"],
        site: "kettle", title: "Weeknight focaccia", author: "jules", ago: "4d", read: "2 min",
        excerpt: "Stir it at breakfast, bake it at dinner. The fridge does the rest.",
        body: ["Stir flour, water, salt and yeast together at breakfast. Cover it and put it in the fridge.",
          "At dinner, tip it into an oiled pan, poke it all over and bake it hot until the top is deep gold."],
        comments: [c(51, "priya", "Rosemary and flaky salt. That's the whole review.", "3d", 2)],
      },
      material: {
        likes: 31, liked: false, likers: ["ana", "lena", "theo"],
        site: "slow", title: "Notifications are a design material", author: "kofi", ago: "6d", read: "5 min",
        excerpt: "Every ping is a decision someone made about your attention. We can make better ones.",
        body: ["Every ping is a decision someone made about your attention, usually without asking you.",
          "Treat notifications like any other material: choose them on purpose, and use as few as you can."],
        comments: [],
      },
    });

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
      site: null, // the Reader showing one site's posts (from a hovercard, or a post's site name)
      menu: false, saved: new Set(), read: new Set(),
    };
    const items = () => {
      if (st.section === "notifications") return NOTES.filter((n) => st.filter === "all" || (n.unread && !st.read.has(n.id)));
      if (st.site) return Object.keys(POSTS).filter((k) => POSTS[k].site === st.site && !POSTS[k].xpost);
      if (st.feed === "saved") return [...st.saved];
      return FEEDS[st.feed];
    };
    const postFor = (item) => (st.section === "notifications" ? POSTS[item.post] : POSTS[item]);
    const keyOf = (item) => (typeof item === "string" ? item : item.id);

    // ---------------------------------------------------------------- markup
    const esc = (s) => s.replace(/[&<>"]/g, (ch) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[ch]));
    const initials = (who) => P[who][0].split(" ").map((w) => w[0]).join("");
    // `data-card` opens a hovercard: person:<who> or site:<site>.
    const av = (who, cls = "sim-av", card = true) =>
      `<div class="${cls}" style="--c:${P[who][1]}"${card ? ` data-card="person:${who}"` : ""}>${initials(who)}</div>`;
    const siteIcon = (site, extra = "") => `<div class="sim-site ${extra}" style="--c:${S[site].color}" data-card="site:${site}">${S[site].name.replace("+", "")[0].toUpperCase()}</div>`;
    const marked = (text) => esc(text).replace(/@robin|Robin/g, (m) => `<mark>${m}</mark>`);
    const unreadCount = () => NOTES.filter((n) => n.unread && !st.read.has(n.id)).length;
    const KIND = { comment: "#0a84ff", mention: "#ff9500", like: "#ff2d55", follow: "#34c759" };

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
        <div class="sim-dock">${["#5ac8fa", "#ff9f0a", "#34c759", "#af52de", "#ff375f", "#8e8e93", "#3858e9", "#ffd60a"]
          .map((c) => `<span style="--c:${c}"></span>`).join("")}</div>
        <div class="sim-menu"></div>
        <div class="sim-card"></div>
        <div class="sim-key"></div>
        <div class="sim-cursor">${I.cursor}</div>
      </div>`;
    const $ = (s) => root.querySelector(s);
    const sim = $(".sim"), panel = $(".sim-panel"), detail = $(".sim-detail"), rows = $(".sim-rows-inner");
    const cursor = $(".sim-cursor"), keyHint = $(".sim-key"), menu = $(".sim-menu"), card = $(".sim-card");

    function renderHead() {
      const unread = unreadCount();
      $(".sim-head").innerHTML = `
        <button class="sim-tab ${st.section === "notifications" ? "on" : ""}" data-a="section" data-v="notifications">Notifications${unread ? `<span class="sim-badge">${unread}</span>` : ""}</button>
        <button class="sim-tab ${st.section === "reader" ? "on" : ""}" data-a="section" data-v="reader">Reader</button>
        <span class="spacer"></span>
        <button class="sim-icon" data-a="toast" data-v="Refreshed" title="Refresh">${I.refresh}</button>
        <button class="sim-icon" data-a="toast" data-v="Pops out into its own window" title="Pop out into a window">${I.popout}</button>
        <button class="sim-icon ${st.menu ? "on" : ""}" data-a="menu" title="More">${I.more}</button>`;
    }

    // The ⋯ menu, as in the app.
    function renderMenu() {
      menu.classList.toggle("show", st.menu);
      if (!st.menu) return;
      const item = (label, tip) => `<button data-a="menuItem" data-v="${tip}">${label}</button>`;
      menu.innerHTML = item("Open on WordPress.com", "Opens WordPress.com in your browser") + "<hr>"
        + item("Check for Updates…", "You're on the latest version") + `<div class="dim">Dispatch ${VERSION}</div><hr>`
        + item("Sign out", "Signs out of WordPress.com") + item("Restart", "Restarts Dispatch") + item("Quit", "Quits Dispatch");
    }

    let thumb = null;
    function renderFilters() {
      const box = $(".sim-filters");
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
      box.innerHTML = `<div class="sim-pills"><div class="sim-pill-thumb"></div>${opts.map(([v, label]) =>
        `<button class="sim-pill ${v === cur ? "on" : ""}" data-a="${st.section === "notifications" ? "filter" : "feed"}" data-v="${v}">${label}</button>`).join("")}</div>
        <span class="spacer"></span>
        ${st.section === "notifications" ? `<button class="sim-icon" data-a="markAll" title="Mark all as read" ${unread ? "" : "disabled"}>${I.check}</button>` : ""}`;
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
      return `<div class="sim-row note ${unread ? "unread" : ""} ${st.sel === n.id ? "on" : ""}" data-a="select" data-v="${n.id}">
        <div class="sim-dot"></div>
        <div class="sim-avwrap">${av(n.who, "sim-av big")}<span class="sim-kind" style="background:${KIND[n.kind]}">${I.kind[n.kind]}</span></div>
        <div class="main">
          <div class="top"><div class="who"><b>${P[n.who][0]}</b> <span>${n.action}</span></div><div class="time">${n.ago}</div></div>
          <div class="title">${esc(title)}</div>
          ${n.text ? `<div class="ex">${marked(n.text)}</div>` : ""}
        </div>
      </div>`;
    }
    function postRow(k) {
      const p = POSTS[k], on = st.sel === k ? "on" : "";
      const saved = st.saved.has(k) ? `<span class="sim-saved">${I.markFill}</span>` : "";
      if (p.xpost) {
        return `<div class="sim-row compact sim-xrow ${on}" data-a="select" data-v="${k}">
          <div class="sim-avwrap x">${siteIcon(p.xpost.from, "small")}<div class="sim-xbadge">${I.xpost}</div></div>
          <div class="main"><div class="top"><div class="who"><b>${S[p.xpost.from].name}</b> → ${S[p.xpost.to].name} ${saved}</div><div class="time">${p.ago}</div></div>
          <div class="title">${esc(p.title)}</div></div></div>`;
      }
      return `<div class="sim-row ${on}" data-a="select" data-v="${k}">
        ${siteIcon(p.site)}
        <div class="main">
          <div class="top"><div class="who site">${S[p.site].name}</div><div class="time">${p.ago}</div></div>
          <div class="title">${esc(p.title)}</div>
          <div class="ex">${esc(p.excerpt)}</div>
          <div class="foot"><span>${P[p.author][0]}</span><span>${p.read}</span>${p.likes ? `<span class="sim-likes ${p.liked ? "liked" : ""}">${p.liked ? I.starFill : I.star}${p.likes}</span>` : ""}${p.comments.length ? `<span class="sim-likes">${I.comment}${p.comments.length}</span>` : ""}${saved}</div>
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

    // The like star, with a one-off pop (or squash) right after it's toggled.
    function star(x) {
      const fx = x.pop ? ` ${x.pop}` : "";
      delete x.pop;
      return `<span class="sim-star${fx}">${x.liked ? I.starFill : I.star}</span>`;
    }

    function renderDetail() {
      const s = selected();
      if (!s) { detail.innerHTML = `<div class="sim-placeholder">Pick something to read</div>`; return; }
      const p = postFor(s.item);
      if (!p) { // a follow: there's no post to read
        detail.innerHTML = toolbar(s, null) + `<div class="sim-article"><div class="eyebrow">${S[s.item.site].name}</div><h3>${P[s.item.who][0]} followed your blog</h3><div class="sim-byline">${av(s.item.who, "sim-av tiny")} <b data-card="person:${s.item.who}">${P[s.item.who][0]}</b></div></div>`;
        return;
      }
      const origin = p.xpost ? `<div class="sim-notice">X-post from <b>${S[p.xpost.from].name}</b>. You're reading the original.</div>` : "";
      const mentions = p.body.join(" ").match(/@robin|Robin/g)?.length ?? 0;
      const likers = (p.liked ? ["robin", ...p.likers] : p.likers).map((who) =>
        `<span class="sim-liker" data-card="person:${who}">${av(who, "sim-av mini", false)}${P[who][0]}</span>`).join("");
      detail.innerHTML = toolbar(s, p) + `
        <div class="sim-article">
          ${origin}
          <div class="eyebrow"><a data-a="site" data-v="${p.site}" title="Read this site">${S[p.site].name}</a></div>
          <h3>${esc(p.title)}</h3>
          <div class="sim-byline">${av(p.author, "sim-av tiny")} <b data-card="person:${p.author}">${P[p.author][0]}</b><i>·</i>${S[p.site].host}<i>·</i>${longAgo(p.ago)}</div>
          <div class="sim-chips"><span class="sim-chip">${p.read === "2 min" || p.read === "3 min" ? "Quick read" : p.read + " read"}</span>${mentions
            ? `<button class="sim-chip me" data-a="jump">You’re mentioned${mentions > 1 ? ` ${mentions}×` : ""}  ↓</button>` : ""}</div>
          ${likers ? `<div class="sim-likers">${likers}</div>` : ""}
          <div class="body">${p.body.map((t) => `<p>${marked(t)}</p>`).join("")}</div>
        </div>
        <div class="sim-comments ${st.commentsOpen ? "open" : ""}"></div>`;
      renderComments(true);
    }
    const longAgo = (ago) => {
      const n = parseInt(ago), unit = { m: "minute", h: "hour", d: "day" }[ago.slice(-1)];
      return `${n} ${unit}${n === 1 ? "" : "s"} ago`;
    };
    function toolbar(s, p) {
      const reader = st.section === "reader" && p;
      return `<div class="sim-dhead">
        <button class="sim-icon" data-a="close" title="Close (esc)">${I.x}</button>
        ${reader ? `<button class="sim-like ${p.liked ? "liked" : ""}" data-a="likePost" title="Like (l)">${star(p)}${p.likes ? `<span>${p.likes}</span>` : ""}</button>
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
          <div class="sim-acts"><button class="${cm.liked ? "liked" : ""}" data-a="like" data-v="${cm.id}">${star(cm)}${cm.likes ? cm.likes : ""}</button>
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
      tab(d) {
        if (st.section !== "reader" || st.site) return;
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
      menuItem(v) { st.menu = false; renderHead(); renderMenu(); hint(v, 1800); },
      toast(v) { hideCard(); hint(v, 1800); },
    };

    // Clicks: real ones pause the tour; the tour's own are synthetic (isTrusted false).
    sim.addEventListener("click", (e) => {
      const el = e.target.closest("[data-a]");
      if (e.isTrusted) stopTour();
      if (st.menu && !["menu", "menuItem"].includes(el?.dataset.a)) A.menu();
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
      const k = { j: ["move", 1], ArrowDown: ["move", 1], k: ["move", -1], ArrowUp: ["move", -1], ArrowLeft: ["tab", -1], ArrowRight: ["tab", 1], Escape: ["close"], s: ["save"], l: ["likePost"], o: ["toast", "Opens in your browser"] }[e.key];
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
        const wide = st.open && st.sel !== null, f = wide ? SHOT.panel : SHOT.list;
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
      Object.assign(st, { open: true, section: "notifications", filter: "all", feed: "blogs", site: null, menu: false, sel: null, commentsOpen: false, replyTo: null, draft: "", typing: false });
      hideCard();
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
        await point(".sim-chip.me", t); await sleep(1800, t);
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
    const ORDER = ["notifications", "read", "keys", "reader", "cards", "xposts", "comments"];

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
      if (visible && !handedOver && !calm) runTour(NAMES || ORDER, true);
      else if (!visible && playing) halt();
    }, { threshold: 0.45 }).observe(root);

    render();
    setPlaying(false);
    const api = { play, pause: stopTour, chapter: (n) => runTour([n], false), do: A, state: st };
    (window.DispatchSims ||= []).push(api);
    window.DispatchSim ||= api;
  }
})();
