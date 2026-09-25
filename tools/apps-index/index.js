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
  var statusFilters = document.getElementById("status-filters");
  var sortSel = document.getElementById("sort");

  var activeKind = "all";
  var activeStatus = "all";
  var query = "";
  var sortKey = "name";

  /* Readiness ladder: label + sort rank, in one place so the badge, the filter and the sort agree.
   * An app whose status is missing or unrecognised reads as experimental, matching the generator's
   * default. */
  var STATUS_META = {
    playable:     { label: "Playable",     rank: 0 },
    experimental: { label: "Experimental", rank: 1 },
    wip:          { label: "WIP",          rank: 2 }
  };
  function statusOf(app) { return STATUS_META[app.status] ? app.status : "experimental"; }

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

  function statuses() {
    var seen = {};
    APPS.forEach(function (a) { seen[statusOf(a)] = true; });
    return Object.keys(STATUS_META).filter(function (s) { return seen[s]; });
  }

  function byName(a, b) {
    return String(a.title || a.name).localeCompare(String(b.title || b.name));
  }

  /* All three sort keys are truthful from the baked data, so the grid never waits on the network.
   * Downloads and publish-date are deliberately absent: the rolling release recreates every asset
   * on each push, so those numbers are not meaningful until the release workflow preserves them. */
  function sortApps(list) {
    var l = list.slice();
    if (sortKey === "status") {
      l.sort(function (a, b) {
        return (STATUS_META[statusOf(a)].rank - STATUS_META[statusOf(b)].rank) || byName(a, b);
      });
    } else if (sortKey === "kind") {
      l.sort(function (a, b) {
        return String(a.kind || "").localeCompare(String(b.kind || "")) || byName(a, b);
      });
    } else {
      l.sort(byName);
    }
    return l;
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

  function buildStatusFilters() {
    var all = ["all"].concat(statuses());
    all.forEach(function (s) {
      var b = el("button", "chip");
      b.textContent = s === "all" ? "Any readiness" : STATUS_META[s].label;
      b.setAttribute("role", "tab");
      b.setAttribute("aria-selected", s === activeStatus ? "true" : "false");
      b.addEventListener("click", function () {
        activeStatus = s;
        Array.prototype.forEach.call(statusFilters.children, function (ch) {
          ch.setAttribute("aria-selected", ch === b ? "true" : "false");
        });
        render();
      });
      statusFilters.appendChild(b);
    });
  }

  function matches(app) {
    if (activeKind !== "all" && app.kind !== activeKind) return false;
    if (activeStatus !== "all" && statusOf(app) !== activeStatus) return false;
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
    var st = statusOf(app);
    meta.appendChild(el("span", "badge status " + st, STATUS_META[st].label));
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
    var shown = sortApps(APPS.filter(matches));
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
    var dst = statusOf(app);
    tags.appendChild(el("span", "badge status " + dst, STATUS_META[dst].label));
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

  sortSel.addEventListener("change", function () {
    sortKey = sortSel.value;
    render();
  });

  /* ---- go ---- */
  buildFilters();
  buildStatusFilters();
  render();
})();
