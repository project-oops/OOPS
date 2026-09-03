#!/usr/bin/env bash
# Resolve every relative markdown link and anchor across all five repositories.
#
#   tools/check-links.sh            # all five, plus OOPS itself
#   tools/check-links.sh selfish
#
# A cross-repository link is the one kind this cannot be checked from inside a project: from
# orbistoun, `../selfish/docs/DECISIONS.md` either exists or does not depending on what else
# is checked out, and only the meta-repository knows.
#
# Only tracked files are read. The Python version this replaces walked the filesystem and
# subtracted what `git status --ignored` reported, which was six broken links in
# `orbistoun/site/` - a Pages bundle CI regenerates - before it learned to skip them. Asking
# `git ls-files` for the tracked set gets the same answer without the subtraction, and cannot
# drift from what a commit would contain.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
PROJECTS="orbistoun obscene prosperous selfish oops-libs oops-sdk"

if [ "$#" -gt 0 ]; then
    for want in "$@"; do
        case " $PROJECTS " in
            *" $want "*) ;;
            *) printf 'not a project: %s\n' "$want" >&2; exit 2 ;;
        esac
    done
    WANTED="$*"
else
    # The meta repository's own docs are checked too, but only on a full run: naming a
    # project means that project.
    WANTED="$PROJECTS ."
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
links="$work/links"
: > "$links"

# --- collect every relative link -------------------------------------------------------
#
# `[text](target)`, with the target having no whitespace. Emitted as
# `<source path><TAB><line><TAB><target>` for the resolver below. A line can hold several, so
# the match loop consumes the line as it goes.
#
# Tab-separated, not pipe: the generated indexes are markdown tables, and a pipe separator
# split every row across the wrong fields and reported live links as missing paths.
for repo in $WANTED; do
    dir="$ROOT/$repo"
    [ -d "$dir/.git" ] || continue
    git -C "$dir" ls-files '*.md' | while IFS= read -r rel; do
        [ -f "$dir/$rel" ] || continue
        awk -v src="$repo/$rel" '
            {
                line = $0
                while (match(line, /\[[^]]*\]\([^)[:space:]]+\)/)) {
                    m = substr(line, RSTART, RLENGTH)
                    # To the LAST `](`, not the first `(`. A link whose TEXT contains
                    # parentheses - "Package header (found on hardware)" - otherwise yields
                    # everything after that inner paren as the target, and a live link is
                    # reported as a missing path.
                    sub(/^.*\]\(/, "", m)
                    sub(/\)$/, "", m)
                    print src "	" NR "	" m
                    line = substr(line, RSTART + RLENGTH)
                }
            }
        ' "$dir/$rel" >> "$links"
    done
done

# --- resolve ---------------------------------------------------------------------------
bad="$work/bad"
: > "$bad"

# One heading list per target file, computed once and kept. GitHub's anchor rule: drop code
# fences and punctuation, lowercase, spaces to hyphens.
anchors_of() {
    local file="$1" cache
    cache="$work/anchors.$(printf '%s' "$file" | tr -c 'A-Za-z0-9' '_')"
    if [ ! -f "$cache" ]; then
        awk '
            function slug(h,   t) {
                t = h
                gsub(/`/, "", t)
                gsub(/[^A-Za-z0-9 _-]/, "", t)
                gsub(/^[ \t]+|[ \t]+$/, "", t)
                t = tolower(t)
                gsub(/[ \t]+/, "-", t)
                return t
            }
            /^#{1,6}[ \t]+/ {
                h = $0
                sub(/^#+[ \t]+/, "", h)
                sub(/[ \t]+$/, "", h)
                print slug(h)
            }
        ' "$file" > "$cache"
    fi
    cat "$cache"
}

while IFS="$(printf '	')" read -r src line target; do
    [ -n "$target" ] || continue
    case "$target" in
        http://*|https://*|mailto:*|"#"*) continue ;;
    esac

    path="${target%%#*}"
    frag=""
    case "$target" in *#*) frag="${target#*#}" ;; esac

    # A `_preamble.md` is a fragment, not a page: the splitters store it beside the items and
    # replay it into the index one directory up, so its links are written for `docs/` and are
    # wrong where the file physically sits. Resolve them from where they are used rather than
    # skipping the file - a link the reader will actually follow still gets checked.
    srcdir="$(dirname "$ROOT/$src")"
    case "$src" in */_preamble.md) srcdir="$(dirname "$(dirname "$ROOT/$src")")" ;; esac
    if [ -z "$path" ]; then
        full="$ROOT/$src"
    else
        full="$srcdir/$path"
    fi

    if [ ! -e "$full" ]; then
        printf '%s:%s -> %s (no such path)\n' "$src" "$line" "$target" >> "$bad"
        continue
    fi
    [ -n "$frag" ] || continue
    case "$full" in *.md) ;; *) continue ;; esac

    # Compare case-insensitively, the way GitHub resolves a fragment.
    want="$(printf '%s' "$frag" | tr 'A-Z' 'a-z')"
    if ! anchors_of "$full" | grep -Fxq -- "$want"; then
        printf '%s:%s -> %s (no such anchor)\n' "$src" "$line" "$target" >> "$bad"
    fi
done < "$links"

count="$(grep -c . "$bad" || true)"
if [ "$count" -gt 0 ]; then
    sed 's|^|   |' "$bad"
fi
printf '\nbroken links: %s\n' "$count"
[ "$count" -eq 0 ]
