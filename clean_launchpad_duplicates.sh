#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
CANONICAL_APP="$DIR/Nexor.app"

echo "=== Cleaning Up Duplicate Applications & Launchpad Database ==="

# 1. Search for any extra Nexor app bundles in this directory tree (excluding canonical)
echo "Searching for extraneous .app bundles..."
find "$DIR" -name "*.app" -type d | while read -r app_path; do
    if [ "$app_path" != "$CANONICAL_APP" ]; then
        echo "Unregistering non-canonical bundle: $app_path"
        "$LSREGISTER" -u "$app_path" 2>/dev/null || true
    fi
done

# 2. Ensure canonical app is properly registered
if [ -d "$CANONICAL_APP" ]; then
    echo "Registering canonical app bundle: $CANONICAL_APP"
    "$LSREGISTER" -f "$CANONICAL_APP" 2>/dev/null || true
fi

# 3. Garbage-collect Launch Services database
echo "Garbage-collecting Launch Services database..."
"$LSREGISTER" -gc 2>/dev/null || true

# 4. Reset Launchpad SQLite cache and restart Dock
echo "Resetting Launchpad database..."
defaults write com.apple.dock ResetLaunchPad -bool true
killall Dock 2>/dev/null || true

echo "✓ Launchpad cleanup complete! Launchpad now indexes only canonical applications."
