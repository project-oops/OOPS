#!/usr/bin/env bash
# One compiler across the collection, and every repository says the same number.
#
#   tools/check-toolchain.sh
#
# # Why this gate exists
#
# Until 2026-09-21 the pin was ambient. `oops-sdk/Makefile`, `obscene/Makefile` and
# `oops-apps/common/app.mk` all said bare `CC := clang`, and `oops-mesa/toolchain/Dockerfile`
# said `FROM silkeh/clang:18`. So the same source built with clang 21 under WSL `oops-builder`
# and clang 18 under Docker, and which one you got depended on where you were standing. Nothing
# in the tree preferred either, and three documents asserted a pin that no build enforced.
#
# The per-repository fix is `toolchain.mk`, which refuses to build against the wrong major.
# That makes each repository internally honest and does nothing about the repositories
# disagreeing with *each other*, which is the failure that actually happened. This gate is the
# other half: it reads every pin the collection declares and fails when they are not one
# number. (oops-mesa#D013)
#
# # Where a pin is allowed to live
#
# Two shapes, because the two runners are genuinely different things:
#
#   * `<repo>/toolchain.mk`, as `OOPS_CLANG_MAJOR := N`   - repositories that compile directly
#   * `oops-mesa/toolchain/Dockerfile`, as `FROM silkeh/clang:N` - the container is that
#     repository's runner, so its tag *is* its pin and a `toolchain.mk` beside it would be a
#     second place to be wrong
#
# # A repository with no pin is a finding, not a pass
#
# The whole defect was a pin nobody enforced, so "this one declares nothing" must be louder
# than "this one declares 21", not quieter. An unpinned repository that compiles is reported
# and fails the gate. `tools/check-decisions.sh` set this precedent: it failed on the tree it
# was written against, because the defects were already there.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

# The repositories that compile C or C++ and therefore owe a pin. The Rust-only members
# (prosperous, selfish, oops-libs) are not here: they are pinned by `rust-toolchain` and this
# gate would have nothing to read.
#
# **orbistoun is excluded on purpose and is not Rust-only.** It pins `silkeh/clang:18` as the
# *reference* toolchain that reproduces its committed shader fixtures, where the version is part
# of the expected output rather than a means to it - LLVM 18 and 19 already disagree about the
# first word of every compute fixture. Checking it here would report a deliberate decision as
# drift and invite somebody to "fix" it. The reasoning is `orbistoun#D681`, which names this
# gate back.
PROJECTS="obscene oops-sdk oops-apps oops-mesa"

fail=0
declare -A pins

note() { printf '%s\n' "$*"; }
bad()  { printf '%s\n' "$*" >&2; fail=1; }

for proj in $PROJECTS; do
    dir="$ROOT/$proj"
    [ -d "$dir" ] || { bad "$proj: not checked out at $dir"; continue; }

    mk="$dir/toolchain.mk"
    dockerfile="$dir/toolchain/Dockerfile"

    if [ -f "$mk" ]; then
        # The assignment, not a mention of it: `grep OOPS_CLANG_MAJOR` also matches the prose
        # above the assignment in every one of these files.
        major="$(sed -n 's/^OOPS_CLANG_MAJOR[[:space:]]*:=[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$mk" | head -1)"
        if [ -z "$major" ]; then
            bad "$proj: toolchain.mk exists but declares no 'OOPS_CLANG_MAJOR := <n>'"
            continue
        fi
        pins["$proj"]="$major"
        note "$proj: clang $major (toolchain.mk)"

        # A pin file nothing includes is the "definition nothing calls" failure: it passes
        # every gate and changes no build. Prove something reaches it.
        if ! grep -rqF 'toolchain.mk' --include='Makefile' --include='*.mk' "$dir" \
             --exclude='toolchain.mk'; then
            bad "$proj: toolchain.mk is included by no Makefile, so it pins nothing"
        fi

    elif [ -f "$dockerfile" ]; then
        major="$(sed -n 's|^FROM[[:space:]][[:space:]]*silkeh/clang:\([0-9][0-9]*\).*|\1|p' "$dockerfile" | head -1)"
        if [ -z "$major" ]; then
            bad "$proj: toolchain/Dockerfile has no 'FROM silkeh/clang:<n>' to read a pin from"
            continue
        fi
        pins["$proj"]="$major"
        note "$proj: clang $major (toolchain/Dockerfile)"

    else
        bad "$proj: declares no compiler pin (no toolchain.mk, no toolchain/Dockerfile)"
    fi
done

# One number, or name every distinct one. Printing the set rather than "they differ" is what
# makes the message actionable without a second command.
if [ "${#pins[@]}" -gt 0 ]; then
    distinct="$(printf '%s\n' "${pins[@]}" | sort -u)"
    if [ "$(printf '%s\n' "$distinct" | wc -l)" -ne 1 ]; then
        bad ""
        bad "toolchain: the collection declares more than one clang major:"
        for proj in "${!pins[@]}"; do
            bad "    $proj -> ${pins[$proj]}"
        done
        bad "One compiler, or the C++ standard library and the shader fixtures disagree about"
        bad "what they were built by. See oops-mesa#D013."
    fi
fi

if [ "$fail" -ne 0 ]; then
    exit 1
fi

note "toolchain: every pin agrees"
