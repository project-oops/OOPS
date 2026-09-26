#!/usr/bin/env bash
# Render oops-apps into a browsable index for its Pages site.
#
#   tools/build-apps-index.sh <apps-dir> <out-dir> <accent>
#
# Called by oops-apps' pages.yml; writes the site root to <out-dir>, beside the docs that
# build-docs.sh renders into <out-dir>/docs. Apps come from `bin/oops-apps list`; one is
# listed when its app.env `FORMATS` contains `title`. Each card is built from the app's
# app.env, README.md, `assets/` and `docs/screenshots/`, and grouped by `KIND` (inferred
# from the directory group when unset). Download links are resolved in the browser from
# the `latest-main` release (apps-index/index.js).
set -euo pipefail

SRC="${1:?usage: build-apps-index.sh <apps-dir> <out-dir> <accent>}"
OUT="${2:?missing out-dir}"
ACCENT="${3:-#3fb950}"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$HERE/apps-index"

SRC="$(cd "$SRC" && pwd)"

# jq builds the data; pandoc renders each README. Installed if the runner lacks them.
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
    # Copy one app's media into the site and print a JSON array of {type,src}.
    local app="$1" dir="$2" destrel="media/$1" dest="$OUT/media/$1"
    local -a items=()
    local f base
    mkdir -p "$dest"
    # The demo clip, in one format only, video preferred.
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
    # The README as an HTML fragment (see readme-prose.lua). `appdir` is the app's path in
    # the repository, for its relative links.
    local readme="$1" appdir="$2"
    [ -f "$readme" ] || { echo ""; return 0; }
    pandoc -f gfm -t html \
        -M "appdir=$appdir" -M "repo=project-oops/oops-apps" \
        --lua-filter="$TEMPLATE_DIR/readme-prose.lua" "$readme" 2>/dev/null
}

# An app's kind when app.env sets no `KIND`, from its name and directory group.
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

# One `KEY=value` field of an app.env, without one layer of double quotes. Parsed, not
# sourced: app.env is make syntax, and `FORMATS=elf eboot title` is not valid shell.
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

    # Readiness badge: playable, experimental (the default) or wip; anything else fails.
    status="$(ae_get "$env" STATUS)"; status="${status:-experimental}"
    case "$status" in
        playable|experimental|wip) ;;
        *) echo "build-apps-index: $app: STATUS='$status' is not one of playable|experimental|wip" >&2; exit 1 ;;
    esac

    title="$(ae_get "$env" TITLE_NAME)"; title="${title:-$app}"
    subtitle="$(ae_get "$env" APP_SUBTITLE)"
    version="$(ae_get "$env" TITLE_VERSION)"

    appdir="${dir#"$SRC"/}"

    icon="$(emit_icon "$app" "$dir")"
    media="$(emit_media "$app" "$dir")"
    desc="$(render_desc "$dir/README.md" "$appdir")"

    jq -n \
        --arg name "$app" \
        --arg title "$title" \
        --arg subtitle "$subtitle" \
        --arg kind "$kind" \
        --arg status "$status" \
        --arg version "$version" \
        --arg icon "$icon" \
        --arg desc "$desc" \
        --arg repo "https://github.com/project-oops/oops-apps/tree/main/$appdir" \
        --argjson media "$media" \
        '{name:$name,title:$title,subtitle:$subtitle,kind:$kind,status:$status,version:$version,icon:$icon,media:$media,desc:$desc,repo:$repo}' \
        >> "$records"
done < <("$SRC/bin/oops-apps" list)

{
    printf 'window.OOPS_INDEX = %s;\n' "$(jq -n --arg owner project-oops --arg repo oops-apps --arg accent "$ACCENT" '{owner:$owner,repo:$repo,accent:$accent}')"
    printf 'window.OOPS_APPS = '
    jq -s 'sort_by(.title)' "$records"
    printf ';\n'
} > "$OUT/apps.js"

# The catalogue as JSON, for the on-device downloader.
jq -s 'sort_by(.title)' "$records" > "$OUT/apps.json"

cp "$TEMPLATE_DIR/index.html"  "$OUT/index.html"
cp "$TEMPLATE_DIR/index.css"   "$OUT/index.css"
cp "$TEMPLATE_DIR/index.js"    "$OUT/index.js"
cp "$TEMPLATE_DIR/favicon.svg" "$OUT/favicon.svg"

echo "build-apps-index: $(jq -s 'length' "$records") apps -> $OUT"
