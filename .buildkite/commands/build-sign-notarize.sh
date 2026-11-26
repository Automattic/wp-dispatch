#!/usr/bin/env bash

set -euo pipefail

echo "--- :rubygems: Install gems"
install_gems

echo "--- :closed_lock_with_key: Fetch the Developer ID certificate"
bundle exec fastlane configure_code_signing

rm -rf dist
mkdir -p dist

echo "--- :hammer_and_wrench: Build and sign"
readonly AUTOMATTIC_DEVELOPER_ID='Developer ID Application: Automattic, Inc. (PZYM8XX95Q)'
SIGN_IDENTITY="$AUTOMATTIC_DEVELOPER_ID" ./build.sh

echo "--- :apple: Notarize and staple"
bundle exec fastlane notarize_app app:"build/Dispatch.app"

echo "--- :package: Archive"
ditto -c -k --sequesterRsrc --keepParent "build/Dispatch.app" "dist/Dispatch.zip"

buildkite-agent annotate --context "notarized-app-dl-link" --style "success" --scope job \
  "Notarized binary available for download [here](artifact://dist/Dispatch.zip)"
