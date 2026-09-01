#!/usr/bin/env bash
# Render a project's docs/ to static HTML for its Pages site.
#
#   tools/build-docs.sh <project-dir> <out-dir> <accent> <title>
#
# One implementation, four consumers. Each project's `pages.yml` checks this
# repository out and calls this, the same way obSCEne's CI already checks it out
# for the shared gates - so the docs of all four look like one set and a change
# to how they are rendered is made once.
#
# Markdown becomes HTML at build time rather than in the browser: a static page
# needs no script, survives the GitHub API being unreachable, and is readable by
# anything that reads HTML. Cross-document links are rewritten `.md` -> `.html`
# so they still resolve once published.
set -euo pipefail

SRC="${1:?usage: build-docs.sh <project-dir> <out-dir> <accent> <title>}"
OUT="${2:?missing out-dir}"
ACCENT="${3:?missing accent colour}"
TITLE="${4:?missing project title}"

command -v pandoc >/dev/null 2>&1 || {
    echo "build-docs: pandoc not found, installing" >&2
    sudo apt-get update -qq && sudo apt-get install -y -qq pandoc
}

# OOPS itself has no logo - it is the four projects rather than a fifth - so the
# favicon is conditional rather than a link to a file that is not there.
FAVICON=""
[ -f "$SRC/assets/logo.svg" ] && FAVICON="assets/logo.svg"

mkdir -p "$OUT/docs"
TEMPLATE="$(mktemp)"
trap 'rm -f "$TEMPLATE"' EXIT

# The same frame, palette and pixel face as the landing page, plus the prose
# styles a document needs and a page of buttons does not.
cat > "$TEMPLATE" <<'TEMPLATE_END'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$pagetitle$ - $projecttitle$</title>
$if(favicon)$<link rel="icon" href="$root$$favicon$">$endif$
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Press+Start+2P&display=swap" rel="stylesheet">
<style>
:root {
  --accent: $accent$;
  --bg: #000000;
  --fg: #e9e9ea;
  --muted: #8b9096;
  --rule: #26282c;
  --frame-width: 14px;
  --frame-radius: 44px;
  --frame-gap: 18px;
  --pixel: "Press Start 2P", "Courier New", monospace;
}
* { box-sizing: border-box; }
html, body {
  margin: 0; padding: 0; background: var(--bg); color: var(--fg);
  font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  line-height: 1.7;
}
.frame {
  margin: var(--frame-gap);
  border: var(--frame-width) solid var(--accent);
  border-radius: var(--frame-radius);
  padding: clamp(1.5rem, 5vw, 4rem);
  min-height: calc(100vh - (var(--frame-gap) * 2));
}
.wrap { max-width: 78ch; margin: 0 auto; }
.crumb {
  font-family: var(--pixel); font-size: 0.65rem; margin-bottom: 2.5rem;
  display: flex; gap: 0.9rem; flex-wrap: wrap;
}
.crumb a { color: var(--accent); text-decoration: none; }
.crumb a:hover { text-decoration: underline; }
h1, h2, h3, h4 { line-height: 1.3; margin: 2.2em 0 0.7em; }
h1 { font-family: var(--pixel); font-size: clamp(1.1rem, 3.6vw, 1.7rem);
     line-height: 1.5; margin-top: 0; color: var(--accent); }
