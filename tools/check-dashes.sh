#!/usr/bin/env bash
# No em-dash or en-dash in prose (STYLE section 1, "Dashes are hyphens").
#
#   tools/check-dashes.sh            # every member, plus OOPS itself
#   tools/check-dashes.sh selfish
#
# Scans tracked text files. A line that keeps a dash (captured output, quoted source) is
# listed exactly in `tools/dashes-allowed.txt`; fenced blocks are not exempt.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
PROJECTS="orbistoun obscene prosperous selfish oops-libs oops-sdk oops-apps oops-mesa"
ALLOW="$HERE/dashes-allowed.txt"

# The refused marks, written literally; this file is excluded from its own scan.
EM=$'—'
EN=$'–'

if [ "$#" -gt 0 ]; then
    for want in "$@"; do
        case " . $PROJECTS " in
            *" $want "*) ;;
            *) printf 'unknown project %s. One of: %s\n' "$want" "$PROJECTS" >&2; exit 2 ;;
        esac
    done
    WANTED="$*"
else
    WANTED=". $PROJECTS"
fi

[ -f "$ALLOW" ] || { printf 'missing %s - nothing was examined, which is not a pass\n' "$ALLOW" >&2; exit 2; }

found=0
examined=0
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

for repo in $WANTED; do
    dir="$ROOT/$repo"
    [ -d "$dir/.git" ] || continue
    # `git grep` exits 1 for no match, the passing case. `bin/*` is listed by path because
    # the entry points have no extension.
    status=0
    git -C "$dir" grep -nI -e "$EM" -e "$EN" -- \
        '*.md' '*.rs' '*.c' '*.h' '*.sh' '*.toml' '*.yml' '*.html' 'bin/*' \
        ':!tools/dashes-allowed.txt' ':!tools/check-dashes.sh' > "$tmp" 2>/dev/null || status=$?
    if [ "$status" -gt 1 ]; then
        printf 'check-dashes: git grep failed in %s (exit %s) - NOT clean, just unread\n' \
            "$repo" "$status" >&2
        exit 2
    fi
    examined=$((examined + $(git -C "$dir" ls-files -- '*.md' '*.rs' '*.c' '*.h' '*.sh' '*.toml' '*.yml' '*.html' 'bin/*' | wc -l)))

    while IFS= read -r hit; do
        [ -n "$hit" ] || continue
        # `path:line:text` - strip the first two fields, then compare the trimmed text.
        text="${hit#*:}"
        text="${text#*:}"
        trimmed="$(printf '%s' "$text" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
        if grep -Fxq -- "$trimmed" "$ALLOW"; then
            continue
        fi
        if [ "$found" -eq 0 ]; then
            printf 'em-dash or en-dash in prose (STYLE section 1):\n\n'
        fi
        found=$((found + 1))
        [ "$found" -le 40 ] && printf '   %s/%s\n      %s\n' \
            "${repo#.}" "${hit%%:*}" "$(printf '%s' "$trimmed" | cut -c1-100)"
    done < "$tmp"
done

if [ "$examined" -eq 0 ]; then
    printf 'check-dashes: nothing examined, which is not a pass\n' >&2
    exit 2
fi

if [ "$found" -gt 0 ]; then
    [ "$found" -gt 40 ] && printf '\n   ... and %s more\n' "$((found - 40))"
    printf '\nUse a hyphen. If the line is captured output or quoted from elsewhere, add it\n'
    printf 'to tools/dashes-allowed.txt, with a comment saying which.\n'
    printf '%s line(s) across %s files examined\n' "$found" "$examined"
    exit 1
fi

printf '%s files: no em-dash or en-dash outside the allowed lines\n' "$examined"
