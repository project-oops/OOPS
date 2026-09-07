#!/usr/bin/env bash
# setup-wsl.sh - make a machine able to build the three C repositories.
#
#   tools/setup-wsl.sh              # WSL's Ubuntu distribution if there is none, then the toolchain
#   tools/setup-wsl.sh --dry-run    # say what it would do, and change nothing
#   tools/setup-wsl.sh --inside     # the Linux half alone, which is also what runs on Linux
#
# `./bin/oops setup` is this script, and `./bin/oops doctor` is how you find out whether it
# worked. Everything here is install-if-missing, so a run that stops halfway is run again
# rather than unpicked.
#
# # Two halves, and why `--inside` is both of them
#
# On Windows there is an outer half and an inner half. The outer half is about WSL: whether it
# is there, whether it holds a distribution, and whether that distribution is one the
# collection's expectations hold for. The inner half is the toolchain, and it is the same list
# whether it runs inside WSL or on a Linux machine directly. So `--inside` names both "the
# part that runs in the distribution" and "the whole of what a Linux machine needs", and there
# is one copy of the list rather than two that drift.
#
# # Why Ubuntu, and why not something smaller
#
# Alpine would compile the payloads. It would also be wrong, and quietly:
#
#   * **obSCEne's host harness is a glibc differential.** `make check` builds `obscene-host`
#     against the host C library and judges what comes back, and its decision log records
#     those expectations in glibc's terms - errno being thread-local, the value of the
#     recursive mutex constant, which censused names resolve at all. Against musl the harness
#     still measures correctly and disagrees with every one of those entries, which is the
#     worst shape a wrong answer can take.
#   * **The collection already names Ubuntu.** CI is `ubuntu-latest`, obSCEne's own scripts
#     say `wsl.exe -d Ubuntu`, and its CLAUDE.md gives the toolchain as an `apt-get` line. The
#     house rule is that the command a person runs and the command CI runs are one command,
#     and a different distribution is a quiet way to make them two.
#
# Debian would behave the same. Ubuntu is what the documents name, so Ubuntu is what this
# installs, and a distribution that is neither is reported rather than worked around.
#
# # What this does not do, deliberately
#
#   * **It does not enable the WSL feature.** That needs an elevated prompt and usually a
#     reboot, so it is named and handed back rather than half-attempted from a shell that
#     cannot finish it.
#   * **It does not install rustup on the Windows side.** The three Rust projects build there
#     too, but a Windows rustup wants the MSVC build tools, which is a download measured in
#     gigabytes and somebody else's licence to accept.
#
# # A distribution of its own, called oops-builder, running as root
#
# It does not install "Ubuntu". Somebody's WSL is theirs, and an Ubuntu they already have may
# hold their work, their packages and their account; a setup script that installs that name
# either collides with it or quietly adopts it and starts changing it. This registers
# `oops-builder` from the Ubuntu image instead, which says what it is for, cannot be mistaken
# for anything a person set up, and is thrown away whole with one command:
#
#     wsl --unregister oops-builder
#
# Inside it, root. A distribution with one job has one occupant, and an account would exist
# only to own a rustup - at the cost of choosing somebody a password. So the toolchain goes
# into root's home, `run_via_wsl` finds it there because `$HOME/.cargo/env` is whatever home
# the shell has, and `[user] default=root` is pinned in `/etc/wsl.conf` so that an interactive
# `wsl -d oops-builder` never starts asking for a username either.
#
# None of that touches a distribution somebody else made. Point `WSL_DISTRO` at your own and
# this installs the toolchain there, as you, and rewrites none of its configuration.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$HERE")"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'; DIM=$'\033[2m'; OFF=$'\033[0m'
else
    BOLD=""; RED=""; GREEN=""; DIM=""; OFF=""
fi

step() { printf '\n%s=== %s%s\n' "$BOLD" "$*" "$OFF"; }
note() { printf '%s%s%s\n' "$DIM" "$*" "$OFF"; }
ok()   { printf '  %sok%s   %s\n' "$GREEN" "$OFF" "$*"; }
bad()  { printf '  %s--%s   %s\n' "$RED" "$OFF" "$*"; }
die()  { printf '\n%serror:%s %s\n' "$RED" "$OFF" "$*" >&2; exit 1; }

# In dry-run, say it instead of doing it. Every mutating command in this script goes through
# here, so there is one place that decides, rather than a `$DRY` test at each call site with
# one of them eventually missing.
DRY=0
run() {
    if [ "$DRY" -eq 1 ]; then
        printf '  %swould run:%s %s\n' "$DIM" "$OFF" "$*"
        return 0
    fi
    "$@"
}

