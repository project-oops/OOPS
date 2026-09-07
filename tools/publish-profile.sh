#!/usr/bin/env bash
# The organisation's landing page, assembled from this README rather than written twice.
#
#   tools/publish-profile.sh            # publish it
#   tools/publish-profile.sh --check    # fail if what is published has drifted
#
# github.com/<org> renders `profile/README.md` from a repository the organisation must call
# `.github` - the name is GitHub's, not a choice - so the landing page cannot simply live
# here. What it can do is stop being a second copy: the sections between `oops:profile`
# markers in README.md are the source, this assembles them, and `--check` fails when the
# published page and this repository disagree.
#
# The same shape as obSCEne's generated blocks, and for the same reason: a hand-written
# duplicate of a description is stale within a week, and nothing announces it.
#
# The logo travels with it. `assets/logo.svg` in this repository is the source; publishing
# copies it next to the page and rewrites the `src` to match. See ASSETS below for why it is
# copied rather than linked.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

ORG="project-oops"
META="OOPS"                 # this repository, under that organisation
PROFILE_REPO=".github"      # GitHub's fixed name for the profile repository
PROFILE_PATH="profile/README.md"

# Images the page needs, as `<local path>:<path under profile/>`.
#
# **Copied, not linked, and that is not a preference.** An absolute link would have to point
# at `raw.githubusercontent.com/$ORG/$META/...` - and `$META` is empty on GitHub, so the
# image would 404 on a page that renders perfectly here. It would keep 404ing until somebody
# pushed this repository, with nothing to say why. Beside the page, a relative `src` resolves
# inside `.github` and works from the first publish.
#
# This is not a second copy in the sense the marker blocks exist to prevent: the file here is
# the source and this is the publish step, the same relationship the assembled README has to
# the sections it comes from.
ASSETS="assets/logo.svg:profile/logo.svg"

# Published as the collection's identity, never as whoever happens to be logged in. The
# address is GitHub's per-account no-reply form, which is public by construction - it is in
# every commit - so naming it here discloses nothing.
AUTHOR_NAME="legboots"
AUTHOR_EMAIL="201123593+legboots@users.noreply.github.com"

BLOB="https://github.com/$ORG/$META/blob/main"

# Concatenate the marked sections, blank line between, then make every repository-relative
# link absolute - a relative link resolves against `.github` once published, which is a
# different repository and a 404.
render() {
    awk '
        /<!-- oops:profile -->/  { inblock = 1; if (seen++) print ""; next }
        /<!-- \/oops:profile -->/ { inblock = 0; next }
        inblock                   { print }
    ' "$REPO/README.md" |
        sed -E "s#\]\((docs/|tools/|bin/)#](${BLOB}/\1#g" |
        sed -E 's#src="assets/#src="#g'
    printf '\n---\n\n*Assembled from [the OOPS README](%s/README.md). Edit it there.*\n' "$BLOB"
}

published() {
    gh api "repos/$ORG/$PROFILE_REPO/contents/$PROFILE_PATH" --jq '.content' 2>/dev/null |
        tr -d '\n' | base64 -d 2>/dev/null || true
}

# The published blob sha of a path, empty if it is not there. Used both to decide whether a
# PUT is a create or an update, and to tell whether an asset needs re-uploading at all.
#
# **The shape is checked rather than trusted.** `gh api` writes the API's error document to
# STDOUT on a 404, so a file that is not published yet comes back as
# `{"message":"Not Found",...}` - a non-empty string, which the caller then interpolated
# straight into the request body. The result was a 400 reading `Problems parsing JSON`,
# naming neither the file nor the cause. A blob sha is forty hex characters and nothing else.
remote_sha() {
    local out
    out="$(gh api "repos/$ORG/$PROFILE_REPO/contents/$1" --jq '.sha' 2>/dev/null)" || return 0
    printf '%s' "$out" | grep -qE '^[0-9a-f]{40}$' && printf '%s' "$out"
    return 0
}

# git's blob sha of a local file, so an asset can be compared without downloading it.
local_sha() {
    git hash-object "$1"
}

