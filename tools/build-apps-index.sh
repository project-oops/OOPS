#!/usr/bin/env bash
# Render oops-apps into a browsable index for its Pages site.
#
#   tools/build-apps-index.sh <apps-dir> <out-dir> <accent>
#
# One implementation, one consumer, the same shape as build-docs.sh: oops-apps' pages.yml
# checks this repository out and calls this, so the index is generated here and never
# hand-kept. It writes the index to <out-dir> as the site root; build-docs.sh renders the
# documentation into <out-dir>/docs beside it.
#
# **The listing is the repository, not a table somebody maintains.** The apps are discovered
# with `bin/oops-apps list`, each one's card is built from its own `app.env` and `README.md`,
# and its screenshots are whatever it ships under `assets/` and `docs/screenshots/`. A new app,
# a new screenshot or a changed subtitle appears the next time the site builds, with nothing to
# edit here.
#
# **An app is listed when it ships a title.** The rule is `FORMATS` contains `title`: that is
# exactly the set that produces a downloadable `<app>-title-<gen>.zip` in the release, which is
# what a person (or the on-device downloader) installs. A payload or a bare-ELF probe ships no
# title and is not something to install from here, so it does not appear.
#
# **Cards are grouped by KIND** - game, demo, probe, utility - taken from `app.env`'s `KIND`
# field, or inferred from the app's directory group when it is unset. This is deliberately not
# `TITLE_CATEGORY`, which is the platform's packaging category (`big-app`), a different thing.
#
# **What can go stale is fetched live, not baked.** Card media and descriptions are rendered in
# at build time so the page is readable with no network. The download buttons are the one thing
# that moves on every push to main, so they are resolved in the browser from the rolling
# `latest-main` release rather than frozen into the page - see apps-index/index.js.
set -euo pipefail

SRC="${1:?usage: build-apps-index.sh <apps-dir> <out-dir> <accent>}"
OUT="${2:?missing out-dir}"
ACCENT="${3:-#3fb950}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$HERE/apps-index"

SRC="$(cd "$SRC" && pwd)"

# The same two tools build-docs.sh leans on, installed the same way if the runner lacks them.
# jq builds the data island without a single hand-escaped quote; pandoc turns each README into
# the HTML the detail panel shows.
need() {
    command -v "$1" >/dev/null 2>&1 && return 0
    echo "build-apps-index: $1 not found, installing" >&2
    sudo apt-get update -qq && sudo apt-get install -y -qq "$2"
}
need jq jq
need pandoc pandoc

mkdir -p "$OUT" "$OUT/media"

records="$(mktemp)"
trap 'rm -f "$records"' EXIT

