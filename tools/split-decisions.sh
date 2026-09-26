#!/usr/bin/env bash
# Split a decision log into one file per decision, and regenerate its index.
#
#   tools/split-decisions.sh oops-libs        # split, then write docs/DECISIONS.md
#   tools/split-decisions.sh --index oops-libs   # regenerate the index only
#   tools/split-decisions.sh --retitle oops-libs # name untitled entries, then index
#   tools/split-decisions.sh --dry-run oops-libs # report what a split would produce
#
# Splitting turns `## Dnnn - Title` sections of docs/DECISIONS.md into
# docs/decisions/Dnnn-title.md, keeping the text before the first entry as `_preamble.md`.
# The index is a table of every entry's status and date, with the preamble above it.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

index_only=0
retitle_only=0
dry_run=0
project=""
for a in "$@"; do
    case "$a" in
        --index) index_only=1 ;;
        --retitle) retitle_only=1; index_only=1 ;;
        --dry-run) dry_run=1 ;;
        --*) printf 'not a flag: %s\n' "$a" >&2; exit 2 ;;
        *) project="$a" ;;
    esac
done
[ -n "$project" ] || { printf 'usage: split-decisions.sh [--index|--retitle] <project>\n' >&2; exit 2; }

if [ "$dry_run" -eq 1 ]; then
    log="$ROOT/$project/docs/DECISIONS.md"
    [ -f "$log" ] || { echo "no $log" >&2; exit 2; }
    entries="$(grep -cE '^## D[0-9]+' "$log")"
    bytes="$(wc -c < "$log")"
    echo "$project: $entries entries, $bytes bytes -> docs/decisions/ + a generated index"
    echo "  first: $(grep -m1 -E '^## D[0-9]+' "$log")"
    echo "  last:  $(grep -E '^## D[0-9]+' "$log" | tail -1)"
    printf '  statuses:'
    grep -ohiE '^\*{0,2}(status:)?[ ]*\*{0,2}(decided|assumed|measured|derived|proposed|reversed|superseded)' "$log" \
        | sed 's/.*[ :*]//' | tr '[:upper:]' '[:lower:]' | sort | uniq -c | sort -rn \
        | while read -r n s; do printf ' %s=%s' "$s" "$n"; done
    echo
    exit 0
fi

repo="$ROOT/$project"
log="$repo/docs/DECISIONS.md"
dir="$repo/docs/decisions"
[ -d "$repo" ] || { printf 'no such project: %s\n' "$project" >&2; exit 2; }

if [ "$index_only" -eq 0 ]; then
    [ -f "$log" ] || { printf 'no %s\n' "$log" >&2; exit 2; }
    # Splitting a generated index would overwrite it with an empty table.
    if grep -q 'This table is generated' "$log" 2>/dev/null; then
        printf 'docs/DECISIONS.md is already an index. Use --index to regenerate it.\n' >&2
        exit 2
    fi
    mkdir -p "$dir"

    # Everything before the first `## Dnnn` goes to `_preamble.md`.
    awk -v dir="$dir" -v preamble="$dir/_preamble.md" '
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
            gsub(/`/, "", t)
            gsub(/[^a-z0-9]+/, "-", t)
            gsub(/^-+|-+$/, "", t)
            # At most 40 characters, cut at a word boundary.
            if (length(t) > 40) {
                t = substr(t, 1, 40)
                sub(/-[^-]*$/, "", t)
            }
            return t
        }
        BEGIN { out = preamble }
        /^## D[0-9]+/ {
            num = $0; sub(/^## D/, "", num); sub(/[^0-9].*$/, "", num)
            title = $0; sub(/^## D[0-9]+[ \t]*-?[ \t]*/, "", title)
            slug = slugify(title)
            out = sprintf("%s/D%03d-%s.md", dir, num + 0, slug)
            printf "# D%03d - %s\n", num + 0, title > out
            printf "\n" > out
            next
        }
        { print relink($0) > out }
    ' "$log"

    printf 'split %s: %s entries -> docs/decisions/\n' "$project" \
        "$(find "$dir" -name 'D*.md' | wc -l)"
fi

# An entry headed by a bare `## Dnnn` splits to `Dnnn-.md`. Its title is taken from the
# bold lead of its body (lib/recover-title.awk), and the file renamed.
retitle() {
    local n=0 f base id title slug new
    for f in "$dir"/D*-.md; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"
        id="${base%%-*}"
        title="$(awk -f "$HERE/lib/recover-title.awk" "$f")"
        # With no bold lead the file keeps its empty name, and check-decisions.sh reports it.
        [ -n "$title" ] || { printf '  %s: no bold lead, left alone\n' "$base" >&2; continue; }
        slug="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | tr -d '`' \
                | sed 's/[^a-z0-9]\+/-/g; s/^-\+//; s/-\+$//' \
                | cut -c1-40 | sed 's/-[^-]*$//')"
        new="$dir/$id-$slug.md"
        [ "$new" = "$f" ] && continue
        sed -i "1s|^# ${id} - *$|# ${id} - ${title}|" "$f"
        if [ -e "$new" ]; then
            printf '  %s: %s already exists - two entries share a number\n' "$base" "$(basename "$new")" >&2
            continue
        fi
        mv "$f" "$new"
        n=$((n + 1))
    done
    [ "$n" -gt 0 ] && printf 'retitled %s: %s entries recovered from their bold lead\n' "$project" "$n"
    return 0
}
retitle
[ "$retitle_only" -eq 1 ] && index_only=1

# The index. Each entry's status maps onto a coloured light, with the word kept beside it.
# An undated entry shows a date derived from its dated neighbours, marked `~` and never
# written back into the entry.
rows="$(mktemp)"
trap 'rm -f "$rows"' EXIT

# The status words a banner line may use.
VOCABULARY='decided|assumed|measured|derived|proposed|scoped|reversed|superseded|withdrawn|blocked|struck|confirmed|done|hardware|published|guest-observed'

for f in $(find "$dir" -name 'D*.md' | sort); do
    base="$(basename "$f")"
    id="${base%%-*}"
    title="$(sed -n '1s/^# D[0-9]* - //p' "$f")"
    # A status is declared by a `Status: <word>` line anywhere (emphasis stripped first), or
    # by a banner: a line in the header that begins with an emphasised vocabulary word.
    # Anything else is `unrecorded`. `head -1` everywhere, since `-o` prints one line per
    # match and a second match would split the row.
    labelled="$(sed 's/[*_]//g' "$f" \
                | sed -n -E 's/^[[:space:]]*[Ss]tatus[[:space:]]*:[[:space:]]*([A-Za-z][A-Za-z-]*).*/\1/p' \
                2>/dev/null | head -1 || true)"
    banner="$(sed -n '2,6p' "$f" \
              | sed -n -E "s/^[[:space:]]*(>[[:space:]]*)?[*_]{1,2}($VOCABULARY)\b.*/\2/Ip" \
              2>/dev/null | head -1 || true)"
    status="$(printf '%s' "${labelled:-$banner}" | tr '[:upper:]' '[:lower:]')"
    date="$(grep -m1 -oE '20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]' "$f" 2>/dev/null | head -1 || true)"
    case "$status" in
        # `published` and `guest-observed` are orbistoun's provenance grades, and settled.
        decided|measured|derived|done|hardware|confirmed|published|guest-observed) light='🟢' ;;
        assumed|proposed|scoped|open)                     light='🟡' ;;
        reversed|superseded|withdrawn|blocked|struck)     light='🔴' ;;
        *)                                                light='⚪'; status="${status:-unrecorded}" ;;
    esac
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$light" "$id" "$title" "$base" "$status" "${date:--}" >> "$rows"
done

