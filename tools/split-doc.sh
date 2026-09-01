#!/usr/bin/env bash
# Split a long document into one file per item, and regenerate it as an index with a status
# column.
#
#   tools/split-doc.sh selfish BACKLOG 2 backlog
#   tools/split-doc.sh orbistoun ROADMAP 2 roadmap
#   tools/split-doc.sh obscene MILESTONES 2 milestones
#   tools/split-doc.sh --index selfish BACKLOG 2 backlog
#
# Arguments: <project> <DOC> <heading-level> <subdirectory>.
#
# # Why the heading level is an argument
#
# These documents do not share a shape. SELFish's backlog is numbered `## N. Title`; orbistoun's
# is `## Category` with the actual items as `### Title`; obSCEne's milestones are `## date -
# Title`. One splitter with the level passed in fits all three; one splitter that guessed would
# be wrong for two of them.
#
# **Not every long document is a list of items.** Prosperous's roadmap is `## Wrong`,
# `## Missing`, `## Unmeasured` - categories holding prose, with no per-item status to put in a
# column. Splitting that would produce six files and a table saying nothing. It is left alone,
# and this tool is not applied to a document just because the document is long.
#
# # Status
#
# Read from the marker these documents already carry, in this order: a trailing `*(DONE)*` or
# `*(not done)*`, a `~~struck-through~~` title, or a trailing `- done` / `- deferred`. Nothing
# is invented: an item with no marker is recorded as having none, which is a fact about the
# document rather than a gap in the parser.
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
    # Refuse to split a file this tool already wrote. Splitting an index produces one file per
    # table row, each holding a link and nothing else, and the original headings are gone -
    # there is no undo, because the source was overwritten in the same run. Found by doing it:
    # SELFish's backlog had to be recovered from an unreachable blob.
    if grep -q 'This table is generated' "$src" 2>/dev/null; then
        printf '%s is already an index. Use --index to regenerate it, or split the entries.\n' \
            "docs/$doc.md" >&2
        exit 2
    fi
    mkdir -p "$dir"
    awk -v dir="$dir" -v hashes="$hashes" -v level="$level" '
        # Bodies move one directory deeper, so every relative link in them needs one more
        # `../`. Found by splitting obSCEne milestones: `../data/hardware/ps5-full.txt` was
        # right from docs/ and wrong from docs/milestones/, and `screenshots/x.png` stopped
        # resolving at all.
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
            # The file already carries a sequence prefix; a title beginning "7." would
            # repeat it as "07-7-...".
            sub(/^[0-9]+-/, "", t)
            if (length(t) > 40) { t = substr(t, 1, 40); sub(/-[^-]*$/, "", t) }
            return t
        }
        # Everything before the first item is the preamble: a title, and what the document says
        # about itself. It went to /dev/null, so the obSCEne worklog lost "Surprises are the most
        # valuable field" - a convention the sibling repositories still quote. Kept beside the
        # items and replayed into the index, which is where a reader was always going to look.
        # Links in it are not rewritten: it is only ever read back into docs/, so it already sits
        # at the depth its links assume.
        BEGIN { out = dir "/_preamble.md"; n = 0 }
        {
            # A heading at exactly the requested level, not deeper.
            if ($0 ~ ("^" hashes " ") && $0 !~ ("^" hashes "#")) {
                title = $0
                sub("^" hashes " +", "", title)
                n++
                # Always a sequence number, never the date. Naming dated entries by date and
                # undated ones by sequence puts them in one directory that sorts two ways:
                # the SELFish worklog has 41 undated entries and 2 dated, and date-naming
                # dropped those two into the middle of a chronological document. Order is
                # what a worklog means, so the filename preserves it and the date - where
                # there is one - goes in the index column.
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

# Does anything in this document carry a status marker? A worklog does not - every entry is
# a record of something already done - and a column of "no marker found" reads as a column of
# open items.
has_status=0
for f in $(find "$dir" -name '[0-9]*.md' | sort); do
    t="$(sed -n '1s/^# //p' "$f")"
    case "$t" in
        *'*('*|*'~~'*|*' - done'*|*' - DONE'*|*' - deferred'*) has_status=1; break ;;
    esac
done

{
    # The title came from the preamble when there was one - "# Work log", not the file name
    # shouted back. A generated header that quietly renames the document is a small lie a
    # reader has no way to check.
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
            # Dated document: the date is the useful column, and it is already the filename.
            date="$(printf '%s' "$title" | grep -oE '^20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]' || true)"
            clean="$(printf '%s' "$title" | sed 's/^20[0-9][0-9]-[0-9][0-9]-[0-9][0-9][ ]*-\{0,1\}[ ]*//')"
            printf '| %s | [%s](%s/%s) |\n' "${date:--}" "$clean" "$sub" "$base"
            continue
        fi

        # The marker the document already carries. Checked most specific first.
        status=""
        case "$title" in
            *'*(DONE'*|*'*(done'*)         status="done" ;;
            *'*(not done)*'*)              status="not done" ;;
            *'~~'*)                        status="done" ;;
            *' - done'*|*' - DONE'*)       status="done" ;;
            *' - deferred'*)               status="deferred" ;;
            *'*(begun)*'*|*'*(half done)*'*) status="begun" ;;
            *'*(answered'*|*'*(evaluated'*) status="answered" ;;
            # orbistoun's backlog closes an item by narrating it: "wrong, then fixed, now
            # closed". Recognised rather than normalised, because the sentence is the record.
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
            # No marker means no marker. Defaulting to "open" put a red light against "both
            # now run" and "censused, and now called" - items plainly in progress - and a
            # status the document never claimed is the same failure as an invented one, just
            # in a louder colour. Red is only for an explicit "not done".
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
