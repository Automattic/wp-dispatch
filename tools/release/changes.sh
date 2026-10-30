#!/bin/zsh
# What's changed since the last release, to review before writing release notes.
# Lists every commit since the last "Release x.y.z" commit, then the files they touched.
set -e
cd "${0:A:h}/../.."
LAST=$(git log -E --grep='^Release [0-9]+\.[0-9]+\.[0-9]+' -1 --format=%H)
echo "Since $(git log -1 --format='%s (%ad)' --date=short $LAST):\n"
git log --reverse --format='• %s%n%w(0,2,2)%b' $LAST..HEAD | grep -v -E '^\s*(Co-Authored-By:.*)?$' || true
echo "\nFiles:"
git diff --stat $LAST..HEAD | tail -25
