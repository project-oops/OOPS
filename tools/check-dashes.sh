#!/usr/bin/env bash
# No em-dash or en-dash in prose. See CONVENTIONS section 8, "Dashes are hyphens".
#
#   tools/check-dashes.sh            # all five repositories, plus OOPS itself
#   tools/check-dashes.sh selfish
#
# # Why this is a gate and not a habit
#
# Two marks were in use for the same job and the split ran roughly along repository lines
# without anybody deciding it - SELFish leaned em-dash, the other four leaned hyphen, and
# every repository used both in the hundreds. 3,231 were converted in one pass before
# anything was published, which is the only moment that is cheap. The next one arrives one
# document at a time, and a convention nobody checks is a preference.
#
# # What is allowed to keep a dash
#
# An allow list of exact lines in `tools/dashes-allowed.txt`, not a pattern: a pattern would
# quietly forgive the next one too. Each entry is a fact rather than prose - the decision-log
# parser's own strip set, the convention that has to quote it, and two lines lifted verbatim
# from another project's source.
#
# A fenced block is NOT exempt as a class. A captured session is evidence and keeps its
# dashes; a hand-written comment inside an illustrative block is prose. Nothing can tell those
# apart by looking at the fence, so a new one goes in the allow file deliberately.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
PROJECTS="orbistoun obscene prosperous selfish oops-libs"
ALLOW="$HERE/dashes-allowed.txt"

# The marks this refuses, written out. That means this file contains what it forbids and
# reports itself, so it is excluded from its own scan by the pathspec below - the right answer
# to the wrong question, and cheaper than five allow entries explaining a checker to itself.
#
# `$'\uXXXX'` would keep them out of the file, and was tried: bash resolves it, but the escape
# does not survive being written here by anything that also resolves it. Not worth the trouble
# for a line nobody reads twice.
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
    # `git grep` reads the working tree for tracked files, and its exit status is 1 for "no
    # match" - which is the passing case here, so it must not end the run under `set -e`.
    #
    # `-n` for the line number, `-I` so a binary never reaches the output. The pathspec keeps
    # this to text: a `.png` cannot hold prose, and `tools/dashes-allowed.txt` holds the very
    # lines being excluded.
    status=0
    git -C "$dir" grep -nI -e "$EM" -e "$EN" -- \
        '*.md' '*.rs' '*.c' '*.h' '*.sh' '*.py' '*.toml' '*.yml' '*.html' \
        ':!tools/dashes-allowed.txt' ':!tools/check-dashes.sh' > "$tmp" 2>/dev/null || status=$?
    if [ "$status" -gt 1 ]; then
        printf 'check-dashes: git grep failed in %s (exit %s) - NOT clean, just unread\n' \
            "$repo" "$status" >&2
        exit 2
    fi
    examined=$((examined + $(git -C "$dir" ls-files -- '*.md' '*.rs' '*.c' '*.h' '*.sh' '*.py' '*.toml' '*.yml' '*.html' | wc -l)))

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
            printf 'em-dash or en-dash in prose (CONVENTIONS section 8):\n\n'
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
