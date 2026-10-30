#!/bin/zsh
# Cuts a release: ./release.sh 0.2.0 [--no-publish]
#
# 0. Checks that the website demo still matches the app (tools/drift/check.sh). Stops if not.
# 1. Checks the Sparkle signing key and fetches the previous release zip if it's missing.
# 2. Sets the version in Info.plist (marketing version + next build number).
# 3. Builds and zips Dispatch.app into site/releases/.
# 4. Regenerates site/appcast.xml, signing each zip with the EdDSA key in the
#    login Keychain (account "dispatch", made by Sparkle's generate_keys).
# 5. Points /download at the new zip and publishes site/ to the Dispatch Space.
#
# Release notes are required: run tools/release/changes.sh to review what's changed since the
# last release, then write site/releases/Dispatch-<version>.html. Sparkle shows them in the update
# window, and they go on the public release log at /releases/.
# Full runbook: docs/releasing.md
set -e
cd "$(dirname "$0")"
VERSION=$1
[[ -z "$VERSION" ]] && { echo "usage: ./release.sh <version> [--no-publish], e.g. 0.2.0"; exit 1; }
SITE_URL=https://dispatchapp.space.fast
SPACE_ID=spc_6f81e0c2ca994ef597cc94eb55f421d5 # the "dispatchapp" Space, as in site/.spacefast/space.json
TOOLS=.build/artifacts/sparkle/Sparkle/bin
PLIST=Info.plist

# Every release gets notes. Without them, show what's changed and stop.
NOTES=site/releases/Dispatch-$VERSION.html
if [[ ! -f $NOTES ]]; then
  ./tools/release/changes.sh
  echo "\nNo release notes yet. Review the changes above, write $NOTES"
  echo "(like the others: <h2>Dispatch $VERSION</h2><ul><li><strong>What's better.</strong> Why it matters.</li></ul>), then release again."
  exit 1
fi

# The website shows a working copy of the app. Don't ship if the two have drifted apart.
if ! ./tools/drift/check.sh; then
  echo "\nThe website demo no longer matches the app. Fix site/sim.js or site/sim.css (see build/drift/report.html), then release again."
  exit 1
fi

# Sparkle's tools come with the SwiftPM package.
[[ -x $TOOLS/generate_appcast ]] || swift package resolve

# Without the private key, existing installs would reject the update. Stop early.
EXPECTED_KEY=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" $PLIST)
KEYCHAIN_KEY=$($TOOLS/generate_keys --account dispatch -p 2>/dev/null || true)
if [[ "$KEYCHAIN_KEY" != "$EXPECTED_KEY" ]]; then
  echo "The Sparkle signing key isn't in this Mac's Keychain (account \"dispatch\")."
  echo "Import it first: $TOOLS/generate_keys --account dispatch -f <private-key-file>"
  exit 1
fi

# The appcast is rebuilt from the zips in site/releases, and publishing replaces the whole
# Space, so the current release has to be here too. Fresh clones don't have it.
CURRENT=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" $PLIST)
mkdir -p site/releases
if [[ ! -f site/releases/Dispatch-$CURRENT.zip ]]; then
  echo "Fetching Dispatch-$CURRENT.zip from the site"
  curl -fsSL -o site/releases/Dispatch-$CURRENT.zip "$SITE_URL/releases/Dispatch-$CURRENT.zip"
fi

BUILD=$(( $(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" $PLIST) + 1 ))
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" $PLIST
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" $PLIST
echo "Dispatch $VERSION ($BUILD)"

./build.sh
ZIP=site/releases/Dispatch-$VERSION.zip
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent build/Dispatch.app "$ZIP"

$TOOLS/generate_appcast --account dispatch \
  --download-url-prefix "$SITE_URL/releases/" \
  --maximum-versions 5 \
  -o site/appcast.xml site/releases

# Fresh copies of the demo for this release: its ⋯ menu shows the version, and the
# cache-busting query is each file's content hash.
sed -i '' -E "s#(const VERSION = )\"[^\"]*\"#\1\"$VERSION\"#" site/sim.js
./bust-site.sh

# The public release log, from every release's notes.
node tools/release/log.mjs

# The website's Download button always gets the newest zip.
print -r -- "/download /releases/Dispatch-$VERSION.zip 302" > site/_redirects

if [[ "$2" != "--no-publish" ]]; then
  (cd site && sf publish --space $SPACE_ID --yes --wait -m "Dispatch $VERSION")
fi
echo "Released $VERSION. Commit Info.plist, site/appcast.xml, site/_redirects, site/index.html, site/sim.js, site/releases/*.html and the notes."
