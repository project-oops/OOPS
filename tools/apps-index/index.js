/* oops-apps index — renders the cards baked into apps.js and resolves each app's
 * downloads live from the rolling `latest-main` release, so the buttons are never
 * a frozen copy of a build that has moved on. No build-time secrets, no framework. */
(function () {
  "use strict";

  var APPS = (window.OOPS_APPS || []).slice();
  var CFG = window.OOPS_INDEX || { owner: "project-oops", repo: "oops-apps" };
  var RELEASE_TAG = "latest-main";
  var RELEASE_PAGE =
    "https://github.com/" + CFG.owner + "/" + CFG.repo + "/releases/tag/" + RELEASE_TAG;

  var grid = document.getElementById("grid");
  var emptyMsg = document.getElementById("empty");
  var search = document.getElementById("search");
  var filters = document.getElementById("filters");
  var overlay = document.getElementById("overlay");
  var detail = document.getElementById("detail");

  var activeKind = "all";
  var query = "";

  /* ---- helpers ---- */

  function el(tag, cls, html) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (html != null) n.innerHTML = html;
    return n;
  }

  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"]/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c];
    });
  }

  function letterTile(app) {
    var t = el("div", "tile");
    t.textContent = (app.title || app.name || "?").charAt(0).toUpperCase();
    return t;
  }

  function thumb(app, cls) {
    if (app.icon) {
      var img = el("img", cls);
      img.src = app.icon;
      img.alt = "";
      img.loading = "lazy";
      return img;
    }
    var tile = letterTile(app);
    tile.className = "tile";
    return tile;
  }

  function bytes(n) {
    if (!n && n !== 0) return "";
    var u = ["B", "KB", "MB", "GB"], i = 0;
    while (n >= 1024 && i < u.length - 1) { n /= 1024; i++; }
    return (i === 0 ? n : n.toFixed(1)) + " " + u[i];
  }

  var GENERATIONS = ["orbis", "neo", "prospero", "trinity"];
  function generationOf(name) {
    var lower = name.toLowerCase();
    for (var i = 0; i < GENERATIONS.length; i++) {
      if (lower.indexOf("-" + GENERATIONS[i]) !== -1) return GENERATIONS[i];
    }
    return "";
  }

  /* ---- the live release, fetched once and shared by every card ---- */

  var releasePromise = null;
  function loadRelease() {
    if (releasePromise) return releasePromise;
    var url =
      "https://api.github.com/repos/" + CFG.owner + "/" + CFG.repo +
      "/releases/tags/" + RELEASE_TAG;
    releasePromise = fetch(url, { headers: { Accept: "application/vnd.github+json" } })
      .then(function (r) {
        if (!r.ok) throw new Error("release " + r.status);
        return r.json();
      })
      .then(function (rel) { return rel.assets || []; });
    return releasePromise;
  }

  function assetsFor(app, assets) {
    var prefix = app.name.toLowerCase() + "-";
    return assets.filter(function (a) {
      return a.name.toLowerCase().indexOf(prefix) === 0;
    });
  }

  /* ---- grid ---- */

  function kinds() {
    var seen = {};
    APPS.forEach(function (a) { if (a.kind) seen[a.kind] = true; });
    return Object.keys(seen).sort();
  }

  function buildFilters() {
    var all = ["all"].concat(kinds());
    all.forEach(function (k) {
      var b = el("button", "chip");
      b.textContent = k === "all" ? "All" : k;
      b.setAttribute("role", "tab");
      b.setAttribute("aria-selected", k === activeKind ? "true" : "false");
      b.addEventListener("click", function () {
        activeKind = k;
        Array.prototype.forEach.call(filters.children, function (ch) {
          ch.setAttribute("aria-selected", ch === b ? "true" : "false");
        });
        render();
      });
      filters.appendChild(b);
    });
  }

  function matches(app) {
    if (activeKind !== "all" && app.kind !== activeKind) return false;
    if (!query) return true;
    var hay = (app.title + " " + app.name + " " + app.subtitle).toLowerCase();
    return hay.indexOf(query) !== -1;
  }

  function card(app) {
    var c = el("button", "card");
    c.type = "button";
    c.appendChild(thumb(app, "thumb"));

    var body = el("div");
    body.appendChild(el("h3", null, esc(app.title)));
    if (app.subtitle) body.appendChild(el("p", null, esc(app.subtitle)));

    var meta = el("div", "meta");
    if (app.kind) meta.appendChild(el("span", "badge", esc(app.kind)));
    if (app.media && app.media.length) {
      var n = app.media.length;
      meta.appendChild(el("span", "badge media", n + (n === 1 ? " shot" : " shots")));
    }
    body.appendChild(meta);
    c.appendChild(body);

    c.addEventListener("click", function () { openDetail(app); });
    return c;
  }

  function render() {
    grid.innerHTML = "";
    var shown = APPS.filter(matches);
    shown.forEach(function (a) { grid.appendChild(card(a)); });
    emptyMsg.hidden = shown.length !== 0;
  }

  /* ---- detail ---- */

  function openDetail(app) {
    detail.innerHTML = "";

    var head = el("div", "detail-head");
    head.appendChild(thumb(app, ""));
    var htext = el("div");
    htext.appendChild(el("h2", null, esc(app.title)));
    if (app.subtitle) htext.appendChild(el("p", "sub", esc(app.subtitle)));
    var tags = el("div", "tags");
    if (app.kind) tags.appendChild(el("span", "badge", esc(app.kind)));
    if (app.version) tags.appendChild(el("span", "badge", "v" + esc(app.version)));
    tags.appendChild(el("span", "badge", esc(app.name)));
    htext.appendChild(tags);
    if (app.repo) {
      var src = el("a", "src-link", "View source on GitHub ↗");
      src.href = app.repo;
      src.target = "_blank";
      src.rel = "noopener";
      htext.appendChild(src);
    }
    head.appendChild(htext);
    detail.appendChild(head);

    if (app.media && app.media.length) {
      var g = el("div", "gallery");
      app.media.forEach(function (m) {
        var node;
        if (m.type === "video") {
          node = el("video");
          node.src = m.src;
          node.controls = true;
          node.loop = true;
          node.muted = true;
          node.playsInline = true;
          node.autoplay = true;
        } else {
          node = el("img");
          node.src = m.src;
          node.alt = app.title + " screenshot";
          node.loading = "lazy";
        }
        g.appendChild(node);
      });
      detail.appendChild(g);
    }

    var dl = el("div", "downloads");
    dl.appendChild(el("h4", null, "Download"));
    var dlBody = el("div", "dl-list");
    dlBody.appendChild(el("p", "dl-note", "Checking the latest build&hellip;"));
    dl.appendChild(dlBody);
    detail.appendChild(dl);

    loadRelease().then(function (assets) {
      renderDownloads(dlBody, assetsFor(app, assets));
    }).catch(function () {
      dlBody.innerHTML =
        '<p class="dl-note">Could not reach the release right now. ' +
        '<a href="' + RELEASE_PAGE + '">Browse all downloads on GitHub</a>.</p>';
    });

    if (app.desc) {
      var about = el("div", "about");
      about.appendChild(el("h4", null, "About"));
      var body = el("div", "readme collapsed");
      body.innerHTML = app.desc;
      about.appendChild(body);
      var more = el("button", "more", "Read more");
      more.addEventListener("click", function () {
        var open = body.classList.toggle("collapsed") === false;
        more.textContent = open ? "Show less" : "Read more";
      });
      requestAnimationFrame(function () {
        if (body.scrollHeight > 300) about.appendChild(more);
        else body.classList.remove("collapsed");
      });
      detail.appendChild(about);
    }

    overlay.hidden = false;
    document.body.style.overflow = "hidden";
    document.getElementById("close").focus();
  }

  function renderDownloads(container, assets) {
    container.innerHTML = "";
    if (!assets.length) {
      container.appendChild(el("p", "dl-note",
        'No build in the latest release yet &mdash; this one is still in development. ' +
        '<a href="' + RELEASE_PAGE + '">See all downloads</a>.'));
      return;
    }
    assets.sort(function (a, b) { return a.name.localeCompare(b.name); });
    assets.forEach(function (a) {
      var link = el("a", "dl");
      link.href = a.browser_download_url;
      var info = el("div");
      info.appendChild(el("div", "dl-name", esc(a.name)));
      var gen = generationOf(a.name);
      var sub = [gen ? gen : null, bytes(a.size)].filter(Boolean).join(" &middot; ");
      if (sub) info.appendChild(el("div", "dl-sub", sub));
      link.appendChild(info);
      link.appendChild(el("span", "dl-go", "Get ↓"));
      container.appendChild(link);
    });
  }

  function closeDetail() {
    overlay.hidden = true;
    document.body.style.overflow = "";
  }

  document.getElementById("close").addEventListener("click", closeDetail);
  overlay.addEventListener("click", function (e) {
    if (e.target === overlay) closeDetail();
  });
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && !overlay.hidden) closeDetail();
  });

  search.addEventListener("input", function () {
    query = search.value.trim().toLowerCase();
    render();
  });

  /* ---- go ---- */
  buildFilters();
  render();
})();
