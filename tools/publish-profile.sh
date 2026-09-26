#!/usr/bin/env bash
# Publish the organisation's landing page, assembled from README.md.
#
#   tools/publish-profile.sh            # publish it
#   tools/publish-profile.sh --check    # fail if what is published has drifted
#
# GitHub renders github.com/<org> from `profile/README.md` in the org's `.github`
# repository. The page is the sections between `oops:profile` markers in README.md, with
# relative links made absolute; `assets/logo.svg` is uploaded beside it.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/.." && pwd)"

ORG="project-oops"
META="OOPS"                 # this repository, under that organisation
PROFILE_REPO=".github"      # GitHub's fixed name for the profile repository
PROFILE_PATH="profile/README.md"

# Images the page needs, as `<local path>:<path under profile/>`. Uploaded beside the page
# so a relative `src` resolves inside `.github`.
ASSETS="assets/logo.svg:profile/logo.svg"

# Published as the collection's identity, with its public GitHub no-reply address.
AUTHOR_NAME="legboots"
AUTHOR_EMAIL="201123593+legboots@users.noreply.github.com"

BLOB="https://github.com/$ORG/$META/blob/main"

# The marked sections, blank line between, with repository-relative links made absolute.
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

# The published blob sha of a path, empty if it is not there. Validated as 40 hex digits,
# since `gh api` prints the error document to stdout on a 404.
remote_sha() {
    local out
    out="$(gh api "repos/$ORG/$PROFILE_REPO/contents/$1" --jq '.sha' 2>/dev/null)" || return 0
    grep -qE '^[0-9a-f]{40}$' <<< "$out" && printf '%s' "$out"
    return 0
}

# git's blob sha of a local file, so an asset can be compared without downloading it.
local_sha() {
    git hash-object "$1"
}

# Upload one file, creating or updating it. The content is base64 of the file itself, so
# binary files survive.
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

# True, with each file named, when an asset is missing locally or differs from the published one.
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
        # The header, up to the `set -euo` line.
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

# Assets before the page, so a failed upload leaves the old page intact.
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