# What the target-side build needs, and why each one. A list with no reasons is a list nobody
# dares to trim.
#
#   clang lld        the cross-compile itself: freestanding C for a FreeBSD-derived target
#   binutils         `ar` builds oops-sdk's archive; `readelf` is what obSCEne's scripts read
#   gcc libc6-dev    cargo invokes `cc` to link build scripts even when everything else is
#                    clang, so a clang-only box fails with a wall of "could not compile
#                    <crate> (build script)" and no mention of a missing linker. obSCEne's
#                    CLAUDE.md calls this the non-obvious one, having been caught by it
#   make             obSCEne, oops-sdk and every app under oops-apps are Makefiles
#   clang-format     obSCEne's format gate runs it in CI
#   zip unzip        the package job and oops-apps' release job stage archives
#   python3          obscene/scripts/build-pkg.sh shells out to it for one generated file.
#                    The collection has no Python and does not intend to; this is one script
#                    reaching for it, and Ubuntu ships it regardless
#   curl ca-certificates
#                    rustup's installer arrives over https, and a distribution image thin
#                    enough to omit curl would fail there rather than here
PACKAGES="clang lld binutils gcc libc6-dev make clang-format zip unzip python3 curl ca-certificates"

# The rust components the gates need. `cargo` and `rustc` come with the toolchain; these do
# not, and `oops lint` and `oops fmt` are what notice.
RUST_COMPONENTS="clippy rustfmt"

# The distribution this creates, and the image it is made from.
#
# **A name of its own, rather than `Ubuntu`.** Somebody's WSL is theirs. They may already have
# an Ubuntu with their work in it, their packages and their account, and a setup script that
# installs "Ubuntu" either collides with that or silently adopts it and starts changing it.
# `oops-builder` says what it is for, cannot be confused with anything a person set up
# themselves, and can be thrown away whole - `wsl --unregister oops-builder` - without anybody
# having to work out what else was in there.
#
# `--name` needs WSL 2.4 or newer. Older than that is reported rather than worked around.
DISTRO_NAME="${OOPS_WSL_NAME:-oops-builder}"
DISTRO_IMAGE="${OOPS_WSL_IMAGE:-Ubuntu}"

# Where its disk goes. Unset means WSL's own choice, which is the right default; this exists
# because the VHD grows to several gigabytes and not every machine wants that on C:.
DISTRO_LOCATION="${OOPS_WSL_LOCATION:-}"

is_windows() {
    case "$(uname -s 2>/dev/null || echo unknown)" in
        MINGW*|MSYS*|CYGWIN*) return 0 ;;
        *) return 1 ;;
    esac
}

# ---------------------------------------------------------------------------------------
# The inner half: the toolchain, in a Debian-family Linux. Runs inside WSL, or directly on a
# Linux machine, and does not know or care which.
# ---------------------------------------------------------------------------------------

# Refuse a distribution the collection's expectations do not hold for, and say which
# expectation. The header has the argument; this is where it is enforced.
check_distro() {
    local id="" like=""
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        id="$(. /etc/os-release 2>/dev/null && printf '%s' "${ID:-}")"
        like="$(. /etc/os-release 2>/dev/null && printf '%s' "${ID_LIKE:-}")"
    fi
    case " $id $like " in
        *" debian "*|*" ubuntu "*) ok "distribution: ${id:-unknown}" ; return 0 ;;
    esac
    if [ -z "$id" ]; then
        bad "no /etc/os-release, so this is not a Linux this script can install packages on"
    else
        bad "distribution is '$id', and this installs with apt-get"
    fi
    printf '\n'
    printf 'The collection expects a Debian-family, glibc distribution. obSCEne'"'"'s host harness\n'
    printf 'is a differential against the host C library and its decision log records what it\n'
    printf 'expects in glibc'"'"'s terms, so a musl distribution measures correctly and disagrees\n'
    printf 'with every one of those entries. Install %s beside this one:\n\n' "$DISTRO_DEFAULT"
    printf '    wsl --install -d %s\n\n' "$DISTRO_DEFAULT"
    return 1
}

# Debian's own answer to "is this installed", rather than looking for the program: a package
# can be present with its binary under a name this script does not know, and `command -v
# libc6-dev` was never going to find anything at all.
package_missing() {
    [ "$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null)" != "installed" ]
}

