#!/bin/zsh
# Prints "version=<next version>" for a release.
# Usage: scripts/next-version.sh "<existing release tags, one per line>"
# The next version keeps project.yml's MARKETING_VERSION major.minor and takes a patch one above
# the highest released patch for that major.minor, but never below project.yml's patch. With no
# release yet, it is project.yml's version (e.g. 0.1.0).
set -euo pipefail
cd "$(dirname "$0")/.."

base=$(sed -nE 's/^ *MARKETING_VERSION: *"?([0-9]+\.[0-9]+\.[0-9]+)"?.*/\1/p' project.yml | head -1)
[[ -n "$base" ]] || { echo "MARKETING_VERSION not found in project.yml" >&2; exit 1; }
prefix=${base%.*}
patch=${base##*.}
for tag in ${(f)1}; do
    [[ $tag == v$prefix.<-> ]] || continue
    released=${tag##*.}
    (( released + 1 > patch )) && patch=$(( released + 1 ))
done
echo "version=$prefix.$patch"