# Upload one file, creating or updating as needed. Binary-safe: the content is base64 of the
# bytes, never of a shell variable, because a `$(...)` strips trailing newlines and would
# corrupt anything that is not text.
put_file() {
    local local_path="$1" repo_path="$2" message="$3"
    local sha sha_field=""
    sha="$(remote_sha "$repo_path")"
    [ -n "$sha" ] && sha_field="\"sha\": \"$sha\","
    gh api -X PUT "repos/$ORG/$PROFILE_REPO/contents/$repo_path" --input - >/dev/null <<JSON
{
  "message": "$message",
  "content": "$(base64 -w0 < "$local_path")",
  $sha_field
  "committer": { "name": "$AUTHOR_NAME", "email": "$AUTHOR_EMAIL" },
  "author":    { "name": "$AUTHOR_NAME", "email": "$AUTHOR_EMAIL" }
}
JSON
}

# Every asset is present and current. Reported rather than silently re-uploaded on --check,
# because a page whose image 404s looks like a GitHub problem rather than a publish that did
# not finish.
assets_drifted() {
    local pair local_path repo_path drifted=""
    for pair in $ASSETS; do
        local_path="$REPO/${pair%%:*}"
        repo_path="${pair##*:}"
        if [ ! -f "$local_path" ]; then
            echo "missing locally: ${pair%%:*}" >&2
            drifted="yes"
        elif [ "$(remote_sha "$repo_path")" != "$(local_sha "$local_path")" ]; then
            echo "out of date: $repo_path" >&2
            drifted="yes"
        fi
    done
    [ -n "$drifted" ]
}

case "${1:-publish}" in
    --check | check)
        status=0
        # The assets first, and reported separately: a page that matches byte for byte while
        # its logo is missing is still a broken page, and the diff would say nothing at all.
        if assets_drifted; then
            echo "org profile: assets DRIFTED" >&2
            status=1
        fi
        if ! diff -u <(published) <(render) >/dev/null 2>&1; then
            echo "org profile: DRIFTED - github.com/$ORG does not match README.md" >&2
            diff -u <(published) <(render) | head -40 >&2
            status=1
        fi
        if [ "$status" -eq 0 ]; then
            echo "org profile: in sync"
            exit 0
        fi
        echo >&2
        echo "fix: tools/publish-profile.sh" >&2
        exit 1
        ;;
    -h | --help | help)
        # The range is found rather than hardcoded. It was `2,12p`, and the header grew past
        # it - so `--help` silently stopped printing its last paragraph, which is the failure
        # mode a hardcoded line number always has.
        sed -n "2,$(($(grep -n '^set -euo' "$0" | head -1 | cut -d: -f1) - 1))p" "$0" |
            sed 's|^# \{0,1\}||'
        exit 0
        ;;
    publish) ;;
    *)
        echo "unknown argument: $1" >&2
        exit 2
        ;;
esac

body="$(render)"
if [ -z "$body" ]; then
    echo "nothing between the oops:profile markers in README.md - refusing to publish an empty page" >&2
    exit 1
fi

# Assets before the page. If the page went first and an asset upload then failed, the
# published page would reference an image that is not there - so the ordering is the one
# where a half-finished publish leaves the old page intact.
for pair in $ASSETS; do
    asset_local="$REPO/${pair%%:*}"
    asset_repo="${pair##*:}"
    [ -f "$asset_local" ] || {
        echo "missing: ${pair%%:*} - the page references it, so refusing to publish" >&2
        exit 1
    }
    if [ "$(remote_sha "$asset_repo")" = "$(local_sha "$asset_local")" ]; then
        echo "unchanged: $asset_repo"
    else
        put_file "$asset_local" "$asset_repo" "Publish $asset_repo for the organisation profile"
        echo "uploaded:  $asset_repo"
    fi
done

page="$(mktemp)"
trap 'rm -f "$page"' EXIT
printf '%s\n' "$body" > "$page"
put_file "$page" "$PROFILE_PATH" "Assemble the organisation profile from the OOPS README"

echo "published: https://github.com/$ORG"