inner() {
    step "the toolchain"
    check_distro || return 1

    command -v apt-get >/dev/null 2>&1 || {
        bad "no apt-get"
        return 1
    }

    local sudo="" p want=""
    if [ "$(id -u)" != "0" ]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo="sudo"
        else
            bad "not root, and no sudo - cannot install packages"
            return 1
        fi
    fi

    for p in $PACKAGES; do
        if package_missing "$p"; then want="$want $p"; fi
    done

    if [ -z "$want" ]; then
        ok "every package already installed"
    else
        note "  installing:${want}"
        # `apt-get update` only when something is actually going to be installed. It is the
        # slow half of this on a machine that is already set up, and running it to install
        # nothing is how a re-run stops being cheap enough to bother with.
        run $sudo apt-get update -qq || { bad "apt-get update failed"; return 1; }
        # shellcheck disable=SC2086
        run $sudo apt-get install -y -qq $want || { bad "apt-get install failed"; return 1; }
        ok "packages installed"
    fi

    step "rust"
    # rustup rather than the distribution's rustc: the projects pin components through
    # rustup, and a distro-packaged cargo is the one obSCEne's notes record refusing a
    # version-4 lock file and reporting it as a parse error rather than as a version problem.
    if command -v rustup >/dev/null 2>&1 || [ -x "$HOME/.cargo/bin/rustup" ]; then
        ok "rustup already installed"
    elif [ "$DRY" -eq 1 ]; then
        printf '  %swould run:%s curl --proto =https --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal\n' "$DIM" "$OFF"
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal ||
            { bad "rustup install failed"; return 1; }
        ok "rustup installed"
    fi

    # rustup writes this and a login shell sources it, but this shell started before it
    # existed. Without it the component step below cannot find the rustup that was just
    # installed, and the failure reads as rustup not having installed at all.
    if [ -f "$HOME/.cargo/env" ]; then
        # shellcheck disable=SC1091
        . "$HOME/.cargo/env"
    fi

    if command -v rustup >/dev/null 2>&1; then
        # Idempotent by rustup's own design: adding a component that is present is a no-op
        # that exits 0, so there is nothing to check first.
        # shellcheck disable=SC2086
        run rustup component add $RUST_COMPONENTS || { bad "rustup component add failed"; return 1; }
        ok "components: $RUST_COMPONENTS"
    elif [ "$DRY" -eq 0 ]; then
        bad "rustup is still not on PATH"
        return 1
    fi

    verify
}

# What the machine can actually do now, asked of the machine rather than inferred from the
# steps having exited 0. Conventions section 3: a step that ran is not a capability, and the
# difference is the whole reason `doctor` exists.
verify() {
    step "what this machine can do now"
    local rc=0 t
    for t in clang ld.lld make cc ar; do
        if command -v "$t" >/dev/null 2>&1; then ok "$t"; else bad "$t missing"; rc=1; fi
    done
    for t in cargo rustc; do
        if command -v "$t" >/dev/null 2>&1; then ok "$t"; else bad "$t missing"; rc=1; fi
    done
    for t in clang-format zip python3; do
        if command -v "$t" >/dev/null 2>&1; then ok "$t"; else bad "$t missing"; rc=1; fi
    done
    if [ "$rc" -ne 0 ] && [ "$DRY" -eq 1 ]; then
        note "  (dry run: nothing was installed, so this is the state before, not after)"
        return 0
    fi
    return "$rc"
}

# ---------------------------------------------------------------------------------------
# The outer half: WSL, on Windows.
# ---------------------------------------------------------------------------------------

