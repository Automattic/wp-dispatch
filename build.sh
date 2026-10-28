#!/bin/zsh
# Builds Dispatch.app into ./build and (optionally) installs to ~/Applications.
set -e
cd "$(dirname "$0")"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
swift build -c release
APP="build/Dispatch.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/DispatchApp "$APP/Contents/MacOS/Dispatch"
cp Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"
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