h2 { font-size: 1.5rem; border-bottom: 1px solid var(--rule); padding-bottom: 0.3em; }
h3 { font-size: 1.2rem; }
a { color: var(--accent); }
code, pre { font-family: ui-monospace, "Cascadia Code", Consolas, monospace; }
code { background: #17191c; padding: 0.15em 0.4em; border-radius: 4px; font-size: 0.9em; }
pre { background: #0d0f11; border: 1px solid var(--rule); border-radius: 10px;
      padding: 1rem 1.2rem; overflow-x: auto; }
pre code { background: none; padding: 0; font-size: 0.85rem; }
blockquote { margin: 1.5em 0; padding: 0.2em 1.2em; border-left: 4px solid var(--accent);
             color: var(--muted); }
table { border-collapse: collapse; width: 100%; display: block; overflow-x: auto; margin: 1.5em 0; }
th, td { border: 1px solid var(--rule); padding: 0.5em 0.8em; text-align: left; }
th { background: #17191c; }
hr { border: 0; border-top: 1px solid var(--rule); margin: 2.5em 0; }
img { max-width: 100%; }
/* A diagram is not a code listing, so it loses the box. Before the script runs -
   or if it never does - this shows the diagram's source, which is the honest
   failure: readable, and obviously not what was intended. */
pre.mermaid {
  background: none; border: 0; padding: 0; text-align: center;
  color: var(--muted); overflow-x: auto;
}
pre.mermaid > code { font-size: 0.8rem; }
</style>
</head>
<body>
<main class="frame"><div class="wrap">
<nav class="crumb"><a href="$root$index.html">$projecttitle$</a><a href="$root$docs/index.html">docs</a></nav>
$body$
</div></main>
$if(mermaid)$
<!-- Loaded only on documents that contain a diagram, so the other ninety-odd
     pages stay static files with no script at all. -->
<script type="module">
import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
mermaid.initialize({
  startOnLoad: true,
  theme: "base",
  themeVariables: {
    background: "#000000",
    primaryColor: "#17191c",
    primaryTextColor: "#e9e9ea",
    primaryBorderColor: "$accent$",
    lineColor: "$accent$",
    secondaryColor: "#0d0f11",
    tertiaryColor: "#0d0f11",
    fontFamily: "ui-monospace, Consolas, monospace"
  }
});
</script>
$endif$
</body>
</html>
TEMPLATE_END

# Which group a document belongs to. The logs are last because they are the
# project's memory rather than its manual - honest to publish, misleading to lead
# with. Everything is published either way; only the order is a judgement.
group_of() {
    # Only the top-level README is the way in. A README inside `examples/` is a
    # note about that directory, and listing it as a starting point sends a
    # reader to the wrong end of the documentation.
    if [ "$1" = "$SRC/docs/README.md" ]; then
        echo 0
        return
    fi
    case "$(basename "$1")" in
        DECISIONS.md | WORKLOG.md | BACKLOG.md | ROADMAP.md) echo 3 ;;
        # Building is guide material, not reference. Left to the default it landed in
        # "Reference" between two dozen design notes, which is where it was looked for and
        # not found - the reason these documents were written at all.
        BUILDING.md) echo 1 ;;
        *)
            case "$1" in
                */guide/* | */features/*) echo 1 ;;
                *) echo 2 ;;
            esac
            ;;
    esac
}

index_rows=""
count=0

while IFS= read -r md; do
    rel="${md#"$SRC"/docs/}"
    dest="$OUT/docs/${rel%.md}.html"
    mkdir -p "$(dirname "$dest")"

    # How far back to the site root, so the frame's links work at any depth.
    depth=$(printf '%s' "$rel" | awk -F/ '{print NF-1}')
    root=""
    for _ in $(seq 0 "$depth"); do root="../$root"; done

    # pandoc renders a ```mermaid fence as <pre class="mermaid">, which is the
    # hook mermaid.js already looks for - so the only thing needed is the script,
    # and only where a diagram is.
    mermaid=""
    grep -q '```mermaid' "$md" && mermaid="1"

    pandoc "$md" \
        --from=gfm --to=html5 --standalone \
        --template="$TEMPLATE" \
        -V "mermaid=$mermaid" \
        -M "pagetitle=${rel%.md}" \
        -V "projecttitle=$TITLE" \
        -V "accent=$ACCENT" \
        -V "root=$root" \
        -V "favicon=$FAVICON" \
        --output="$dest"

    # Links between documents point at the markdown; the published pages are HTML.
    # `[^":]*` excludes anything with a scheme, so a link to a `.md` file on
    # github.com keeps pointing at the source rather than at a page that is only
    # published here. The delimiter is not `#`, because the pattern contains one.
    sed -i -E 's|href="([^":]*)\.md(#[^"]*)?"|href="\1.html\2"|g' "$dest"

    title="$(sed -n 's/^# \(.*\)/\1/p' "$md" | head -1)"
    [ -n "$title" ] || title="${rel%.md}"
    index_rows="${index_rows}$(group_of "$md")|${rel%.md}.html|${rel%.md}|${title}
"
    count=$((count + 1))
done < <(find "$SRC/docs" -name '*.md' | sort)

# Everything under docs/ that is not markdown, at the path it already sits in.
#
# This copied `docs/images/` and only that, by name. obSCEne keeps its figures in
# `docs/screenshots/`, so every screenshot on its published site was a broken icon -
# `docs/screenshots/fpps4.png` returned a 404 while the page around it rendered fine,
# which reads as a styling fault and is not one. orbistoun's three `.txt` appendices and
# prosperous's `manifest.schema.json` were missing the same way.
#
# Copying by shape rather than by name means the next directory somebody adds arrives
# without this file needing to hear about it.
copied=0
while IFS= read -r f; do
    rel="${f#"$SRC/docs/"}"
    mkdir -p "$OUT/docs/$(dirname "$rel")"
    cp "$f" "$OUT/docs/$rel"
    copied=$((copied + 1))
done < <(find "$SRC/docs" -type f ! -name '*.md')
[ "$copied" -gt 0 ] && echo "build-docs: $copied non-markdown file(s) copied"

# The index, grouped and in a fixed order.
{
    printf '# %s documentation\n\n' "$TITLE"
    i=0
    for label in "Start here" "Guide" "Reference" "Project memory"; do
        rows="$(printf '%s' "$index_rows" | awk -F'|' -v g="$i" '$1==g')"
        i=$((i + 1))
        [ -n "$rows" ] || continue
        printf '## %s\n\n' "$label"
        printf '%s\n' "$rows" | while IFS='|' read -r _ href name title; do
            [ -n "$href" ] || continue
            printf -- '- [%s](%s) - %s\n' "$name" "$href" "$title"
        done
        printf '\n'
    done
} > "$OUT/docs/_index.md"

pandoc "$OUT/docs/_index.md" \
    --from=gfm --to=html5 --standalone \
    --template="$TEMPLATE" \
    -M "pagetitle=documentation" \
    -V "projecttitle=$TITLE" \
    -V "accent=$ACCENT" \
    -V "root=../" \
    -V "favicon=$FAVICON" \
    --output="$OUT/docs/index.html"
rm -f "$OUT/docs/_index.md"

echo "build-docs: $count documents -> $OUT/docs"
