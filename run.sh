#!/bin/bash
# Move to the directory containing this script
cd "$(dirname "$0")"

# Detect OS to select target desktop platform
OS_NAME="$(uname -s)"
case "$OS_NAME" in
    Darwin*)
        TARGET="macos"
        ;;
    Linux*)
        TARGET="linux"
        ;;
    *)
        TARGET="linux"
        ;;
esac

flutter run -d "$TARGET"
