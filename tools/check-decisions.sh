#!/usr/bin/env bash
# Check every project's decision log against OOPS conventions section 4.
#
#   tools/check-decisions.sh                 # all five
#   tools/check-decisions.sh selfish         # one
#   tools/check-decisions.sh --show-known    # enumerate the baseline too
#   tools/check-decisions.sh --update-baseline
#   tools/check-decisions.sh --prune-baseline  # drop keys that no longer fire, and only those
#
# Exit status is 0 only when nothing fails that is not already in the baseline.
#
# A convention that is only written down is a convention that drifts. Each of these
# repositories started dating decisions and quietly stopped, and two of them have logs whose
# entries are no longer in numeric order, which is what "append-only" was supposed to prevent.
# Nothing noticed, because nothing was looking.
#
# # Why there is a baseline
#
# The first version reported 370 failures, which was the right thing to do once. But it could
# never go green: 302 of those are undated entries whose dates cannot be recovered, because no
# repository here had commit history when they were written. A gate whose verdict is "fails"
# on every run it will ever have says exactly as much as one that has never fired - conventions
# section 8 makes that argument about a workflow on the wrong branch, and this is the same
# defect from the other side. It also buried the failures that are actionable under three
# hundred that are not.
#
# So the known set lives in `decisions-baseline.txt`, which is a **list and not a count** -
# section 5's objection is to numbers copied out of the thing that owns them, and a list the
# tool regenerates is not that.
#
# The baseline can only shrink. A key in it that no longer fires is itself a failure, because
# a baseline nobody prunes becomes a licence rather than a record.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
# oops-libs is not one of the four, but it keeps a decision log and is held to the same rules -
# a gate that skips the newest repository is a gate that drifts first.
PROJECTS="orbistoun obscene prosperous selfish oops-libs oops-sdk"
BASELINE="$HERE/decisions-baseline.txt"

show_known=0
update_baseline=0
prune_baseline=0
args=""
for a in "$@"; do
    case "$a" in
        --show-known)      show_known=1 ;;
        --update-baseline) update_baseline=1 ;;
        --prune-baseline)  prune_baseline=1 ;;
        --*) printf 'not a flag: %s\n' "$a" >&2; exit 2 ;;
        *)
            case " $PROJECTS " in
                *" $a "*) args="$args $a" ;;
                *) printf 'not a project: %s\n' "$a" >&2; exit 2 ;;
            esac
            ;;
    esac
done
WANTED="${args:-$PROJECTS}"
WANTED="$(printf '%s' "$WANTED" | sed 's/^ *//')"
full_run=0
[ "$WANTED" = "$PROJECTS" ] && full_run=1

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
found="$work/found"
: > "$found"

