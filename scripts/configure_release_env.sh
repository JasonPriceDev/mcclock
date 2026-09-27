#!/bin/sh
# Configure the GitHub Actions "release" environment for McClock.
#
# Creates (or reuses) the environment, restricts it to the main branch, and
# stores the five secrets that .github/workflows/release.yml reads.
#
# Run this yourself, in your own terminal. Secret values are read from local
# files or typed at a prompt and are passed to GitHub over standard input only,
# so they never become command arguments, appear in the process list, or get
# printed in this script's output.

set -eu

cd "$(dirname "$0")/.."

usage() {
    cat >&2 <<'USAGE'
Usage: scripts/configure_release_env.sh --p12 FILE --notary-key FILE [--reviewer LOGIN]...

Creates the GitHub Actions "release" environment, restricts it to main, and
stores the secrets required by .github/workflows/release.yml.

  --p12 FILE          Developer ID Application certificate and key (.p12)
  --notary-key FILE   App Store Connect API key (.p8)
  --reviewer LOGIN    Require approval from this GitHub user before the signing
                      job can read the secrets. Repeat for more reviewers.
  -h, --help          Show this help.

The .p12 export password and the App Store Connect key ID and issuer ID are
prompted for, unless MCLOCK_P12_PASSWORD, NOTARY_KEY_ID, and NOTARY_ISSUER_ID
are already set. Paths may also come from MCLOCK_P12_PATH and
MCLOCK_NOTARY_KEY_PATH.

Requires macOS (for its base64) and the GitHub CLI authenticated as a
repository admin. Nothing else is uploaded; only the named secrets are sent.
USAGE
}

p12=${MCLOCK_P12_PATH:-}
notary_key=${MCLOCK_NOTARY_KEY_PATH:-}
reviewers=''

while [ "$#" -gt 0 ]; do
    case "$1" in
        --p12)       [ "$#" -ge 2 ] || { usage; exit 1; }; p12=$2; shift 2 ;;
        --notary-key) [ "$#" -ge 2 ] || { usage; exit 1; }; notary_key=$2; shift 2 ;;
        --reviewer)  [ "$#" -ge 2 ] || { usage; exit 1; }; reviewers="$reviewers $2"; shift 2 ;;
        -h|--help)   usage; exit 0 ;;
        *)           printf 'Unknown option: %s\n' "$1" >&2; usage; exit 1 ;;
    esac
done

for file in "$p12" "$notary_key"; do
    if [ -z "$file" ] || [ ! -f "$file" ]; then
        printf 'Not a readable file: %s\n' "${file:-<none given>}" >&2
        usage
        exit 1
    fi
done

if ! printf '' | base64 -b 0 >/dev/null 2>&1; then
    printf '%s\n' 'This script needs the macOS base64, which supports -b.' >&2
    exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
    printf '%s\n' 'The GitHub CLI is required: https://cli.github.com/' >&2
    exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
    printf '%s\n' 'Authenticate first with: gh auth login' >&2
    exit 1
fi

repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)
if [ -z "$repo" ]; then
    printf '%s\n' 'Run this from a clone of the repository you want to configure.' >&2
    exit 1
fi

prompt_value() {
    # $1 = prompt, $2 = variable name to assign, $3 = non-interactive hint
    if [ ! -t 0 ]; then
        printf '%s\n' "$3" >&2
        exit 1
    fi
    printf '%s' "$1" >&2
    IFS= read -r "$2"
}

password=${MCLOCK_P12_PASSWORD:-}
if [ -z "$password" ]; then
    prompt_value "Export password for $(basename "$p12"): " password \
        'Set MCLOCK_P12_PASSWORD or run this script in a terminal to be prompted.'
fi
if [ -z "$password" ]; then
    printf '%s\n' 'The .p12 export password cannot be empty.' >&2
    exit 1
fi

key_id=${NOTARY_KEY_ID:-}
if [ -z "$key_id" ]; then
    prompt_value 'App Store Connect API key ID: ' key_id \
        'Set NOTARY_KEY_ID or run this script in a terminal to be prompted.'
fi
if [ -z "$key_id" ]; then
    printf '%s\n' 'The App Store Connect key ID cannot be empty.' >&2
    exit 1
fi

issuer_id=${NOTARY_ISSUER_ID:-}
if [ -z "$issuer_id" ]; then
    prompt_value 'App Store Connect issuer ID: ' issuer_id \
        'Set NOTARY_ISSUER_ID or run this script in a terminal to be prompted.'
fi
if [ -z "$issuer_id" ]; then
    printf '%s\n' 'The App Store Connect issuer ID cannot be empty.' >&2
    exit 1
fi

reviewer_json=''
for login in $reviewers; do
    id=$(gh api "users/$login" --jq .id 2>/dev/null || true)
    case "$id" in
        ''|*[!0-9]*) printf 'No GitHub user found for %s\n' "$login" >&2; exit 1 ;;
    esac
    reviewer_json="$reviewer_json,{\"type\":\"User\",\"id\":$id}"
done

policy='"deployment_branch_policy":{"protected_branches":false,"custom_branch_policies":true}'
if [ -n "$reviewer_json" ]; then
    body="{$policy,\"reviewers\":[${reviewer_json#,}]}"
else
    body="{$policy}"
fi

printf 'Configuring %s environment "release"\n' "$repo" >&2
printf '%s' "$body" | gh api --method PUT "repos/$repo/environments/release" --input - >/dev/null

existing_branches=$(gh api "repos/$repo/environments/release/deployment-branch-policies" \
    --jq '.branch_policies[].name' 2>/dev/null || true)
if printf '%s\n' "$existing_branches" | grep -qx main; then
    printf '%s\n' 'Branch policy for main already present.' >&2
else
    gh api --method POST "repos/$repo/environments/release/deployment-branch-policies" \
        -f name=main -f type=branch >/dev/null
    printf '%s\n' 'Restricted the environment to the main branch.' >&2
fi

set_secret() {
    # Secret value arrives on standard input so it stays out of the process list.
    gh secret set "$1" --env release --repo "$repo" >/dev/null
}

printf 'Storing secrets\n' >&2
base64 -b 0 -i "$p12" | set_secret DEVELOPER_ID_P12_BASE64
printf '%s' "$password" | set_secret DEVELOPER_ID_P12_PASSWORD
base64 -b 0 -i "$notary_key" | set_secret NOTARY_API_KEY_BASE64
printf '%s' "$key_id" | set_secret NOTARY_KEY_ID
printf '%s' "$issuer_id" | set_secret NOTARY_ISSUER_ID
password=''

printf '\nSecrets in the release environment:\n'
gh secret list --env release --repo "$repo"
printf '\nDone. Start a release with: Actions -> Release McClock -> Run workflow\n'
