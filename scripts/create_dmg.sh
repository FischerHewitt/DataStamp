#!/bin/bash
# create_dmg.sh
# Creates a polished DMG installer for DataStamp with a drag-to-install layout.
#
# Usage:
#   ./scripts/create_dmg.sh /path/to/exported/DataStamp.app
#
# Output:
#   DataStamp-1.0.dmg in the current directory

set -e

APP_PATH="$1"
APP_NAME="DataStamp"
VERSION="1.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
STAGING_DIR="/tmp/${APP_NAME}_dmg_staging"
TEMP_DMG="/tmp/${APP_NAME}_temp.dmg"

# ── Validate input ────────────────────────────────────────────────────────────
if [ -z "$APP_PATH" ]; then
    echo "Usage: $0 /path/to/DataStamp.app"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

echo "→ Building DMG for $APP_PATH"

# ── Clean up any previous staging ────────────────────────────────────────────
rm -rf "$STAGING_DIR"
rm -f "$TEMP_DMG"
rm -f "$DMG_NAME"

# ── Create staging folder ─────────────────────────────────────────────────────
mkdir -p "$STAGING_DIR"

# Copy the app in
cp -r "$APP_PATH" "$STAGING_DIR/${APP_NAME}.app"

# Create an alias to /Applications so users can drag-install
ln -s /Applications "$STAGING_DIR/Applications"

# ── Create a temporary writable DMG ──────────────────────────────────────────
echo "→ Creating temporary DMG..."
hdiutil create \
    -srcfolder "$STAGING_DIR" \
    -volname "$APP_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,b=16" \
    -format UDRW \
    -size 150m \
    "$TEMP_DMG"

# ── Mount it ──────────────────────────────────────────────────────────────────
echo "→ Mounting DMG..."
MOUNT_DIR="/Volumes/${APP_NAME}"

# Unmount if already mounted
hdiutil detach "$MOUNT_DIR" 2>/dev/null || true

DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "$TEMP_DMG" \
    | egrep '^/dev/' | sed 1q | awk '{print $1}')

sleep 2

# ── Set window layout with AppleScript ───────────────────────────────────────
echo "→ Setting window layout..."
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 920, 420}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        set background color of viewOptions to {55000, 55000, 65535}
        set position of item "${APP_NAME}.app" of container window to {150, 160}
        set position of item "Applications" of container window to {370, 160}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
APPLESCRIPT

# ── Finalise ──────────────────────────────────────────────────────────────────
echo "→ Finalising..."
chmod -Rf go-w "$MOUNT_DIR"
sync
sync

hdiutil detach "$DEVICE"

# Convert to compressed read-only DMG
echo "→ Compressing..."
hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_NAME"

# Clean up
rm -f "$TEMP_DMG"
rm -rf "$STAGING_DIR"

echo ""
echo "✓ Done: $(pwd)/${DMG_NAME}"
echo "  Size: $(du -sh "$DMG_NAME" | cut -f1)"