# --- one pass per log -------------------------------------------------------------------
#
# Emits `<project>|<ident>|<kind>|<line>|<detail>`. `ident` is `Dnnn`, or a run like
# `D337-D339`, or `-` for a whole-file finding; it is the half of the baseline key that has to
# survive somebody editing the file above it, which is why no line number goes in the key.
for project in $WANTED; do
    log="$ROOT/$project/docs/DECISIONS.md"
    split="$ROOT/$project/docs/decisions"

    # Two layouts, one set of rules. A split log is many files with `# Dnnn - Title`; an
    # unsplit one is a single file of `## Dnnn - Title`. Rather than two implementations of
    # section 4, the split layout is flattened into the shape the rules already read - so a
    # repository that splits does not quietly get a different standard.
    #
    # Two failure kinds stop being possible once split, which is most of the reason to do it:
    # entries cannot be out of order when each is its own file, and two sessions writing two
    # decisions never touch the same file, so they cannot collide into a duplicate.
    if [ -d "$split" ]; then
        # An appended entry in a generated index is invisible to everything below: the rules
        # read `docs/decisions/`, so a `## Dnnn` written into DECISIONS.md is checked by
        # nothing and overwritten by the next `--index` run. Somebody who has not noticed the
        # split yet will do exactly this, so it is reported rather than left to be discovered
        # by the decision going missing.
        if grep -qE '^## D[0-9]+' "$ROOT/$project/docs/DECISIONS.md" 2>/dev/null; then
            printf '%s|-|appended-to-index|0|%s\n' "$project" \
                "docs/DECISIONS.md is generated but has \`## Dnnn\` headings - move them into docs/decisions/" \
                >> "$found"
        fi
        log="$work/flat.$project"
        for f in $(find "$split" -name 'D*.md' | sort); do
            sed -n '1s/^# /## /p' "$f"
            head -8 "$f" | grep -m1 -oE '20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]' || true
        done > "$log"
    fi

    if [ ! -f "$log" ]; then
        printf '%s|-|no-log|0|no docs/DECISIONS.md\n' "$project" >> "$found"
        continue
    fi
    awk -v project="$project" '
        function ident(n) { return sprintf("D%03d", n) }
        function emit(id, kind, line, detail) {
            print project "|" id "|" kind "|" line "|" detail
        }

        # A heading, and the date that belongs to it. Every log puts status and date in the
        # first line or two; six lines of slack, not licence.
        /^## D[0-9]+/ {
            num = $0; sub(/^## D/, "", num); sub(/[^0-9].*$/, "", num); num = num + 0
            rest = $0; sub(/^## D[0-9]+/, "", rest)
            gsub(/^[ \t]+|[ \t]+$/, "", rest)

            n++
            enum[n] = num; eline[n] = NR; erest[n] = rest; edate[n] = ""
            want_date = 6; last_i = n
            next
        }
        want_date > 0 {
            if (match($0, /20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]/)) {
                edate[last_i] = substr($0, RSTART, RLENGTH)
                want_date = 0
            } else want_date--
        }

        END {
            if (n == 0) { emit("-", "empty-log", 0, "no `## Dnnn` entries"); exit }

            # 1. Append-only means numeric order.
            for (i = 2; i <= n; i++)
                if (enum[i] < enum[i-1])
                    emit(ident(enum[i]), "out-of-order", eline[i],
                         sprintf("out of order, follows D%03d", enum[i-1]))

            # 2. A repeated number makes every citation of it ambiguous.
            for (i = 1; i <= n; i++) {
                if (enum[i] in firstline)
                    emit(ident(enum[i]), "duplicate", eline[i],
                         sprintf("duplicate, first at line %d", firstline[enum[i]]))
                else firstline[enum[i]] = eline[i]
            }

            # 3. A gap is either a withdrawn decision - which should say so rather than vanish -
            #    or a number claimed somewhere else and never written up. Reported per RUN of
            #    consecutive numbers: append D999 to a log ending at D024 and per-number
            #    reporting prints nine hundred lines that all say the same thing.
            lo = hi = enum[1]
            for (i = 1; i <= n; i++) { if (enum[i] < lo) lo = enum[i]; if (enum[i] > hi) hi = enum[i] }
            run_start = 0
            for (v = lo; v <= hi + 1; v++) {
                gap = (v <= hi && !(v in firstline))
                if (gap && run_start == 0) run_start = v
                if (!gap && run_start != 0) {
                    run_end = v - 1
                    if (run_start == run_end)
                        emit(ident(run_start), "missing", 0, "missing from the run")
                    else
                        emit(sprintf("D%03d-D%03d", run_start, run_end), "missing", 0,
                             sprintf("D%03d..D%03d missing from the run (%d numbers)",
                                     run_start, run_end, run_end - run_start + 1))
                    run_start = 0
                }
            }

            # 4. No commit history predates the first push, so the date on an entry is the
            #    only record of when it was made.
            for (i = 1; i <= n; i++)
                if (edate[i] == "") emit(ident(enum[i]), "undated", eline[i], "undated")

            # 5. Dates that run backwards mean either the order is wrong or a date is.
            prev = ""
            for (i = 1; i <= n; i++) {
                if (edate[i] == "") continue
                if (prev != "" && edate[i] < prev)
                    emit(ident(enum[i]), "date-backwards", eline[i],
                         sprintf("dated %s, after D%03d dated %s", edate[i], prevnum, prev))
                prev = edate[i]; prevnum = enum[i]
            }

            # 6. A heading with no title is a heading you cannot skim. The strip set carries
            #    both dash marks because the logs predate the house style and contain both.
            for (i = 1; i <= n; i++) {
                t = erest[i]
                gsub(/^[ \t---]+|[ \t---]+$/, "", t)
                if (t == "") emit(ident(enum[i]), "untitled", eline[i], "heading carries no title")
            }
        }
    ' "$log" >> "$found"
done

# --- baseline ---------------------------------------------------------------------------
keyfile="$work/keys"
awk -F'|' '{print $1 " " $2 " " $3}' "$found" | sort -u > "$keyfile"

if [ "$update_baseline" -eq 1 ]; then
    if [ "$full_run" -ne 1 ]; then
        printf -- '--update-baseline rewrites the whole file, so it needs every project\n' >&2
        exit 2
    fi
    {
        sed -n '1,/^$/p' "$BASELINE" 2>/dev/null | grep '^#' || true
        printf '\n'
        sort -k1,1 -k3,3 -k2,2 "$keyfile"
    } > "$work/newbase"
    mv "$work/newbase" "$BASELINE"
    printf 'baseline rewritten: %s keys\n' "$(grep -c . "$keyfile")"
    exit 0
