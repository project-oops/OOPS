#!/usr/bin/env bash
# setup-wsl.sh - make a machine able to build the three C repositories.
#
#   tools/setup-wsl.sh              # WSL's Ubuntu distribution if there is none, then the toolchain
#   tools/setup-wsl.sh --dry-run    # say what it would do, and change nothing
#   tools/setup-wsl.sh --inside     # the Linux half alone, which is also what runs on Linux
#
# Run as `./bin/oops setup`; `./bin/oops doctor` checks the result. Every step installs only
# what is missing, so an interrupted run is simply run again. On Windows it registers a WSL
# distribution `oops-builder` from the Ubuntu image (removed with `wsl --unregister
# oops-builder`), runs it as root, and installs the toolchain inside; on Linux it installs
# the toolchain directly. A Debian-family glibc distribution is required, since obSCEne's
# host harness is a differential against glibc. WSL_DISTRO names an existing distribution
# to use instead, whose configuration is left alone. Enabling the WSL feature needs an
# elevated prompt and a reboot, so it is left to the user.
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

# Every mutating command goes through here; in dry-run it is printed instead.
DRY=0
run() {
    if [ "$DRY" -eq 1 ]; then
        printf '  %swould run:%s %s\n' "$DIM" "$OFF" "$*"
        return 0
    fi
    "$@"
}

# What the build needs:
#
#   clang lld        the cross-compile
#   binutils         `ar` for oops-sdk's archive, `readelf` for obSCEne's scripts
#   gcc libc6-dev    cargo links build scripts with `cc`
#   make             obSCEne, oops-sdk and the apps are Makefiles
#   clang-format     the C format gates
#   zip unzip        release and package archives
#   python3          obscene/scripts/build-pkg.sh generates one file with it
#   curl ca-certificates
#                    the rustup installer
PACKAGES="clang lld binutils gcc libc6-dev make clang-format zip unzip python3 curl ca-certificates"

# The rust components the gates need beyond the minimal profile.
RUST_COMPONENTS="clippy rustfmt"

# The distribution this creates, and its image; its own name, so no existing Ubuntu is
# touched. `--name` needs WSL 2.4 or newer.
DISTRO_NAME="${OOPS_WSL_NAME:-oops-builder}"
DISTRO_IMAGE="${OOPS_WSL_IMAGE:-Ubuntu}"

# Where its virtual disk goes; unset leaves it to WSL.
DISTRO_LOCATION="${OOPS_WSL_LOCATION:-}"

is_windows() {
    case "$(uname -s 2>/dev/null || echo unknown)" in
        MINGW*|MSYS*|CYGWIN*) return 0 ;;
        *) return 1 ;;
    esac
}

# The inner half: the toolchain, in a Debian-family Linux, inside WSL or not.

# Refuse a distribution that is not Debian-family.
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
    printf 'with every one of those entries. Install %s beside this one:\n\n' "$DISTRO_IMAGE"
    printf '    wsl --install -d %s\n\n' "$DISTRO_IMAGE"
    return 1
}

# Asks dpkg, since a package name need not be a program name.
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
        # `apt-get update` only when something is to be installed, so a re-run is fast.
        run $sudo apt-get update -qq || { bad "apt-get update failed"; return 1; }
        # shellcheck disable=SC2086
        run $sudo apt-get install -y -qq $want || { bad "apt-get install failed"; return 1; }
        ok "packages installed"
    fi

    step "rust"
    # rustup, not the distribution's cargo, which is too old for the lock files.
    if command -v rustup >/dev/null 2>&1 || [ -x "$HOME/.cargo/bin/rustup" ]; then
        ok "rustup already installed"
    elif [ "$DRY" -eq 1 ]; then
        printf '  %swould run:%s curl --proto =https --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal\n' "$DIM" "$OFF"
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal ||
            { bad "rustup install failed"; return 1; }
        ok "rustup installed"
    fi

    # Puts a rustup installed by this run on PATH.
    if [ -f "$HOME/.cargo/env" ]; then
        # shellcheck disable=SC1091
        . "$HOME/.cargo/env"
    fi

    if command -v rustup >/dev/null 2>&1; then
        # Adding a present component is a no-op.
        # shellcheck disable=SC2086
        run rustup component add $RUST_COMPONENTS || { bad "rustup component add failed"; return 1; }
        ok "components: $RUST_COMPONENTS"
    elif [ "$DRY" -eq 0 ]; then
        bad "rustup is still not on PATH"
        return 1
    fi

    verify
}

# Checks each tool is now on PATH, rather than trusting the install steps' exit codes.
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

# The outer half: WSL, on Windows. The helpers below repeat bin/oops's, since this script
# runs on machines where bin/oops cannot.

# A Windows path as a distribution sees it. `cygpath -m`, since wslpath loses the
# backslashes of `-w` output; `-d`, since each distribution mounts the drives in its own place.
to_wsl_path() {
    local distro="$1" win out
    win="$(cygpath -m "$2")"
    out="$(MSYS_NO_PATHCONV=1 wsl.exe -d "$distro" wslpath -a "$win" 2>/dev/null | tr -d '\r\0')"
    case "$out" in
        /*) printf '%s' "$out" ;;
        # The default mount root; wslpath honours a `root =` in wsl.conf.
        *)  printf '%s' "$2" | sed 's|^/\([a-zA-Z]\)/|/mnt/\1/|' ;;
    esac
}

# The WSL distributions a toolchain can go in, one per line; empty when there are none.
# Container runtimes' appliance distributions (Docker Desktop, Rancher, podman) are excluded.
distros() {
    MSYS_NO_PATHCONV=1 wsl.exe --list --quiet 2>/dev/null | tr -d '\r\0' |
        sed '/^[[:space:]]*$/d' |
        grep -viE '^(docker-desktop(-data)?|rancher-desktop(-data)?|podman-machine.*)$' || true
}

# The distribution to work in, in order of preference:
#
#   1. WSL_DISTRO
#   2. the one this script creates
#   3. WSL's default (marked `*` in `--list --verbose`), when it is a usable one
#   4. the first usable one
#
# bin/oops picks by the same rule, so builds find the toolchain this installs.
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
        # Affects new installs only; existing distributions keep their version.
        run env MSYS_NO_PATHCONV=1 wsl.exe --set-default-version 2 >/dev/null 2>&1 || true

        # `--no-launch`: a launch waits at a username prompt no script answers, and blocks
        # every later call to the distribution.
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

    # In the distribution this script created only: default to root, so no account is
    # created and the first-run username prompt never appears. The toolchain goes in root's
    # home, where run_via_wsl's `$HOME/.cargo/env` finds it.
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

    # MSYS_NO_PATHCONV stops Git Bash rewriting `/mnt/c/...`. A login shell puts an
    # installed rustup on PATH.
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
