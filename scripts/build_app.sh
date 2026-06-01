#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Agendada"
CONFIGURATION="${AGENDADA_CONFIGURATION:-release}"
ARCH="${AGENDADA_ARCH:-}"
if [[ -n "$ARCH" ]]; then
    TRIPLE_DIR="$ARCH-apple-macosx"
    PRODUCT_PATH="$ROOT_DIR/.build/$TRIPLE_DIR/$CONFIGURATION/$APP_NAME"
else
    PRODUCT_PATH="$ROOT_DIR/.build/$CONFIGURATION/$APP_NAME"
fi
APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

cd "$ROOT_DIR"
if [[ "${AGENDADA_SKIP_BUILD:-0}" != "1" ]]; then
    if [[ -n "$ARCH" ]]; then
        swift build -c "$CONFIGURATION" --arch "$ARCH"
    else
        swift build -c "$CONFIGURATION"
    fi
fi

if [[ ! -x "$PRODUCT_PATH" ]]; then
    echo "Missing built executable: $PRODUCT_PATH" >&2
    echo "Run swift build first, or run this script without AGENDADA_SKIP_BUILD=1." >&2
    exit 1
fi

if command -v codesign >/dev/null 2>&1; then
    codesign --force --sign - "$PRODUCT_PATH" >/dev/null
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$PRODUCT_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

PRODUCT_DIR="$(dirname "$PRODUCT_PATH")"
shopt -s nullglob
for bundle in "$PRODUCT_DIR"/*.bundle; do
    # SwiftPM's generated Bundle.module accessor for executable targets looks
    # next to Bundle.main.bundleURL, so the resource bundle must live directly
    # inside the .app package root rather than only in Contents/Resources.
    cp -R "$bundle" "$APP_DIR/"
done
shopt -u nullglob

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>Agendada</string>
    <key>CFBundleIdentifier</key>
    <string>local.agendada.mvp</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Agendada</string>
    <key>CFBundleDisplayName</key>
    <string>Agendada</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSCalendarsFullAccessUsageDescription</key>
    <string>Agendada 需要读取和显示你的日历事件，以便在时间线中关联日程。</string>
    <key>NSCalendarsUsageDescription</key>
    <string>Agendada 需要读取和显示你的日历事件，以便在时间线中关联日程。</string>
    <key>NSRemindersFullAccessUsageDescription</key>
    <string>Agendada 需要读取和管理你的提醒事项，以便在时间线中显示并勾选提醒。</string>
    <key>NSRemindersUsageDescription</key>
    <string>Agendada 需要读取和管理你的提醒事项，以便在时间线中显示并勾选提醒。</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

cat > "$CONTENTS_DIR/PkgInfo" <<'PKGINFO'
APPL????
PKGINFO

echo "$APP_DIR"
