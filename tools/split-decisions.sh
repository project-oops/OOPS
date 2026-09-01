#!/usr/bin/env bash
# Split a decision log into one file per decision, and regenerate its index.
#
#   tools/split-decisions.sh oops-libs        # split, then write docs/DECISIONS.md
#   tools/split-decisions.sh --index oops-libs   # regenerate the index only
#
# # Why one file per decision
#
# Two reasons, and the second is the one that costs money today.
#
# **They no longer render.** orbistoun's log is 1,053,440 bytes and obSCEne's is 634,607.
# GitHub stops rendering markdown well below that, so the durable memory these projects are
# built around shows as "we can't show files that are this big" in the one place a visitor
# looks.
#
# **Two sessions cannot append to one file without colliding.** That is where the duplicate
# numbers and out-of-order entries come from - 83 failures at the last count, and a whole
# subsection of the conventions ("when two sessions write the same log") written to cope with
# it. Two sessions writing two decisions never touch the same file, so the collision class
# disappears rather than being managed.
#
# Splitting is cheap here because **no citation is a link**: 6,067 references to `Dnnn` across
# the collection and one of them is a markdown anchor. The rest are prose a reader looks up,
# and the index is what they look it up in.
#
# # The status line
#
# Four repositories wrote it four ways - `*status: decided*`, `Status: measured.`,
# `**decided** - 2026-08-29 - ...`, and prosperous not at all. This reads all of them and
# writes one shape, because a status column nobody can parse is a column that stops being
# filled in.
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

# A rehearsal, for a log another session is writing into. Reports what the split would
# produce and touches nothing - the two repositories that most need splitting are the two
# it is least safe to split blind.
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
        | sed 's/.*[ :*]//' | tr 'A-Z' 'a-z' | sort | uniq -c | sort -rn \
        | while read -r n s; do printf ' %s=%s' "$s" "$n"; done
    echo
    exit 0
fi

repo="$ROOT/$project"
log="$repo/docs/DECISIONS.md"
dir="$repo/docs/decisions"
[ -d "$repo" ] || { printf 'no such project: %s\n' "$project" >&2; exit 2; }

