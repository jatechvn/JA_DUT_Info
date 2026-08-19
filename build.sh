#!/bin/bash
cd "$(dirname "$0")"

OS_NAME="$(uname -s)"
case "$OS_NAME" in
    Darwin*)
        TARGET="macos"
        SRC_DIR="build/macos/Build/Products/Release"
        ;;
    *)
        TARGET="linux"
        SRC_DIR="build/linux/x64/release/bundle"
        ;;
esac

echo "[BUILD] Compiling $TARGET desktop application in Release mode..."
flutter build "$TARGET"
if [ $? -ne 0 ]; then
    echo "[ERROR] Build failed!"
    exit 1
fi

echo "[DIST] Copying release files to /dist..."
mkdir -p dist
cp -R "$SRC_DIR"/* dist/
echo "[SUCCESS] Release build is complete. Output files copied to /dist"
