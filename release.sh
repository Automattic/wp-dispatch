#!/bin/zsh
# Cuts a release: ./release.sh 0.2.0
#
# 1. Sets the version in Info.plist (marketing version + next build number).
# 2. Builds and zips Dispatch.app into site/releases/.
# 3. Regenerates site/appcast.xml, signing each zip with the EdDSA key in the
#    login Keychain (account "dispatch", made by Sparkle's generate_keys).
# 4. Points /download at the new zip and publishes site/ to Spacefast.
#
# Optional release notes: write site/releases/Dispatch-<version>.html before running.
set -e
cd "$(dirname "$0")"
VERSION=$1
[[ -z "$VERSION" ]] && { echo "usage: ./release.sh <version>, e.g. 0.2.0"; exit 1; }
SITE_URL=https://dispatchapp.space.fast
TOOLS=.build/artifacts/sparkle/Sparkle/bin
PLIST=Info.plist

BUILD=$(( $(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" $PLIST) + 1 ))
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" $PLIST
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" $PLIST
echo "Dispatch $VERSION ($BUILD)"

./build.sh
mkdir -p site/releases
ZIP=site/releases/Dispatch-$VERSION.zip
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent build/Dispatch.app "$ZIP"

$TOOLS/generate_appcast --account dispatch \
  --download-url-prefix "$SITE_URL/releases/" \
  --maximum-versions 5 \
  -o site/appcast.xml site/releases

# The website's Download button always gets the newest zip.
print -r -- "/download /releases/Dispatch-$VERSION.zip 302" > site/_redirects

if [[ "$2" != "--no-publish" ]]; then
  (cd site && sf publish --yes)
fi
echo "Released $VERSION. Commit Info.plist, site/appcast.xml and site/_redirects."
