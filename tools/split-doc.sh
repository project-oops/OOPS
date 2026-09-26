#!/usr/bin/env bash
# Split a document into one file per heading, and regenerate it as an index.
#
#   tools/split-doc.sh <project> <DOC> <heading-level> <subdirectory>
#   tools/split-doc.sh --index obscene WORKLOG 2 worklog
#
# Headings at <heading-level> in docs/<DOC>.md become docs/<subdirectory>/NNN-title.md; the
# text before the first goes to `_preamble.md`. The index lists each item with its date, or
# with a status read from a marker in its title (`*(DONE)*`, `~~struck~~`, `- deferred`)
# when any item carries one.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

index_only=0
argv=""
for a in "$@"; do
    case "$a" in
        --index) index_only=1 ;;
        --*) printf 'not a flag: %s\n' "$a" >&2; exit 2 ;;
        *) argv="$argv $a" ;;
    esac
done
# shellcheck disable=SC2086
set -- $argv
[ "$#" -eq 4 ] || { printf 'usage: split-doc.sh [--index] <project> <DOC> <level> <subdir>\n' >&2; exit 2; }

project="$1"; doc="$2"; level="$3"; sub="$4"
repo="$ROOT/$project"
src="$repo/docs/$doc.md"
dir="$repo/docs/$sub"
hashes="$(printf '%*s' "$level" '' | tr ' ' '#')"

[ -f "$src" ] || { printf 'no %s\n' "$src" >&2; exit 2; }

