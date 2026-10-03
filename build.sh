#!/bin/bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Nexor"
APP_BUNDLE="$DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "=== Building $APP_NAME (macOS 14.0+, Swift 6) ==="

# 1. Prepare App Bundle Layout
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 2. Copy Info.plist
if [ -f "$DIR/Resources/Info.plist" ]; then
    cp "$DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
    echo "✓ Installed Info.plist"
else
    echo "Error: Resources/Info.plist not found" >&2
    exit 1
fi

# 3. Copy LaunchDaemons plist if present
if [ -d "$DIR/Resources/LaunchDaemons" ]; then
    mkdir -p "$CONTENTS_DIR/Library/LaunchDaemons"
    cp -R "$DIR/Resources/LaunchDaemons/"* "$CONTENTS_DIR/Library/LaunchDaemons/" 2>/dev/null || true
    echo "✓ Installed LaunchDaemons configuration"
fi

# 3b. Verify or build AppIcon.icns
if [ ! -f "$DIR/Resources/Icons/AppIcon.icns" ]; then
    if [ -d "$DIR/Resources/Icons/NU.icon" ]; then
        echo "Compiling AppIcon from Resources/Icons/NU.icon via actool..."
        TMP_ACTOOL=$(mktemp -d)
        xcrun actool "$DIR/Resources/Icons/NU.icon" --compile "$TMP_ACTOOL" --platform macosx --minimum-deployment-target 14.0 --app-icon NU --standalone-icon-behavior all --output-partial-info-plist "$TMP_ACTOOL/partial.plist" 2>/dev/null || true
        if [ -f "$TMP_ACTOOL/NU.icns" ]; then
            cp "$TMP_ACTOOL/NU.icns" "$DIR/Resources/Icons/AppIcon.icns"
            cp "$TMP_ACTOOL/Assets.car" "$DIR/Resources/Icons/Assets.car" 2>/dev/null || true
        fi
        rm -rf "$TMP_ACTOOL"
    elif [ -f "$DIR/Scripts/generate_icon.py" ]; then
        echo "AppIcon.icns not found, generating via generate_icon.py..."
        python3 "$DIR/Scripts/generate_icon.py"
    fi
fi

if [ -f "$DIR/Resources/Icons/AppIcon.icns" ]; then
    cp "$DIR/Resources/Icons/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
    echo "✓ Installed AppIcon.icns into Contents/Resources/"
fi

if [ -f "$DIR/Resources/Icons/Assets.car" ]; then
    cp "$DIR/Resources/Icons/Assets.car" "$RESOURCES_DIR/Assets.car"
    echo "✓ Installed Assets.car into Contents/Resources/"
fi

# 4. Find Swift source files
SWIFT_FILES=$(find "$DIR/Sources/Nexor" -name "*.swift")

if [ -z "$SWIFT_FILES" ]; then
    echo "Error: No Swift files found in Sources/Nexor" >&2
    exit 1
fi

# 5. Determine target architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    TARGET_FLAG="-target arm64-apple-macos14.0"
else
    TARGET_FLAG="-target x86_64-apple-macos14.0"
fi

echo "Compiling $APP_NAME for $ARCH (macOS 14.0+)..."
swiftc -g -O $TARGET_FLAG \
    $SWIFT_FILES \
    -o "$MACOS_DIR/$APP_NAME" \
    -framework SwiftUI \
    -framework AppKit \
    -framework CoreWLAN \
    -framework SystemConfiguration \
    -framework Network \
    -framework ServiceManagement \
    -framework CoreBluetooth \
    -framework IOBluetooth

echo "✓ Main application binary compiled: $MACOS_DIR/$APP_NAME"

# 6. Conditionally compile HelperDaemon if present
if [ -d "$DIR/Sources/HelperDaemon" ]; then
    HELPER_FILES=$(find "$DIR/Sources/HelperDaemon" -name "*.swift")
    if [ -n "$HELPER_FILES" ]; then
        echo "Compiling HelperDaemon..."
        swiftc -g -O $TARGET_FLAG \
            $HELPER_FILES \
            -o "$MACOS_DIR/HelperDaemon" \
            -framework Foundation \
            -framework ServiceManagement \
            -framework Network
        echo "✓ HelperDaemon binary compiled: $MACOS_DIR/HelperDaemon"
    fi
fi

echo "=== Code Signing $APP_BUNDLE (Ad-hoc) ==="
rm -rf "$MACOS_DIR"/*.dSYM 2>/dev/null || true
rm -rf "$CONTENTS_DIR/_CodeSignature" 2>/dev/null || true
dot_clean -m "$APP_BUNDLE" 2>/dev/null || true
xattr -cr "$APP_BUNDLE" 2>/dev/null || true
xattr -c "$APP_BUNDLE" 2>/dev/null || true
xattr -rd com.apple.FinderInfo "$APP_BUNDLE" 2>/dev/null || true
xattr -rd com.apple.ResourceFork "$APP_BUNDLE" 2>/dev/null || true
codesign --force --deep --sign - "$APP_BUNDLE"
echo "✓ App bundle signed"

echo "=== Build Complete: $APP_BUNDLE ==="

# Deploy to workspace root Nexor.app
WORKSPACE_APP="$(dirname "$DIR")/Nexor.app"
OLD_WORKSPACE_APP="$(dirname "$DIR")/NetworkUtilities.app"
echo "Deploying to $WORKSPACE_APP..."
rm -rf "$WORKSPACE_APP"
rm -rf "$OLD_WORKSPACE_APP"
cp -R "$APP_BUNDLE" "$WORKSPACE_APP"
rm -rf "$WORKSPACE_APP/Contents/_CodeSignature" 2>/dev/null || true
dot_clean -m "$WORKSPACE_APP" 2>/dev/null || true
xattr -cr "$WORKSPACE_APP" 2>/dev/null || true
xattr -c "$WORKSPACE_APP" 2>/dev/null || true
xattr -rd com.apple.FinderInfo "$WORKSPACE_APP" 2>/dev/null || true
xattr -rd com.apple.ResourceFork "$WORKSPACE_APP" 2>/dev/null || true
codesign --force --deep --sign - "$WORKSPACE_APP"
echo "✓ Deployed and verified up-to-date bundle to $WORKSPACE_APP"

# Unregister internal development bundle and legacy bundles, ensure only canonical Nexor is registered
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP_BUNDLE" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$OLD_WORKSPACE_APP" 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$WORKSPACE_APP" 2>/dev/null || true

if [ "$1" = "--open" ]; then
    echo "Launching $WORKSPACE_APP..."
    open "$WORKSPACE_APP"
fi
