#!/usr/bin/env bash
# Deploy the Bazi PWA to GitHub Pages.
#
# Always rebuilds with the correct --base-href so a stray `flutter run`
# (which regenerates build/web with base href "/") can never ship a broken
# index.html to production.
set -euo pipefail

REPO="https://github.com/kth2/bazi-app.git"
BASE_HREF="/bazi-app/"

cd "$(dirname "$0")"

echo "==> Building web release with base-href $BASE_HREF"
flutter build web --release --base-href "$BASE_HREF"

# Sanity check: refuse to deploy a wrong base href.
if ! grep -q "<base href=\"$BASE_HREF\">" build/web/index.html; then
  echo "ERROR: build/web/index.html base href is not $BASE_HREF — aborting." >&2
  exit 1
fi
echo "==> base href OK"

cd build/web
touch .nojekyll
rm -rf .git
git init -b gh-pages -q
git add -A
git commit -q -m "deploy $(date -u +%Y-%m-%dT%H:%M:%SZ)"
git push -f "$REPO" gh-pages
rm -rf .git
echo "==> Deployed. Live at https://kth2.github.io/bazi-app/"
