#!/bin/zsh
# ./build.sh            build HiDPI.app and set-hidpi into build/
# ./build.sh install    also copy HiDPI.app to ~/Applications and start it
set -euo pipefail
cd "${0:A:h}"

APP=build/HiDPI.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Info.plist "$APP/Contents/Info.plist"

swiftc -O -wmo -target arm64-apple-macos13.0 \
  -import-objc-header Sources/CGSPrivate.h \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/HiDPI"
codesign --force --sign - "$APP"

clang -O2 -o build/set-hidpi set-hidpi.c -framework CoreGraphics -framework CoreFoundation

if [[ "${1:-}" == "install" ]]; then
  pkill -x HiDPI && sleep 1 || true
  mkdir -p ~/Applications
  rm -rf ~/Applications/HiDPI.app
  cp -R "$APP" ~/Applications/
  open ~/Applications/HiDPI.app
fi