emit_media() {
    # Copy one app's presentable media into the site and print a JSON array of {type,src}.
    # Globs, so the set is whatever the app ships - nothing here names a file.
    local app="$1" dir="$2" destrel="media/$1" dest="$OUT/media/$1"
    local -a items=()
    local f base
    mkdir -p "$dest"
    # The demo, in **one** format only, video preferred. An app that ships both `demo.webm` and
    # `demo.gif` is shipping the same clip twice, and showing both is the duplicate a reader
    # notices.
    for f in "$dir"/assets/demo.webm "$dir"/assets/demo.mp4 "$dir"/assets/demo.gif; do
        [ -f "$f" ] || continue
        base="$(basename "$f")"
        case "$base" in *.webm|*.mp4) local t=video ;; *) local t=image ;; esac
        cp "$f" "$dest/$base"
        items+=("$(jq -n --arg type "$t" --arg src "$destrel/$base" '{type:$type,src:$src}')")
        break
    done
    # Then the stills.
    for f in "$dir"/assets/screenshot*.png "$dir"/assets/screenshot*.jpg \
             "$dir"/docs/screenshots/*.png "$dir"/docs/screenshots/*.jpg "$dir"/docs/screenshots/*.gif; do
        [ -f "$f" ] || continue
        base="$(basename "$f")"
        cp "$f" "$dest/$base"
        items+=("$(jq -n --arg src "$destrel/$base" '{type:"image",src:$src}')")
    done
    if [ "${#items[@]}" -eq 0 ]; then
        echo "[]"
    else
        printf '%s\n' "${items[@]}" | jq -s '.'
    fi
}

emit_icon() {
    local app="$1" dir="$2" dest="$OUT/media/$1" f
    mkdir -p "$dest"
    for f in "$dir/assets/icon0.png" "$dir/assets/logo.png" "$dir/assets/icon0.jpg"; do
        if [ -f "$f" ]; then
            cp "$f" "$dest/icon.png"
            echo "media/$app/icon.png"
            return 0
        fi
    done
    echo ""
}

render_desc() {
    # The README as an HTML fragment of prose - the readme-prose.lua filter drops the title, the
    # images (the card's gallery already shows them) and any heading left empty, and repoints
    # relative links at github. `appdir` is the app's path inside the repo, for those links.
    local readme="$1" appdir="$2"
    [ -f "$readme" ] || { echo ""; return 0; }
    pandoc -f gfm -t html \
        -M "appdir=$appdir" -M "repo=project-oops/oops-apps" \
        --lua-filter="$TEMPLATE_DIR/readme-prose.lua" "$readme" 2>/dev/null
}

# A title-shipping app's kind, for grouping. `KIND` in app.env wins; otherwise it is inferred
# from the directory group, which is how the apps are already organised. Kept as inference
# rather than a hardcoded per-app list so a new app lands in the right group on its own.
infer_kind() {
    local group="$1" app="$2"
    case "$app" in
        *probe*|*-cts|*-throw) echo probe; return ;;
    esac
    case "$group" in
        oops-titles)     echo game ;;
        oops-gl|oops-mesa) echo demo ;;
        oops-utilities)  echo utility ;;
        oops-frameworks) echo demo ;;
        oops-payloads)   echo payload ;;
        *)               echo app ;;
    esac
}

# Whitespace-separated word membership: does FORMATS contain `title`?
has_word() { case " $1 " in *" $2 "*) return 0 ;; *) return 1 ;; esac; }

# Read one `KEY=value` field from an app.env. **Parsed, not sourced**: `FORMATS=elf eboot title`
# is a perfectly good make value but invalid shell (sourcing it sets FORMATS=elf and runs
# `eboot title`), which silently dropped every multi-format app from the index until this was a
# parse. Strips one layer of surrounding double quotes; ignores comment lines.
ae_get() {
    local v
    v="$(grep -m1 -E "^$2=" "$1" 2>/dev/null | cut -d= -f2-)"
    v="${v%\"}"; v="${v#\"}"
    printf '%s' "$v"
}

while IFS= read -r app; do
    [ -n "$app" ] || continue
    mk="$(find "$SRC/src" -maxdepth 3 -name Makefile -path "*/$app/Makefile" 2>/dev/null | head -1)"
    [ -n "$mk" ] || continue
    dir="$(dirname "$mk")"
    env="$dir/app.env"
    [ -f "$env" ] || continue

    # Default FORMATS is `elf` (common/app.mk); an app appears only if it ships a title.
    formats="$(ae_get "$env" FORMATS)"; formats="${formats:-elf}"
    has_word "$formats" title || continue

    group="$(basename "$(dirname "$dir")")"
    kind="$(ae_get "$env" KIND)"; kind="${kind:-$(infer_kind "$group" "$app")}"

    title="$(ae_get "$env" TITLE_NAME)"; title="${title:-$app}"
    subtitle="$(ae_get "$env" APP_SUBTITLE)"
    version="$(ae_get "$env" TITLE_VERSION)"

    # The app's own directory inside the repo - used both to repoint the README's relative links
    # (render_desc) and to link the card back to the source on GitHub.
    appdir="${dir#"$SRC"/}"

    icon="$(emit_icon "$app" "$dir")"
    media="$(emit_media "$app" "$dir")"
    desc="$(render_desc "$dir/README.md" "$appdir")"

    jq -n \
        --arg name "$app" \
        --arg title "$title" \
        --arg subtitle "$subtitle" \
        --arg kind "$kind" \
        --arg version "$version" \
        --arg icon "$icon" \
        --arg desc "$desc" \
        --arg repo "https://github.com/project-oops/oops-apps/tree/main/$appdir" \
        --argjson media "$media" \
        '{name:$name,title:$title,subtitle:$subtitle,kind:$kind,version:$version,icon:$icon,media:$media,desc:$desc,repo:$repo}' \
        >> "$records"
done < <("$SRC/bin/oops-apps" list)

{
    printf 'window.OOPS_INDEX = %s;\n' "$(jq -n --arg owner project-oops --arg repo oops-apps --arg accent "$ACCENT" '{owner:$owner,repo:$repo,accent:$accent}')"
    printf 'window.OOPS_APPS = '
    jq -s 'sort_by(.title)' "$records"
    printf ';\n'
} > "$OUT/apps.js"

# The same catalogue as plain JSON, so a machine - the on-device oops-app-downloader above all -
# can read the app list without scraping the page. Its download URLs still come from the live
# release (matched by the `<app>-` filename prefix), so nothing here goes stale.
jq -s 'sort_by(.title)' "$records" > "$OUT/apps.json"

cp "$TEMPLATE_DIR/index.html"  "$OUT/index.html"
cp "$TEMPLATE_DIR/index.css"   "$OUT/index.css"
cp "$TEMPLATE_DIR/index.js"    "$OUT/index.js"
cp "$TEMPLATE_DIR/favicon.svg" "$OUT/favicon.svg"   # the OOPSy-daisy daisy, as the site icon

echo "build-apps-index: $(jq -s 'length' "$records") apps -> $OUT"
