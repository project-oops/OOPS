#!/usr/bin/env bash
# Every workflow that touches a project's source uses the standard OOPS preamble.
#
#   tools/check-workflows.sh            # every member
#   tools/check-workflows.sh selfish
#
# Projects resolve their siblings by relative path, so a job that builds must check out OOPS
# and OOPS/<project>, run `oops bootstrap <project>`, run `OOPS/bin/oops` from the workspace
# root and `./bin/...` from OOPS/<project>. Steps are judged whole, since
# `working-directory:` may follow `run:`. Jobs that check nothing out are skipped. The
# preamble is in docs/BUILDING.md.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
PROJECTS="orbistoun obscene prosperous selfish oops-libs oops-sdk oops-apps"

if [ "$#" -gt 0 ]; then
    for want in "$@"; do
        case " $PROJECTS " in
            *" $want "*) ;;
            *) printf 'unknown project %s. One of: %s\n' "$want" "$PROJECTS" >&2; exit 2 ;;
        esac
    done
    WANTED="$*"
else
    WANTED="$PROJECTS"
fi

examined=0
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

for proj in $WANTED; do
    dir="$ROOT/$proj/.github/workflows"
    [ -d "$dir" ] || continue
    for wf in "$dir"/*.yml "$dir"/*.yaml; do
        [ -f "$wf" ] || continue
        examined=$((examined + 1))
        rel="$proj/.github/workflows/$(basename "$wf")"

        awk -v proj="$proj" -v rel="$rel" '
            function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
            function value(line,   v) {
                v = line; sub(/^[^:]*:[[:space:]]*/, "", v); gsub(/["'"'"',]/, "", v)
                return trim(v)
            }

            # Judge the step that just ended.
            function close_step(   wd) {
                if (!in_step) return
                wd = (step_wd != "" ? step_wd : job_wd)
                if (step_oops && wd != "" && wd != ".")
                    bad_wd = bad_wd " " wd
                if (step_binrun && wd != ("OOPS/" proj))
                    bad_bin = bad_bin " [" (wd == "" ? "workspace root" : wd) "]"
                in_step = 0; step_wd = ""; step_oops = 0; step_binrun = 0
            }

            function close_job() {
                close_step()
                if (job == "" || !has_run || !has_checkout) return
                if (!has_oops || !has_self)
                    print rel " / " job ": checkout paths do not include both OOPS and OOPS/" proj
                if (!has_boot)
                    print rel " / " job ": no `oops bootstrap " proj "` step"
                if (bad_wd != "")
                    print rel " / " job ": runs OOPS/bin/oops from" bad_wd " - resolves to <that>/OOPS/bin/oops"
                if (bad_bin != "")
                    print rel " / " job ": runs ./bin/... from" bad_bin ", not OOPS/" proj
            }

            /^jobs:[[:space:]]*$/ { injobs = 1; next }
            injobs && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
                close_job()
                job = $1; sub(/:$/, "", job)
                has_oops = has_self = has_boot = has_run = has_checkout = 0
                job_wd = ""; bad_wd = ""; bad_bin = ""; in_defaults = 0
                next
            }
            job == "" { next }

            # `defaults:` is job level (four spaces); any key at that depth ends it.
            /^    defaults:[[:space:]]*$/ { in_defaults = 1; next }
            /^    [A-Za-z]/ { in_defaults = 0 }
            in_defaults && /working-directory:/ { job_wd = value($0); next }

            # A step begins at a `- ` under `steps:`.
            /^ +- / { close_step(); in_step = 1 }

            in_step && /working-directory:/ { step_wd = value($0) }
            in_step && /OOPS\/bin\/oops/    { step_oops = 1 }
            in_step && /run:[[:space:]]*\.\/bin\// { step_binrun = 1 }

            /uses:[[:space:]]*actions\/checkout/     { has_checkout = 1 }
            /path:[[:space:]]*OOPS[[:space:]]*$/     { has_oops = 1 }
            $0 ~ ("path:[[:space:]]*OOPS/" proj "[[:space:]]*$") { has_self = 1 }
            /oops bootstrap/ { has_boot = 1 }
            /run:/           { has_run = 1 }

            END { close_job() }
        ' "$wf" >> "$tmp"
    done
done

if [ "$examined" -eq 0 ]; then
    printf 'check-workflows: no workflows found - nothing was examined, which is not a pass\n' >&2
    exit 2
fi

problems="$(grep -c . "$tmp" || true)"
if [ "$problems" -gt 0 ]; then
    printf 'workflows that cannot build what they check out:\n\n'
    sed 's/^/   /' "$tmp"
    printf '\nSee docs/BUILDING.md for the standard preamble.\n'
    printf '%s problem(s) across %s workflow(s)\n' "$problems" "$examined"
    exit 1
fi

printf '%s workflows: preamble correct, bootstrap present\n' "$examined"