# A Windows path as WSL sees it. The same translation `bin/oops` does in `run_via_wsl`, and
# repeated here rather than shared because this script has to work on a machine where nothing
# else does yet. Both copies exist for one trap: `cygpath -m` and not `-w`, because the
# backslashes in a Windows path are eaten before wslpath sees them and it answers a mangled
# path rather than failing.
to_wsl_path() {
    local distro="$1" win out
    win="$(cygpath -m "$2")"
    # **`-d`, and this one cost a whole run.** Windows drives are not mounted at the same
    # place in every distribution, and `wslpath` answers for the one it is asked. Without
    # `-d` that is WSL's default - Docker Desktop's appliance on this machine, which mounts
    # them under `/mnt/host/c`. The translation came back correct for Docker and meaningless
    # for the builder, which reported `No such file or directory` for a script that is plainly
    # there. Ask the distribution the path is actually for.
    out="$(MSYS_NO_PATHCONV=1 wsl.exe -d "$distro" wslpath -a "$win" 2>/dev/null | tr -d '\r\0')"
    case "$out" in
        /*) printf '%s' "$out" ;;
        # The default mount root, when wslpath could not be asked. wslpath is preferred
        # because it honours a non-default `root =` in wsl.conf, which this cannot know.
        *)  printf '%s' "$2" | sed 's|^/\([a-zA-Z]\)/|/mnt/\1/|' ;;
    esac
}

# Every distribution WSL holds that a person could build in, one per line. `--list --quiet`
# prints nothing at all when there are none - the "no installed distributions" text does not
# go anywhere a pipe can read it - so an empty answer is the test rather than a string to
# match. `tr` strips the UTF-16 padding and the carriage returns from a real answer.
#
# **A container runtime's own distributions do not count**, and this is not a nicety. Docker
# Desktop registers `docker-desktop` on the WSL2 backend, and Rancher and podman do the same
# under their own names. They are appliances: minimal, Alpine in Docker's case, and not
# somewhere anybody's toolchain goes. Counting them turns "WSL has a distribution" into a
# false yes on a machine that still cannot build anything, which is exactly the plausible
# wrong answer conventions section 3 is about. `bin/oops` filters the same names in `doctor`,
# and both lists are written out rather than shared because this script has to work on a
# machine where nothing else does yet.
distros() {
    MSYS_NO_PATHCONV=1 wsl.exe --list --quiet 2>/dev/null | tr -d '\r\0' |
        sed '/^[[:space:]]*$/d' |
        grep -viE '^(docker-desktop(-data)?|rancher-desktop(-data)?|podman-machine.*)$' || true
}

# The distribution to work in, in order of preference:
#
#   1. WSL_DISTRO, when somebody has said outright which one they mean
#   2. the one this script makes, when it is there - a machine with `oops-builder` on it has
#      already answered this question
#   3. WSL's own default, but only when that is one a person could build in. Installing Docker
#      Desktop makes `docker-desktop` the default on a machine that had no other, and handing
#      the toolchain to Docker's Alpine appliance fails somewhere much less obvious than here
#   4. the first usable one, which is also the fallback if that `*` marker changes shape
#
# The `*` in `--list --verbose` marks the default. It is a marker rather than a word, so it
# survives a Windows in any language, which the word beside it would not.
#
# `bin/oops` picks by the identical rule and says so. If the two ever disagreed, this would
# install the toolchain into one distribution and every build would look for it in another.
target_distro() {
    if [ -n "${WSL_DISTRO:-}" ]; then printf '%s' "$WSL_DISTRO"; return 0; fi
    local marked usable
    usable="$(distros)"
    if printf '%s\n' "$usable" | grep -qxF "$DISTRO_NAME"; then
        printf '%s' "$DISTRO_NAME"
        return 0
    fi
    marked="$(MSYS_NO_PATHCONV=1 wsl.exe --list --verbose 2>/dev/null | tr -d '\r\0' |
        awk '/^\*/ { print $2; exit }')"
    if [ -n "$marked" ] && printf '%s\n' "$usable" | grep -qxF "$marked"; then
        printf '%s' "$marked"
        return 0
    fi
    printf '%s\n' "$usable" | head -1
}

