#!/bin/zsh
# Builds WP Notifications.app into ./build and (optionally) installs to ~/Applications.
set -e
cd "$(dirname "$0")"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
swift build -c release
APP="build/WP Notifications.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/WPNotifications "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"
if [[ "$1" == "--install" ]]; then
  mkdir -p ~/Applications
  rm -rf ~/Applications/"WP Notifications.app"
  $LSREGISTER -u "$APP" 2>/dev/null || true
  mv "$APP" ~/Applications/
  $LSREGISTER -f ~/Applications/"WP Notifications.app"
  echo "Installed to ~/Applications/WP Notifications.app"
else
  echo "Built $APP"
fi
