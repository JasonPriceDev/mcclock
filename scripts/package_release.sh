#!/bin/sh
set -eu

cd "$(dirname "$0")/.."

tag=${1:-}
case "$tag" in
    v[0-9]*.[0-9]*.[0-9]*) ;;
    *) printf '%s\n' 'Pass a version tag such as v1.0.0' >&2; exit 1 ;;
esac
version=${tag#v}
if ! printf '%s\n' "$version" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'; then
    printf '%s\n' 'Release tags must use vMAJOR.MINOR.PATCH' >&2
    exit 1
fi
plist_version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)
if [ "$version" != "$plist_version" ]; then
    printf 'Tag %s does not match CFBundleShortVersionString %s\n' "$tag" "$plist_version" >&2
    exit 1
fi
: "${MCLOCK_SIGNING_IDENTITY:?Set MCLOCK_SIGNING_IDENTITY to a Developer ID Application identity}"
: "${NOTARY_KEY_PATH:?Set NOTARY_KEY_PATH to the App Store Connect API .p8 file}"
: "${NOTARY_KEY_ID:?Set NOTARY_KEY_ID}"
: "${NOTARY_ISSUER_ID:?Set NOTARY_ISSUER_ID}"

MCLOCK_ARCHS='arm64 x86_64' MCLOCK_SIGNING_TIMESTAMP=1 scripts/build_app.sh
app=build/McClock.app
xcrun lipo "$app/Contents/MacOS/McClock" -verify_arch arm64
xcrun lipo "$app/Contents/MacOS/McClock" -verify_arch x86_64
codesign --verify --strict --verbose=2 "$app"
if ! codesign -dv --verbose=4 "$app" 2>&1 | grep -q '^Authority=Developer ID Application:'; then
    printf '%s\n' 'Release app must be signed with a Developer ID Application certificate' >&2
    exit 1
fi

submission=build/McClock-notarization.zip
ditto -c -k --keepParent "$app" "$submission"
xcrun notarytool submit "$submission" --wait \
    --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID" \
    --output-format plist > build/notarization-result.plist
status=$(/usr/libexec/PlistBuddy -c 'Print status' build/notarization-result.plist)
if [ "$status" != Accepted ]; then
    printf 'Notarization status: %s\n' "$status" >&2
    submission_id=$(/usr/libexec/PlistBuddy -c 'Print id' build/notarization-result.plist)
    xcrun notarytool log "$submission_id" \
        --key "$NOTARY_KEY_PATH" --key-id "$NOTARY_KEY_ID" --issuer "$NOTARY_ISSUER_ID" || true
    exit 1
fi
xcrun stapler staple "$app"
xcrun stapler validate "$app"
codesign --verify --strict --verbose=2 "$app"
spctl --assess --type execute --verbose "$app"

asset="build/McClock-$tag-universal.zip"
ditto -c -k --keepParent "$app" "$asset"
(cd build && shasum -a 256 "$(basename "$asset")" > "$(basename "$asset").sha256")
printf 'Release asset: %s\n' "$asset"
