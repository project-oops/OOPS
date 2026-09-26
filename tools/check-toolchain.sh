#!/usr/bin/env bash
# Every C repository pins the same clang major (oops-mesa#D013).
#
#   tools/check-toolchain.sh
#
# A pin is `OOPS_CLANG_MAJOR := N` in `<repo>/toolchain.mk`, which some Makefile must
# include, or `FROM silkeh/clang:N` in `<repo>/toolchain/Dockerfile` for a repository whose
# runner is that container. A C repository with no pin fails, as does more than one major.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

# The repositories that compile C or C++. orbistoun's clang 18 is the reference toolchain
# for its shader fixtures, independent of the build compiler (orbistoun#D681).
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
        # The assignment only, not comments that mention it.
        major="$(sed -n 's/^OOPS_CLANG_MAJOR[[:space:]]*:=[[:space:]]*\([0-9][0-9]*\).*/\1/p' "$mk" | head -1)"
        if [ -z "$major" ]; then
            bad "$proj: toolchain.mk exists but declares no 'OOPS_CLANG_MAJOR := <n>'"
            continue
        fi
        pins["$proj"]="$major"
        note "$proj: clang $major (toolchain.mk)"

        # A pin file no Makefile includes pins nothing.
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

# One number, or list every repository's pin.
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
