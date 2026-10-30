#!/bin/zsh
# Rebuilds Resources/AppIcon.icns (and the website's icons) from draw.swift.
set -e
cd "${0:A:h}/../.."
SET=$(mktemp -d)/AppIcon.iconset
mkdir -p $SET Resources
for s in 16 32 128 256 512; do
  swift tools/icon/draw.swift $SET/icon_${s}x${s}.png $s
  swift tools/icon/draw.swift $SET/icon_${s}x${s}@2x.png $((s * 2))
done
iconutil -c icns $SET -o Resources/AppIcon.icns
swift tools/icon/draw.swift site/icon.png 512
swift tools/icon/draw.swift site/favicon.png 64
echo "Made Resources/AppIcon.icns, site/icon.png and site/favicon.png"