outer() {
    step "WSL"

    command -v wsl.exe >/dev/null 2>&1 || {
        bad "no wsl.exe on this machine"
        printf '\n'
        printf 'WSL is a Windows feature and enabling it needs an elevated prompt and a reboot,\n'
        printf 'which is why this script names it rather than attempting it. In an Administrator\n'
        printf 'PowerShell:\n\n'
        printf '    wsl --install\n\n'
        printf 'Reboot, then run this again.\n'
        return 1
    }

    if ! MSYS_NO_PATHCONV=1 wsl.exe --status >/dev/null 2>&1; then
        bad "wsl.exe is there but not working"
        printf '\n'
        printf 'The launcher exists and the feature behind it does not answer, which is the state\n'
        printf 'a half-enabled WSL leaves behind. In an Administrator PowerShell:\n\n'
        printf '    wsl --install\n\n'
        printf 'Reboot, then run this again.\n'
        return 1
    fi
    ok "wsl.exe present"

    local have
    have="$(distros)"
    [ -n "$have" ] && note "  other distributions here: $(printf '%s' "$have" | tr '\n' ' ')"

    if ! printf '%s\n' "$have" | grep -qxF "$DISTRO_NAME"; then
        step "installing $DISTRO_NAME"
        # Only for installs made after it, so it is set here rather than reported: an existing
        # version-1 distribution is somebody's decision and not this script's to change.
        run env MSYS_NO_PATHCONV=1 wsl.exe --set-default-version 2 >/dev/null 2>&1 || true

        # `--no-launch`, and this was learned the hard way. Without it `wsl --install` ends by
        # starting the distribution so it can ask for a username and a password, and a shell
        # that is not a terminal never answers: the install sits there, every later call to
        # that distribution queues behind it, and killing the caller leaves an orphaned client
        # still holding it. The symptom is that the whole of WSL stops responding, which names
        # nothing. Registered and never launched, there is no prompt to miss.
        local -a install_cmd
        install_cmd=(env MSYS_NO_PATHCONV=1 wsl.exe --install "$DISTRO_IMAGE"
                     --name "$DISTRO_NAME" --no-launch)
        [ -n "$DISTRO_LOCATION" ] && install_cmd+=(--location "$DISTRO_LOCATION")
        note "  $DISTRO_IMAGE, registered as $DISTRO_NAME, not launched"
        run "${install_cmd[@]}" || {
            bad "installing $DISTRO_NAME failed"
            printf '\n'
            printf 'If that reported an unrecognised option, this WSL is older than 2.4 and cannot\n'
            printf 'name a distribution. `wsl --version` says which it is; updating Windows or\n'
            printf '`wsl --update` is the fix, and installing %s by hand is the way round it.\n' "$DISTRO_IMAGE"
            return 1
        }
        if [ "$DRY" -eq 1 ]; then
            note "  (dry run: the toolchain would then be installed inside it)"
            return 0
        fi
        ok "$DISTRO_NAME registered"
    else
        ok "$DISTRO_NAME already registered"
    fi

    local distro
    distro="$(target_distro)"
    [ -n "$distro" ] || die "WSL reports no distribution to work in, even after installing one"
    note "  working in: $distro"

    # **Root, deliberately, and only in the distribution this script made.**
    #
    # A named build distribution has one job and one occupant. Creating an account in it would
    # mean choosing a password on somebody's behalf, and the account would exist only to own a
    # rustup - so the toolchain goes in root's home and `run_via_wsl` finds it there, because
    # `$HOME/.cargo/env` is whatever home the shell has.
    #
    # `[user] default=root` is written rather than assumed. A fresh Ubuntu image with no
    # account still carries its first-run setup, and an interactive `wsl -d oops-builder` would
    # otherwise start asking for a username - the same prompt this script exists to keep clear
    # of. Pinning the default retires it.
    #
    # Only when this is the distribution named here. Somebody who points WSL_DISTRO at their
    # own Ubuntu gets their own user and their own home, and nothing rewrites their config.
    if [ "$DRY" -eq 0 ] && [ "$distro" = "$DISTRO_NAME" ]; then
        MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' wsl.exe -d "$distro" -u root -- \
            bash -c 'grep -q "^default *= *root" /etc/wsl.conf 2>/dev/null ||
                     printf "\n[user]\ndefault=root\n" >> /etc/wsl.conf' ||
            { bad "could not pin the default user in $distro"; return 1; }
        ok "runs as root, which is what a build distribution is for"
    fi

    step "handing over to $distro"
    local self
    self="$(to_wsl_path "$distro" "$HERE/setup-wsl.sh")"
    note "  $self --inside"

    # MSYS_NO_PATHCONV, or Git Bash rewrites the `/mnt/c/...` argument on its way to a Windows
    # program and wsl.exe is handed a path under Git's own installation directory. It then
    # reports that the script does not exist, having never been asked about the real one.
    #
    # `bash -lc` and not `bash <path>`: a login shell is what puts an already-installed
    # rustup on PATH, so a second run finds what the first one installed.
    local args="--inside"
    [ "$DRY" -eq 1 ] && args="--inside --dry-run"
    MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' wsl.exe -d "$distro" -- \
        bash -lc "bash '$self' $args"
}

usage() {
    sed -n '2,6p' "$0" | sed 's|^# \{0,1\}||'
    exit "${1:-0}"
}

MODE=auto
while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) DRY=1 ;;
        --inside)  MODE=inside ;;
        -h|--help|help) usage ;;
        *) printf 'unknown option: %s\n\n' "$1" >&2; usage 1 ;;
    esac
    shift
done

rc=0
if [ "$MODE" = inside ]; then
    inner || rc=$?
elif is_windows; then
    outer || rc=$?
else
    # A Linux machine needs only the inner half, and that is not a special case worth a
    # branch of its own: it is the same list, run directly rather than through WSL.
    inner || rc=$?
fi

if [ "$rc" -eq 0 ]; then
    if [ "$DRY" -eq 1 ]; then
        printf '\n%sthat is the plan%s - run it again without --dry-run\n' "$GREEN" "$OFF"
    else
        printf '\n%sready%s - now: %s./bin/oops doctor%s\n' "$GREEN" "$OFF" "$BOLD" "$OFF"
        note "then ./bin/oops check obscene, which is the first thing that uses any of it"
    fi
else
    printf '\n%snot finished%s - the step above says what is left\n' "$RED" "$OFF" >&2
fi
exit "$rc"
