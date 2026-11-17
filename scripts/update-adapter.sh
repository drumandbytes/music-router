#!/bin/bash
# Replaces third_party/mediaremote-adapter with upstream tag $1 (e.g. v0.7.8):
# source, include, perl script and LICENSE (not the test client), then rewrites
# VERSION and the version mentioned in the README. No git or network beyond the
# clone; the caller (the adapter-update workflow, or you) commits.
# Usage: scripts/update-adapter.sh <tag>
set -euo pipefail

cd "$(dirname "$0")/.."

TAG="${1:?usage: update-adapter.sh <tag>}"
case "$TAG" in v[0-9]*) ;; *) echo "update-adapter: '$TAG' doesn't look like a release tag" >&2; exit 2 ;; esac

DEST="third_party/mediaremote-adapter"
OLD=$(sed -n 's/^tag: //p' "$DEST/VERSION")
[ -n "$OLD" ] || { echo "update-adapter: no 'tag:' line in $DEST/VERSION" >&2; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$TAG" https://github.com/ungive/mediaremote-adapter.git "$WORK/upstream"
COMMIT=$(git -C "$WORK/upstream" rev-parse HEAD)

for path in src include bin LICENSE; do
  [ -e "$WORK/upstream/$path" ] || { echo "update-adapter: upstream $TAG has no $path; layout changed, update by hand" >&2; exit 1; }
done

rm -rf "${DEST:?}/src" "${DEST:?}/include" "${DEST:?}/bin" "${DEST:?}/LICENSE"
cp -R "$WORK/upstream/src" "$WORK/upstream/include" "$WORK/upstream/bin" "$WORK/upstream/LICENSE" "$DEST/"
rm -rf "$DEST/src/test"

cat > "$DEST/VERSION" <<VERSION
upstream: https://github.com/ungive/mediaremote-adapter
tag: $TAG
commit: $COMMIT
license: BSD-3-Clause (see LICENSE)
local changes: none; src/test (test client) omitted
VERSION

# the README names the pinned version in two places
sed -i.bak "s/$OLD/$TAG/g" README.md && rm -f README.md.bak

echo "updated $OLD -> $TAG ($COMMIT)"
