#!/bin/zsh
# Checks that the website's demo (site/sim.js) still matches the app.
# Renders the real app's views offscreen from site/demo-data.json (demo mode: no network, no menu
# bar, no windows on screen, nothing written to the real app's data), renders the same scenes of
# the website demo in headless Chromium, and compares where every tagged part landed.
# Writes build/drift/report.html. Exits 1 when anything differs.
set -e
cd "${0:A:h}/../.."
OUT=build/drift
SCENES=(notifications note-open comments-open comments-full reply-open reader reader-post xposts later)
rm -rf $OUT && mkdir -p $OUT

swift build -q 2>/dev/null || swift build
BIN=$(swift build --show-bin-path)
DYLD_FRAMEWORK_PATH=$BIN DISPATCH_DEMO=$PWD/site/demo-data.json DISPATCH_RENDER=$PWD/$OUT/app "$BIN/DispatchApp"

node tools/drift/measure.mjs "$PWD" $OUT/site $SCENES
node tools/drift/compare.mjs $OUT $SCENES
