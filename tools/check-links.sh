#!/usr/bin/env bash
# Resolve every relative markdown link and anchor across every member repository.
#
#   tools/check-links.sh            # every member, plus OOPS itself
#   tools/check-links.sh selfish
#
# Runs from the root because links between repositories resolve only in the full checkout.
# Reads tracked markdown only (`git ls-files`); anchors follow GitHub's heading slugs.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
PROJECTS="orbistoun obscene prosperous selfish oops-libs oops-sdk oops-apps oops-mesa"

if [ "$#" -gt 0 ]; then
    for want in "$@"; do
        case " $PROJECTS " in
            *" $want "*) ;;
            *) printf 'not a project: %s\n' "$want" >&2; exit 2 ;;
        esac
    done
    WANTED="$*"
else
    # The root's own docs are checked on a full run only.
    WANTED="$PROJECTS ."
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
links="$work/links"
: > "$links"

# Collect every `[text](target)` as `<source><TAB><line><TAB><target>`. Tabs, since the
# links sit inside markdown tables.
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
                    # Up to the last `](`, since link text may hold parentheses.
                    sub(/^.*\]\(/, "", m)
                    sub(/\)$/, "", m)
                    print src "	" NR "	" m
                    line = substr(line, RSTART + RLENGTH)
                }
            }
        ' "$dir/$rel" >> "$links"
    done
done

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

    # A `_preamble.md` is replayed into the index one directory up; resolve its links there.
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
    want="$(printf '%s' "$frag" | tr '[:upper:]' '[:lower:]')"
    if ! grep -Fxq -- "$want" < <(anchors_of "$full"); then
        printf '%s:%s -> %s (no such anchor)\n' "$src" "$line" "$target" >> "$bad"
    fi
done < "$links"

count="$(grep -c . "$bad" || true)"
if [ "$count" -gt 0 ]; then
    sed 's|^|   |' "$bad"
fi
printf '\nbroken links: %s\n' "$count"
[ "$count" -eq 0 ]
