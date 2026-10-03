#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
CANONICAL_APP="$DIR/Nexor.app"
INTERNAL_APP="$DIR/Nexor/Nexor.app"
OLD_APP="$DIR/NetworkUtilities.app"
OLD_INTERNAL_APP="$DIR/archive/Nexor_legacy/Nexor.app"

echo "=== Cleaning Up Duplicate Applications & Launchpad Database ==="

# 1. Unregister internal/stale bundles
if [ -d "$INTERNAL_APP" ]; then
    echo "Unregistering internal build bundle from Launch Services..."
    "$LSREGISTER" -u "$INTERNAL_APP" 2>/dev/null || true
fi
if [ -d "$OLD_INTERNAL_APP" ]; then
    "$LSREGISTER" -u "$OLD_INTERNAL_APP" 2>/dev/null || true
    rm -rf "$OLD_INTERNAL_APP"
fi
if [ -d "$OLD_APP" ]; then
    "$LSREGISTER" -u "$OLD_APP" 2>/dev/null || true
    rm -rf "$OLD_APP"
fi

# 2. Search for any extra NetworkUtilities or Nexor app bundles in this directory tree (excluding canonical)
echo "Searching for extraneous .app bundles..."
find "$DIR" -name "*.app" -type d | while read -r app_path; do
    if [ "$app_path" != "$CANONICAL_APP" ]; then
        echo "Unregistering non-canonical bundle: $app_path"
        "$LSREGISTER" -u "$app_path" 2>/dev/null || true
    fi
done

# 3. Ensure canonical app is properly registered
if [ -d "$CANONICAL_APP" ]; then
    echo "Registering canonical app bundle: $CANONICAL_APP"
    "$LSREGISTER" -f "$CANONICAL_APP" 2>/dev/null || true
fi

# 4. Garbage-collect Launch Services database
echo "Garbage-collecting Launch Services database..."
"$LSREGISTER" -gc 2>/dev/null || true

# 5. Reset Launchpad SQLite cache and restart Dock
echo "Resetting Launchpad database..."
defaults write com.apple.dock ResetLaunchPad -bool true
killall Dock 2>/dev/null || true

echo "✓ Launchpad cleanup complete! Launchpad now indexes only canonical applications."
