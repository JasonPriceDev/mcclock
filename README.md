# McClock

McClock is a small macOS menu-bar clock. It shows the local date in ISO 8601
`YYYY-MM-DD` format alongside the current local time and updates every second.
Open its menu to toggle seconds, copy the current time, or quit. The seconds setting is saved
between launches. It has no Dock icon.

To place McClock beside the system clock, hold Command and drag its menu-bar
item to the right. macOS keeps its own clock at the far-right edge and does not
offer a setting to replace or hide it. McClock saves its chosen menu-bar
position across launches.

Requires macOS 13 or newer and the Xcode command-line toolchain.

```sh
swift test --disable-sandbox
scripts/build_app.sh
open build/McClock.app
```

The build script creates an ad-hoc signed app at `build/McClock.app`. It uses
the installed Xcode toolchain when Xcode is in `/Applications/Xcode.app`.
For a validated build, install an Apple Development or Developer ID Application
certificate and run `MCLOCK_SIGNING_IDENTITY="certificate name" scripts/build_app.sh`.

## GitLab Flow on GitHub

`scripts/gitlab_flow.py` configures a repository with a development branch (its
current default branch) and ordered environment branches. The default flow is
`main -> staging -> production` when the repository's default branch is `main`.

Requirements: Python 3, [GitHub CLI](https://cli.github.com/) authenticated with
repository Administration (write) and Contents (write) permissions. Initialize
the default branch with a commit before running the script.

```sh
python3 scripts/gitlab_flow.py configure --repo OWNER/REPO
python3 scripts/gitlab_flow.py configure --repo OWNER/REPO --apply

# After changes land on the default branch:
python3 scripts/gitlab_flow.py promote --repo OWNER/REPO --to staging --apply
python3 scripts/gitlab_flow.py promote --repo OWNER/REPO --to production --apply
```

Omit `--apply` to preview. Choose a different ordered chain with
`--environments qa,staging,production` on **every** command. Re-running
`configure --apply` leaves existing environment branches in place and updates
the two `gitlab-flow:` rulesets managed by this script. Other rulesets remain
untouched.

The configuration disables merge commits and rebase merges at repository level,
allows squash merging for feature PRs, and requires PRs for the default branch.
It protects the default and environment branches against force pushes, deletion,
and merge commits. Environment branches allow ordinary fast-forward updates so
the promotion command can preserve commit ancestry. The command accepts only
the immediately preceding branch as the source and refuses divergent history.

GitHub rulesets do not enforce that environment updates come only from their
predecessor; users with write access can still push other linear commits there.
Restrict write access or use a dedicated promotion actor if that policy is
required. Do not use GitHub's squash/rebase PR merge button for promotions:
GitHub creates new commit SHAs, which breaks the ancestry this flow needs.
Existing commits and any existing branch protection rules are not rewritten.