if [ "$index_only" -eq 0 ]; then
    # Splitting a generated index would overwrite the source with an empty table.
    if grep -q 'This table is generated' "$src" 2>/dev/null; then
        printf '%s is already an index. Use --index to regenerate it, or split the entries.\n' \
            "docs/$doc.md" >&2
        exit 2
    fi
    mkdir -p "$dir"
    awk -v dir="$dir" -v hashes="$hashes" -v level="$level" '
        # Bodies move one directory deeper, so each relative link gains a `../`.
        function relink(line,   out, rest, m, target, pre) {
            out = ""
            rest = line
            while (match(rest, /\]\([^)]+\)/)) {
                pre = substr(rest, 1, RSTART + 1)
                m = substr(rest, RSTART + 2, RLENGTH - 3)
                rest = substr(rest, RSTART + RLENGTH)
                if (m !~ /^(https?:|mailto:|#|\/)/) m = "../" m
                out = out pre m ")"
            }
            return out rest
        }
        function slugify(s,   t) {
            t = tolower(s)
            gsub(/~~|`|\*/, "", t)
            gsub(/[^a-z0-9]+/, "-", t)
            gsub(/^-+|-+$/, "", t)
            # The file name already carries a sequence number.
            sub(/^[0-9]+-/, "", t)
            if (length(t) > 40) { t = substr(t, 1, 40); sub(/-[^-]*$/, "", t) }
            return t
        }
        # The preamble is replayed into docs/, so its links are not rewritten.
        BEGIN { out = dir "/_preamble.md"; n = 0 }
        {
            # A heading at exactly the requested level, not deeper.
            if ($0 ~ ("^" hashes " ") && $0 !~ ("^" hashes "#")) {
                title = $0
                sub("^" hashes " +", "", title)
                n++
                # Files are named by sequence, so document order is kept; a leading date
                # goes to the index column.
                rest = title
                sub(/^20[0-9][0-9]-[0-9][0-9]-[0-9][0-9][ 	]*-?[ 	]*/, "", rest)
                out = sprintf("%s/%03d-%s.md", dir, n, slugify(rest))
                printf "# %s\n\n", title > out
                next
            }
            print relink($0) > out
        }
    ' "$src"
    # A document that opened straight into its first item leaves nothing but blank lines here.
    grep -q '[^[:space:]]' "$dir/_preamble.md" 2>/dev/null || rm -f "$dir/_preamble.md"
    printf 'split %s/%s: %s items -> docs/%s/\n' "$project" "$doc" \
        "$(find "$dir" -name '[0-9]*.md' | wc -l)" "$sub"
fi

# A status column only when some item carries a marker.
has_status=0
for f in $(find "$dir" -name '[0-9]*.md' | sort); do
    t="$(sed -n '1s/^# //p' "$f")"
    case "$t" in
        *'*('*|*'~~'*|*' - done'*|*' - DONE'*|*' - deferred'*) has_status=1; break ;;
    esac
done

{
    # The preamble supplies the title; without one, the document name.
    if [ -s "$dir/_preamble.md" ]; then
        cat "$dir/_preamble.md"
    else
        printf '# %s\n\n' "$doc"
    fi
    printf '**This table is generated.** Edit an item under `%s/`, then run\n' "$sub"
    printf '`tools/split-doc.sh --index %s %s %s %s`.\n\n' "$project" "$doc" "$level" "$sub"
    if [ "$has_status" -eq 1 ]; then
        printf '| | item | status |\n|---|---|---|\n'
    else
        printf '| date | entry |\n|---|---|\n'
    fi

    for f in $(find "$dir" -name '[0-9]*.md' | sort); do
        base="$(basename "$f")"
        title="$(sed -n '1s/^# //p' "$f")"

        if [ "$has_status" -eq 0 ]; then
            date="$(printf '%s' "$title" | grep -oE '^20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]' || true)"
            clean="$(printf '%s' "$title" | sed 's/^20[0-9][0-9]-[0-9][0-9]-[0-9][0-9][ ]*-\{0,1\}[ ]*//')"
            printf '| %s | [%s](%s/%s) |\n' "${date:--}" "$clean" "$sub" "$base"
            continue
        fi

        # Most specific marker first.
        status=""
        case "$title" in
            *'*(DONE'*|*'*(done'*)         status="done" ;;
            *'*(not done)*'*)              status="not done" ;;
            *'~~'*)                        status="done" ;;
            *' - done'*|*' - DONE'*)       status="done" ;;
            *' - deferred'*)               status="deferred" ;;
            *'*(begun)*'*|*'*(half done)*'*) status="begun" ;;
            *'*(answered'*|*'*(evaluated'*) status="answered" ;;
            *'now closed)*'*)              status="done" ;;
        esac
        case "$title" in
            'Not planned'*|'Not yet'*|'Not doing'*) status="not planned" ;;
        esac
        case "$status" in
            done)             light='\xf0\x9f\x9f\xa2' ;;
            begun)            light='\xf0\x9f\x9f\xa1' ;;
            "not done")       light='\xf0\x9f\x94\xb4' ;;
            deferred|answered|"not planned") light='\xe2\x9a\xaa' ;;
            # No marker is not "open"; red is only for an explicit "not done".
            *)                light='\xe2\x9a\xaa'; status="no marker" ;;
        esac
        clean="$(printf '%s' "$title" | sed 's/[ ]*\*([^)]*)\*//g; s/~~//g; s/[ ]*- done.*$//; s/[ ]*- deferred.*$//')"
        printf "| $(printf "$light") | [%s](%s/%s) | %s |\n" "$clean" "$sub" "$base" "$status"
    done

    if [ "$has_status" -eq 1 ]; then
        printf '\n'
        printf '| | meaning |\n|---|---|\n'
        printf "| $(printf '\xf0\x9f\x9f\xa2') | done |\n"
        printf "| $(printf '\xf0\x9f\x9f\xa1') | begun |\n"
        printf "| $(printf '\xf0\x9f\x94\xb4') | open, or explicitly not done |\n"
        printf "| $(printf '\xe2\x9a\xaa') | deferred, not planned, or carrying no marker either way |\n"
    fi
} > "$src"

printf 'index: %s items -> docs/%s.md\n' "$(find "$dir" -name '[0-9]*.md' | wc -l)" "$doc"
