#!/bin/bash
# Builds "Markdown Editor.app" (release, for this Mac's architecture) into macos/build.
# --install also copies it to /Applications and registers it with Launch Services ("Open With").
set -euo pipefail

VERSION="0.1.0"
APP_NAME="Markdown Editor"
INSTALL_DIR="/Applications"

MACOS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_DIR="$(dirname "$MACOS_DIR")"
BUILD_DIR="$MACOS_DIR/build"
APP="$BUILD_DIR/$APP_NAME.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

install=false
for argument in "$@"; do
    case "$argument" in
        --install) install=true ;;
        *) echo "usage: $0 [--install]" >&2; exit 2 ;;
    esac
done

swift build --package-path "$MACOS_DIR" -c release --product MarkdownEditor
BINARY="$(swift build --package-path "$MACOS_DIR" -c release --show-bin-path)/MarkdownEditor"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/MarkdownEditor"
sed "s/__VERSION__/$VERSION/g" "$MACOS_DIR/Resources/Info.plist" > "$APP/Contents/Info.plist"

# Preview assets shared with the Windows app.
mkdir -p "$APP/Contents/Resources/shared"
cp -R "$REPO_DIR/shared/preview" "$REPO_DIR/shared/plugins" "$APP/Contents/Resources/shared/"

# App icon, from the same source as the Windows icon.
ICONSET="$BUILD_DIR/AppIcon.iconset"
rm -rf "$ICONSET"
swift "$MACOS_DIR/Scripts/make-icon.swift" "$REPO_DIR/shared/icon/app-icon.svg" "$ICONSET"
iconutil --convert icns --output "$APP/Contents/Resources/AppIcon.icns" "$ICONSET"
rm -rf "$ICONSET"

# Ad-hoc signature: enough to run on the Mac that built it.
codesign --force --sign - "$APP"
echo "Built $APP"

if $install; then
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
    cp -R "$APP" "$INSTALL_DIR/"
    "$LSREGISTER" -f "$INSTALL_DIR/$APP_NAME.app"
    echo "Installed $INSTALL_DIR/$APP_NAME.app"
fi