# --- split ------------------------------------------------------------------------------
if [ "$index_only" -eq 0 ]; then
    [ -f "$log" ] || { printf 'no %s\n' "$log" >&2; exit 2; }
    # Refuse to split a file this tool already wrote. An index has no `## Dnnn` headings, so a
    # second split writes nothing and overwrites the index with an empty table - and the
    # entries it was indexing are still on disk, orphaned, with no way back from the source.
    if grep -q 'This table is generated' "$log" 2>/dev/null; then
        printf 'docs/DECISIONS.md is already an index. Use --index to regenerate it.\n' >&2
        exit 2
    fi
    mkdir -p "$dir"

    # One pass. Everything before the first `## Dnnn` is the log preamble and is kept beside the
    # entries, so the index can carry it. This said "and is kept" for a while above a variable
    # set to /dev/null, and thirteen documents across five repositories lost theirs - including
    # a note explaining why obSCEne decisions before D026 still name deleted tools, and two
    # explaining why undated entries are undated and must not be given invented dates.
    awk -v dir="$dir" -v preamble="$dir/_preamble.md" '
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
            gsub(/`/, "", t)
            gsub(/[^a-z0-9]+/, "-", t)
            gsub(/^-+|-+$/, "", t)
            # 40 characters, and never mid-word: a name ending "-none-of-" reads as though
            # the file were truncated too.
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


# --- recover missing titles ---------------------------------------------------------------
#
# Four repositories wrote the *heading* two ways as well as the status line. Most entries are
# `## Dnnn - Title`; some are a bare `## Dnnn` whose title is the bold sentence that opens the
# body. The split read only the first shape, so the second produced nine files literally named
# `D080-.md`, headed `# D080 - ` with the title sitting one line below, unread.
#
# Nothing was lost - the bold lead is still there in every one of them - but a decision you
# cannot find by name is most of the way to a decision nobody knows about, which is the exact
# failure the log exists to prevent.
#
# So the title is recovered from the lead and the file renamed. This runs after every split,
# not only on repair: the next log written in the second shape is handled rather than
# producing the same nine files again.
retitle() {
    local n=0 f base id title slug new
    for f in "$dir"/D*-.md; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"
        id="${base%%-*}"
        title="$(awk -f "$HERE/lib/recover-title.awk" "$f")"
        # No lead to recover means the entry opens with prose. Renaming it to a slug taken
        # from ordinary prose would read as a title somebody chose, so it keeps the empty
        # name and check-decisions.sh keeps reporting it - visible beats tidy.
        [ -n "$title" ] || { printf '  %s: no bold lead, left alone\n' "$base" >&2; continue; }
        slug="$(printf '%s' "$title" | tr 'A-Z' 'a-z' | tr -d '`' \
                | sed 's/[^a-z0-9]\+/-/g; s/^-\+//; s/-\+$//' \
                | cut -c1-40 | sed 's/-[^-]*$//')"
        new="$dir/$id-$slug.md"
        [ "$new" = "$f" ] && continue
        # `# Dnnn - ` with nothing after it is the line to repair, and only ever line 1.
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

# --- index ------------------------------------------------------------------------------
# Status is read from whatever shape the entry uses, then mapped onto one light. The word is
# kept beside the light: a terminal or an editor without emoji fonts shows an empty box, and a
# status column that reads as a blank is worse than no column.
#
# # Dates that were never written down
#
# Most entries carry no date - 241 of obSCEne's 285, 83 of SELFish's 87 - so a date column read
# straight from the entries is mostly empty, which is the same as not having one.
#
# A position in a numbered log is itself evidence: an entry between two dated entries was
# written between those dates. Where the two agree the day is settled, and 27 of orbistoun's 34
# gaps are that case. Where they do not, the honest answer is the span, not a point inside it -
# 104 of obSCEne's sit in a single `2026-08-20..2026-08-26` bracket, and picking a day out of
# six would be exactly the invented row section 5 is about.
#
# So derived dates are marked `~` and never written back into the entry. The entry stays
# undated, `check-decisions.sh` keeps reporting it, and the index shows what can be worked out
# without dressing it up as something somebody recorded.
rows="$(mktemp)"
trap 'rm -f "$rows"' EXIT

for f in $(find "$dir" -name 'D*.md' | sort); do
    base="$(basename "$f")"
    id="${base%%-*}"
    title="$(sed -n '1s/^# D[0-9]* - //p' "$f")"
    # Only the first few lines, and only a word from the known vocabulary. Reading the
    # whole body picked `**defined**` and "would" out of ordinary prose and presented
    # them as statuses, which is worse than recording none: an invented status is a
    # column somebody trusts.
    #
    # `head -1` is not belt-and-braces. `-m1` caps *matching lines*, not matches, and `-o`
    # prints one line per match - so a status naming two words ("decided, superseded")
    # returned two lines, put a newline into a tab-separated field, and split one row in
    # two. Thirty-five entries across the collection did that: a broken table row each,
    # and a fragment with no date column, which stopped the date search below dead at
    # the first one it met - which is why 65 of SELFish's 87 rows showed no date when a
    # dated entry sat four rows away.
    status="$(head -6 "$f" \
              | grep -m1 -ioE '\*{0,2}(status:?[ ]*)?\*{0,2}(decided|assumed|measured|derived|proposed|scoped|reversed|superseded|withdrawn|blocked|struck|confirmed|done|hardware)\*{0,2}\b' \
              2>/dev/null | sed 's/status:*//I; s/\*//g; s/[ :]//g' | tr 'A-Z' 'a-z' | head -1 || true)"
    # Same trap as the status line, and it bit here too: "decided - 2026-08-19, revised
    # 2026-08-20" is one line with two matches, so `-o` returned both and the field carried
    # a newline. Two orbistoun decisions vanished from their own index that way.
    date="$(grep -m1 -oE '20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]' "$f" 2>/dev/null | head -1 || true)"
    case "$status" in
        decided|measured|derived|done|hardware|confirmed) light='🟢' ;;
        assumed|proposed|scoped|open)                     light='🟡' ;;
        reversed|superseded|withdrawn|blocked|struck)     light='🔴' ;;
        *)                                                light='⚪'; status="${status:-unrecorded}" ;;
    esac
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$light" "$id" "$title" "$base" "$status" "${date:--}" >> "$rows"
done

{
    # The log preamble, replayed. It carries what the log says about itself - "read this at the
    # start of any working session", why entries before D026 still name deleted tools, why the
    # undated ones are undated - and a generated header cannot reconstruct any of it. Where a
    # log has none, the generic line below stands in.
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
        # A row is six fields. Anything else means a field carried a tab or a newline, and
        # indexing by NR would leave a hole that reads as "no date recorded" - the failure
        # above, silently. Count good rows separately and say so.
        NF != 6 { print "index: row " NR " has " NF " fields, not 6 - skipped" > "/dev/stderr"; next }
        { m++; light[m]=$1; id[m]=$2; title[m]=$3; base[m]=$4; status[m]=$5; date[m]=$6 }
        # A range reads better without saying 2026 twice, and the year is still there once.
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