fi

known="$work/known"
if [ -f "$BASELINE" ]; then
    sed 's/#.*//' "$BASELINE" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep . | sort -u > "$known"
else
    : > "$known"
fi


# `--update-baseline` rewrites the file from whatever fires today, which grows it as readily as
# it shrinks it - run it with eighty unfixed failures on disk and all eighty become "known".
# That is the one operation the paragraph above forbids, and it was the only one on offer.
#
# This removes keys that no longer fire and touches nothing else. A baseline can shrink by
# itself; it can only grow by somebody deciding, in a diff, that it should.
if [ "$prune_baseline" -eq 1 ]; then
    if [ "$full_run" -ne 1 ]; then
        printf -- '--prune-baseline compares against every project, so it needs all of them\n' >&2
        exit 2
    fi
    gone="$(comm -23 "$known" "$keyfile" || true)"
    if [ -z "$gone" ]; then
        printf 'baseline: nothing stale\n'
        exit 0
    fi
    # Comments and blank lines are kept: the header explains why the file exists, and a
    # pruning tool that eats the explanation is how the next reader learns nothing.
    awk -v gone="$gone" '
        BEGIN { n = split(gone, g, "\n"); for (i = 1; i <= n; i++) if (g[i] != "") dead[g[i]] = 1 }
        /^#/ || /^[[:space:]]*$/ { print; next }
        { key = $0; sub(/#.*/, "", key); gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
          if (!(key in dead)) print }
    ' "$BASELINE" > "$work/pruned"
    mv "$work/pruned" "$BASELINE"
    printf 'baseline pruned: %s keys dropped, %s remain\n' \
        "$(printf '%s\n' "$gone" | grep -c .)" "$(sed 's/#.*//' "$BASELINE" | grep -c .)"
    exit 0
fi
new_count=0
for project in $WANTED; do
    pnew="$work/new.$project"; pknown="$work/known.$project"
    : > "$pnew"; : > "$pknown"
    while IFS='|' read -r p id kind line detail; do
        [ "$p" = "$project" ] || continue
        # Name the file the reader has to open. For a split log the rules ran over a
        # flattened copy, so its line numbers point into a temporary file that no longer
        # exists - reporting them sends somebody to a line that corresponds to nothing.
        # The entry file is what they want, and the number resolves to exactly one.
        entry=""
        if [ "$id" != "-" ] && [ -d "$ROOT/$p/docs/decisions" ]; then
            entry="$(find "$ROOT/$p/docs/decisions" -name "${id}-*.md" 2>/dev/null | head -1)"
        fi
        if [ -n "$entry" ]; then
            where="$p/docs/decisions/$(basename "$entry")"
        else
            where="$p/docs/DECISIONS.md"
            [ "$line" != "0" ] && where="$where:$line"
            [ "$id" != "-" ] && where="$where $id"
        fi
        if grep -Fxq -- "$p $id $kind" "$known"; then
            printf '%s: %s\n' "$where" "$detail" >> "$pknown"
        else
            printf '%s: %s\n' "$where" "$detail" >> "$pnew"
        fi
    done < "$found"

    n="$(grep -c . "$pnew" || true)"
    k="$(grep -c . "$pknown" || true)"
    if [ "$n" -eq 0 ]; then
        if [ "$k" -gt 0 ]; then printf '%-11s ok (%s known)\n' "$project" "$k"
        else printf '%-11s ok\n' "$project"; fi
    else
        printf '%-11s %s new, %s known\n' "$project" "$n" "$k"
        sed 's|^|   |' "$pnew"
    fi
    [ "$show_known" -eq 1 ] && sed 's|^|   known: |' "$pknown"
    new_count=$((new_count + n))
done

# A baseline key that no longer fires is stale, and stale is what section 5 is about. Only
# meaningful on a full run: a filtered one cannot tell "fixed" from "not looked at".
stale=""
if [ "$full_run" -eq 1 ]; then
    stale="$(comm -23 "$known" "$keyfile" || true)"
fi
if [ -n "$stale" ]; then
    printf '\nbaseline no longer fires - drop these lines, or run --update-baseline:\n'
    printf '%s\n' "$stale" | sed 's|^|   |'
fi

printf '\nnew failures: %s\n' "$new_count"
[ "$new_count" -eq 0 ] && [ -z "$stale" ]
