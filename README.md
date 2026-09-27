# McClock

McClock is a macOS menu-bar clock that shows the local date in ISO 8601
`YYYY-MM-DD` format followed by the local time. It refreshes every second and
has no Dock icon.

Its menu lets you toggle seconds, copy the exact date and time shown in the
menu bar, or quit. The seconds setting persists across launches. To reposition
McClock, hold Command and drag its menu-bar item. macOS keeps its built-in clock
at the far right; McClock cannot replace it. The chosen position persists
across launches.

## Build and install

Requires macOS 13 or newer and Xcode with the macOS SDK. The tests use Swift
Testing, so run them with the full Xcode toolchain. With Xcode installed at
`/Applications/Xcode.app`, run:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
scripts/build_app.sh
open build/McClock.app
```

The build script creates `build/McClock.app` and signs it ad hoc by default.
It selects `/Applications/Xcode.app` automatically when `DEVELOPER_DIR` is
unset; set `DEVELOPER_DIR` yourself if Xcode is elsewhere.
To sign with an installed Apple Development or Developer ID Application identity,
first find its SHA-1 hash with `security find-identity -v -p codesigning`, then run:

```sh
MCLOCK_SIGNING_IDENTITY=SHA1_FROM_ABOVE scripts/build_app.sh
```

On this Mac, Apple Development signing also prevents the `linkd`
`requiresValidatedBundle` warning seen with the ad hoc build. The identity must
appear under `valid identities` in the `security find-identity` output.

To install the built app for your user account, quit any running McClock copy
from its menu, then run:

```sh
mkdir -p ~/Applications
ditto build/McClock.app ~/Applications/McClock.app
open ~/Applications/McClock.app
```

Run only one copy at a time to avoid duplicate clocks in the menu bar. Use the
same `ditto` command to update an existing installation after quitting it.

## Repository workflow

Changes reach `main` through squash-merged pull requests. The `main` ruleset
requires a pull request and linear history, and blocks force pushes and branch
deletion. There are no environment branches. The [CI workflow](.github/workflows/ci.yml)
runs tests and builds the universal app for pull requests and pushes to `main`.

## Publish a GitHub Release

The [release workflow](.github/workflows/release.yml) publishes a universal
macOS app for Apple silicon and Intel. It runs only when started manually from
`main` with an existing `vMAJOR.MINOR.PATCH` tag pointing to a commit on `main`.
It checks the tag against `CFBundleShortVersionString`, runs the tests, signs
with a Developer ID Application certificate, notarizes with Apple, staples the
ticket, verifies the app, and creates a **draft** GitHub Release containing a
ZIP and SHA-256 checksum. Review the draft and publish it on GitHub.

Before the first release, create a GitHub Actions environment named `release`
under **Settings → Environments**. Add these environment secrets:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | Base64 of an exported **Developer ID Application** `.p12` certificate and private key |
| `DEVELOPER_ID_P12_PASSWORD` | Export password for that `.p12` |
| `NOTARY_API_KEY_BASE64` | Base64 of an App Store Connect **team** API key `.p8` |
| `NOTARY_KEY_ID` | App Store Connect API key ID |
| `NOTARY_ISSUER_ID` | App Store Connect issuer ID |

On macOS, `base64 -i certificate.p12 | pbcopy` (and likewise for the `.p8`)
copies the encoded value for entry into the secret field. Never commit these
files or encoded values. Restrict environment access to `main` and, if desired,
require approval before the signing job can read its secrets. The local Apple
Development identity is only for development; public direct downloads need
Developer ID signing and notarization.

For each version, update `CFBundleShortVersionString` and increment
`CFBundleVersion` in [Resources/Info.plist](Resources/Info.plist) through a PR.
After merging, create and push an annotated tag on that `main` commit:

```sh
git switch main
git pull --ff-only
git tag -a v1.0.0 -m 'McClock v1.0.0'
git push origin v1.0.0
```

Then run **Actions → Release McClock → Run workflow** from `main`, entering
`v1.0.0`. Inspect the draft release, its asset, checksum, and workflow logs
before publishing. Use the version appropriate to that release in place of
`v1.0.0`. The latest published version will be at
<https://github.com/JasonPriceDev/mcclock/releases/latest>.
