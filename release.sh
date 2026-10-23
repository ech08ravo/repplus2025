#!/bin/bash
# The one way to release WebGrid.Online.
#
#     ./release.sh              # test, then deploy to both sites
#     ./release.sh --dry-run    # run every check, deploy nothing
#
# Both public sites are updated from the same commit, so a bad release is live
# in two places at once. The tests run first and a failure stops the release
# here, rather than depending on whoever is deploying remembering to run them.
set -uo pipefail
cd "$(dirname "$0")"

DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

SERVER_HOST="ubuntu@208.113.135.63"
SERVER_REPO="/home/ubuntu/repplus2025"

step() { echo; echo "=== $* ==="; }
die()  { echo; echo "RELEASE STOPPED: $*" >&2; exit 1; }

APP_VERSION="$(grep -m1 '^APP_VERSION <-' app.R | sed -E 's/.*"([^"]+)".*/\1/')"
[ -n "$APP_VERSION" ] || die "could not read APP_VERSION from app.R"

step "Releasing v$APP_VERSION"

# --- 1. the version has to be real and described -------------------------
step "Checking the version"
CHANGELOG_VERSION="$(grep -m1 -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | tr -d '#[] ')"
if [ "$APP_VERSION" != "$CHANGELOG_VERSION" ]; then
  die "app.R says $APP_VERSION but the newest CHANGELOG entry is $CHANGELOG_VERSION.
             Run ./bump_version.sh <version> and describe the release."
fi
if grep -A4 "^## \[$APP_VERSION\]" CHANGELOG.md | grep -q "TODO: describe this release"; then
  die "the CHANGELOG entry for $APP_VERSION is still the placeholder."
fi
echo "app.R and CHANGELOG.md agree on $APP_VERSION"

if git rev-parse "v$APP_VERSION" >/dev/null 2>&1; then
  die "v$APP_VERSION has already been released (git tag exists). Bump first."
fi

# --- 2. the working tree has to match what will be deployed ---------------
step "Checking the working tree"
[ -z "$(git status --porcelain)" ] || die "uncommitted changes - commit them first:
$(git status --short)"
git fetch -q origin
LOCAL="$(git rev-parse @)"; REMOTE="$(git rev-parse @{u} 2>/dev/null || echo none)"
[ "$LOCAL" = "$REMOTE" ] || die "local and origin/master differ - push first.
             The server deploys by pulling from GitHub, so an unpushed commit
             would deploy the previous code while claiming this version."
echo "clean, and level with origin/master at ${LOCAL:0:7}"

# --- 3. the tests ---------------------------------------------------------
step "Running the tests"
./tests/run_all.sh || die "tests failed - nothing deployed."

if [ "$DRY" -eq 1 ]; then
  step "Dry run: every check passed, nothing deployed"
  exit 0
fi

# --- 4. deploy ------------------------------------------------------------
step "Deploying to webgrid.online"
ssh -o ConnectTimeout=20 "$SERVER_HOST" \
  "cd $SERVER_REPO && git pull --ff-only && ./deploy.sh" \
  || die "the webgrid.online deploy failed. shinyapps.io has NOT been touched."

step "Deploying to shinyapps.io"
Rscript deploy_shinyapps.R \
  || die "webgrid.online is on v$APP_VERSION but shinyapps.io failed - the two
             sites are now on different versions. Re-run: Rscript deploy_shinyapps.R"

# --- 5. confirm both are actually serving it ------------------------------
step "Verifying both sites"
fail=0
for pair in "webgrid.online|https://webgrid.online/" \
            "shinyapps.io|https://ech08ravo.shinyapps.io/repplus2025/"; do
  name="${pair%%|*}"; url="${pair##*|}"; got=""
  for _ in $(seq 1 12); do
    got="$(curl -sL --max-time 45 "$url" | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)"
    [ -n "$got" ] && break
    sleep 5    # shinyapps.io answers 202 while an instance wakes
  done
  if [ "$got" = "v$APP_VERSION" ]; then
    echo "  $name: $got"
  else
    echo "  $name: expected v$APP_VERSION, got ${got:-no version}"; fail=1
  fi
done
[ "$fail" -eq 0 ] || die "a site is not serving v$APP_VERSION."

git tag -a "v$APP_VERSION" -m "Release v$APP_VERSION" && git push -q origin "v$APP_VERSION"

step "Released v$APP_VERSION - both sites verified, tagged v$APP_VERSION"