# shellcheck disable=SC2016 # markdown with literal backticks
{
    # The preamble, or a generic heading when there is none.
    if [ -s "$dir/_preamble.md" ]; then
        cat "$dir/_preamble.md"
        printf '\n'
    else
        printf '# Decisions\n\n'
        printf 'Every non-obvious choice, numbered, with the reasoning - which is what stops it\n'
        printf 'being re-litigated by somebody who only has the choice.\n\n'
    fi
    printf '**This table is generated.** Edit an entry under `decisions/`, then run\n'
    printf '`tools/split-decisions.sh --index %s`. A number resolves to exactly one file.\n\n' "$project"
    printf '| | # | decision | status | date |\n'
    printf '|---|---|---|---|---|\n'

    awk -F'\t' '
        # A row is six fields; any other row is reported and skipped.
        NF != 6 { print "index: row " NR " has " NF " fields, not 6 - skipped" > "/dev/stderr"; next }
        { m++; light[m]=$1; id[m]=$2; title[m]=$3; base[m]=$4; status[m]=$5; date[m]=$6 }
        # A date range, with a shared year written once.
        function span(lo, hi) {
            if (substr(lo,1,5) == substr(hi,1,5)) return lo ".." substr(hi,6)
            return lo ".." hi
        }
        END {
            n = m
            for (i = 1; i <= n; i++) {
                d = date[i]
                if (d == "-") {
                    lo = ""; hi = ""
                    for (j = i-1; j >= 1; j--) if (date[j] != "-") { lo = date[j]; break }
                    for (j = i+1; j <= n; j++) if (date[j] != "-") { hi = date[j]; break }
                    if (lo != "" && hi != "") d = (lo == hi) ? "~" lo : "~" span(lo, hi)
                    else if (lo != "")        d = "~>" lo
                    else if (hi != "")        d = "~<" hi
                }
                printf "| %s | %s | [%s](decisions/%s) | %s | %s |\n",
                    light[i], id[i], title[i], base[i], status[i], d
            }
        }
    ' "$rows"

    printf '\n'
    printf '| | meaning |\n|---|---|\n'
    printf '| 🟢 | settled, and the reasoning rests on something checkable |\n'
    printf '| 🟡 | assumed or proposed - made without input, and in the review queue |\n'
    printf '| 🔴 | reversed, superseded or blocked |\n'
    printf '| ⚪ | no status recorded |\n\n'
    printf 'A date with `~` is **not recorded** - it is worked out from the dated entries either\n'
    printf 'side, because an entry between two of them was written between their dates. `~` alone\n'
    printf 'is a day both neighbours agree on; `~a..b` is a span, and no day inside it is claimed;\n'
    printf '`~>a` and `~<a` are entries with a dated neighbour on only one side. A bare `-` has no\n'
    printf 'dated entry either side to reason from.\n'
} > "$log"

derived="$(grep -c '| ~' "$log" || true)"
printf 'index: %s entries -> docs/DECISIONS.md' "$(find "$dir" -name 'D*.md' | wc -l)"
[ "$derived" -gt 0 ] && printf ' (%s dates derived from position)' "$derived"
printf '\n'
