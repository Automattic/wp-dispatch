#!/bin/zsh
# Builds Dispatch.app into ./build and (optionally) installs to ~/Applications.
#   SIGN_IDENTITY="Developer ID Application: …" ./build.sh   signs for distribution (default: ad-hoc)
set -e
cd "$(dirname "$0")"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
IDENTITY=${SIGN_IDENTITY:--}
SIGN=(codesign --force --timestamp=none --sign "$IDENTITY")
[[ "$IDENTITY" != "-" ]] && SIGN=(codesign --force --timestamp --options runtime --sign "$IDENTITY")

# Universal: Apple silicon and Intel.
ARCHS=(--arch arm64 --arch x86_64)
swift build -c release $ARCHS
BIN=$(swift build -c release $ARCHS --show-bin-path)
APP="build/Dispatch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Frameworks"
cp "$BIN/DispatchApp" "$APP/Contents/MacOS/Dispatch"
cp Info.plist "$APP/Contents/"
# ditto keeps the framework's symlinks intact.
ditto "$BIN/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"

# Inside out: Sparkle's helpers, the framework, then the app. No --deep.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for item in "$SPARKLE/XPCServices/Installer.xpc" "$SPARKLE/XPCServices/Downloader.xpc" \
            "$SPARKLE/Autoupdate" "$SPARKLE/Updater.app"; do
  [[ -e "$item" ]] && $SIGN "$item"
done
$SIGN "$APP/Contents/Frameworks/Sparkle.framework"
$SIGN "$APP"

if [[ "$1" == "--install" ]]; then
  mkdir -p ~/Applications
  rm -rf ~/Applications/Dispatch.app
  $LSREGISTER -u "$APP" 2>/dev/null || true
  mv "$APP" ~/Applications/
  $LSREGISTER -f ~/Applications/Dispatch.app
  echo "Installed to ~/Applications/Dispatch.app"
else
  echo "Built $APP"
fi
