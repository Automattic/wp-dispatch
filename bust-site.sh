#!/bin/zsh
# Points index.html at the current sim.css and sim.js: each one's query is its content hash,
# so browsers fetch a fresh copy exactly when the file changed. Run it after editing either file.
set -e
cd "${0:A:h}/site"
for f in sim.css sim.js; do
  sed -i '' -E "s#${f//./\\.}\\?v=[0-9a-f]+#$f?v=$(shasum "$f" | cut -c1-10)#" index.html
done
