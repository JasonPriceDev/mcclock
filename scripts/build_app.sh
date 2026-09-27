#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app/Contents/Developer ]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

app="$(pwd)/build/McClock.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
sdk="$(xcrun --sdk macosx --show-sdk-path)"
archs="${MCLOCK_ARCHS:-$(uname -m)}"
set -- $archs
if [ "$#" -eq 0 ]; then
    printf '%s\n' 'MCLOCK_ARCHS must contain at least one architecture' >&2
    exit 1
fi
for arch do
    case "$arch" in
        arm64|x86_64) ;;
        *) printf 'Unsupported architecture: %s\n' "$arch" >&2; exit 1 ;;
    esac
    mkdir -p "build/$arch"
    xcrun swiftc -O -sdk "$sdk" -target "$arch-apple-macos13.0" \
        -module-cache-path "$(pwd)/build/ModuleCache/$arch" \
        Sources/McClock/ClockFormatter.swift Sources/McClock/main.swift \
        -o "build/$arch/McClock"
done
if [ "$#" -eq 1 ]; then
    cp "build/$1/McClock" "$app/Contents/MacOS/McClock"
else
    inputs=""
    for arch do
        inputs="$inputs build/$arch/McClock"
    done
    # Architecture names are validated above, so these arguments contain no spaces.
    xcrun lipo -create $inputs -output "$app/Contents/MacOS/McClock"
fi
cp Resources/Info.plist "$app/Contents/Info.plist"
if [ -n "${MCLOCK_SIGNING_IDENTITY:-}" ]; then
    if [ "${MCLOCK_SIGNING_TIMESTAMP:-0}" = 1 ]; then
        codesign --force --options runtime --timestamp --sign "$MCLOCK_SIGNING_IDENTITY" "$app"
    else
        codesign --force --options runtime --sign "$MCLOCK_SIGNING_IDENTITY" "$app"
    fi
else
    codesign --force --sign - "$app"
    printf '%s\n' 'Ad hoc signed for local use. Set MCLOCK_SIGNING_IDENTITY to an Apple signing identity for validated system-service access.' >&2
fi
printf '%s\n' "$app"
