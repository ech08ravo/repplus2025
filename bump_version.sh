#!/bin/bash
# Bump the app version in one place and open a changelog entry for it.
#
#     ./bump_version.sh 2.12.0
#
# APP_VERSION is what the title bar shows and what deploy.sh checks the live
# site against, so a release that forgets it serves a version string that lies.
# It sat at 2.6.0 across eleven commits once, which made "check the version in
# the title bar" useless as a deploy check.
set -euo pipefail
cd "$(dirname "$0")"

new="${1:-}"
if [[ ! "$new" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: ./bump_version.sh <major.minor.patch>    e.g. ./bump_version.sh 2.12.0" >&2
  exit 1
fi

old="$(grep -m1 '^APP_VERSION <-' app.R | sed -E 's/.*"([^"]+)".*/\1/')"
if [ "$old" = "$new" ]; then
  echo "app.R is already at $new" >&2
  exit 1
fi

# Highest first, so a lower number is rejected rather than silently going back.
if [ "$(printf '%s\n%s\n' "$old" "$new" | sort -V | tail -1)" != "$new" ]; then
  echo "ERROR: $new is lower than the current $old" >&2
  exit 1
fi

sed -i '' -E "s/^APP_VERSION <- \"$old\"/APP_VERSION <- \"$new\"/" app.R
echo "app.R:  $old -> $new"

if ! grep -q "^## \[$new\]" CHANGELOG.md; then
  tmp="$(mktemp)"
  {
    head -4 CHANGELOG.md
    printf '## [%s] - %s\n\n### Changed\n- TODO: describe this release\n\n' \
           "$new" "$(date +%Y-%m-%d)"
    tail -n +5 CHANGELOG.md
  } > "$tmp"
  mv "$tmp" CHANGELOG.md
  echo "CHANGELOG.md: added a [$new] section - fill it in before releasing"
fi

echo
echo "Next:  edit the CHANGELOG entry, commit, then ./release.sh"
