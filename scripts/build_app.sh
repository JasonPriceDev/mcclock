#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

app="$(pwd)/build/McClock.app"
mkdir -p "$app/Contents/MacOS"
sdk="$(xcrun --sdk macosx --show-sdk-path)"
xcrun swiftc -O -sdk "$sdk" -target "$(uname -m)-apple-macos13.0" \
    -module-cache-path "$(pwd)/build/ModuleCache" \
    Sources/McClock/ClockFormatter.swift Sources/McClock/main.swift \
    -o "$app/Contents/MacOS/McClock"
cp Resources/Info.plist "$app/Contents/Info.plist"
if [ -n "${MCLOCK_SIGNING_IDENTITY:-}" ]; then
    codesign --force --options runtime --sign "$MCLOCK_SIGNING_IDENTITY" "$app"
else
    codesign --force --sign - "$app"
    printf '%s\n' 'Ad hoc signed for local use. Set MCLOCK_SIGNING_IDENTITY to an Apple signing identity for validated system-service access.' >&2
fi
printf '%s\n' "$app"
