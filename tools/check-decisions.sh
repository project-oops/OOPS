#!/usr/bin/env bash
# Check every project's decision log against OOPS STYLE, section 4 (decisions).
#
#   tools/check-decisions.sh                 # every member
#   tools/check-decisions.sh selfish         # one
#   tools/check-decisions.sh --show-known    # enumerate the baseline too
#   tools/check-decisions.sh --update-baseline
#   tools/check-decisions.sh --prune-baseline  # drop keys that no longer fire, and only those
#
# Checks numeric order, duplicate numbers, a date and a title on every entry. Exits 0 only
# when every failure is listed in `decisions-baseline.txt`, a list of known failures that
# may only shrink: a listed key that no longer fires is itself a failure.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
PROJECTS="orbistoun obscene prosperous selfish oops-libs oops-sdk oops-apps oops-mesa"
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

# One pass per log, emitting `<project>|<ident>|<kind>|<line>|<detail>`. `ident` is `Dnnn`
# or `-` for a whole-file finding; the baseline key omits the line so edits do not move it.
for project in $WANTED; do
    log="$ROOT/$project/docs/DECISIONS.md"
    split="$ROOT/$project/docs/decisions"

    # A split log (`docs/decisions/Dnnn-*.md`, headed `# Dnnn - Title`) is flattened into the
    # single-file `## Dnnn - Title` shape the rules read.
    if [ -d "$split" ]; then
        # DECISIONS.md is then a generated index; an entry written into it is lost.
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

        # A heading, and its date within the next six lines.
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

            # Gaps and date order are not checked: a decision that changes is edited and
            # redated in place, and one that no longer holds is deleted (STYLE, decisions).

            # 3. Every entry carries a date.
            for (i = 1; i <= n; i++)
                if (edate[i] == "") emit(ident(enum[i]), "undated", eline[i], "undated")

            # 4. Every heading carries a title.
            for (i = 1; i <= n; i++) {
                t = erest[i]
                gsub(/^[ \t---]+|[ \t---]+$/, "", t)
                if (t == "") emit(ident(enum[i]), "untitled", eline[i], "heading carries no title")
            }
        }
    ' "$log" >> "$found"
done

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
    sed 's/#.*//' "$BASELINE" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | { grep . || true; } |
        sort -u > "$known"
else
    : > "$known"
fi

# Drop keys that no longer fire, and nothing else; unlike --update-baseline it cannot grow
# the baseline.
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
    # Comments and blank lines are kept.
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
        # For a split log, name the entry file; line numbers point into the flattened copy.
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

# Stale baseline keys, on a full run only: a filtered run cannot tell fixed from unexamined.
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
