#!/usr/bin/env bash
# Deploy the Bazi PWA to GitHub Pages.
#
# Always rebuilds with the correct --base-href so a stray `flutter run`
# (which regenerates build/web with base href "/") can never ship a broken
# index.html to production.
set -euo pipefail

# Disable Git-Bash/MSYS path conversion, which otherwise rewrites the
# "/bazi-app/" argument into a Windows path like "C:/Program Files/Git/...".
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

REPO="https://github.com/kth2/bazi-app.git"
BASE_HREF="/bazi-app/"

cd "$(dirname "$0")"

# The running app polls build.json to notice it is out of date, comparing it
# against the id compiled in here. A manual deploy must stamp both, or an app
# left open will keep prompting (or never prompt) against a stale id.
BUILD_ID="$(git rev-parse HEAD 2>/dev/null || date -u +manual-%Y%m%d%H%M%S)"

echo "==> Building web release with base-href $BASE_HREF (build $BUILD_ID)"
flutter build web --release --base-href "$BASE_HREF" \
  --dart-define=APP_BUILD_ID="$BUILD_ID"

# Sanity check: refuse to deploy a wrong base href.
if ! grep -q "<base href=\"$BASE_HREF\">" build/web/index.html; then
  echo "ERROR: build/web/index.html base href is not $BASE_HREF — aborting." >&2
  exit 1
fi
echo "==> base href OK"

printf '{"buildId":"%s","builtAt":"%s","ref":"manual"}\n' \
  "$BUILD_ID" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > build/web/build.json
echo "==> stamped build.json ($BUILD_ID)"

cd build/web
touch .nojekyll
rm -rf .git
git init -b gh-pages -q
git add -A
git commit -q -m "deploy $(date -u +%Y-%m-%dT%H:%M:%SZ)"
git push -f "$REPO" gh-pages
rm -rf .git
echo "==> Deployed. Live at https://kth2.github.io/bazi-app/"
