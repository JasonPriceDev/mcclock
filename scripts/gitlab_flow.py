#!/usr/bin/env python3
"""Configure GitHub for a linear GitLab Flow with fast-forward environments."""

import argparse
import json
import re
import shutil
import subprocess


RULE_PREFIX = "gitlab-flow:"
NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


def fail(message):
    raise SystemExit(message)


def api(path, method="GET", data=None, missing_ok=False):
    command = ["gh", "api", path]
    if method != "GET":
        command += ["--method", method]
    if data is not None:
        command += ["--input", "-"]
    result = subprocess.run(
        command, input=json.dumps(data) if data is not None else None,
        text=True, capture_output=True, check=False,
    )
    if result.returncode:
        if missing_ok and re.search(r"HTTP 404\b", result.stderr):
            return None
        fail(f"gh api {path} failed: {result.stderr.strip()}")
    return json.loads(result.stdout) if result.stdout.strip() else None


def branch_name(value):
    if not NAME.fullmatch(value) or ".." in value or value.endswith(".lock"):
        fail(f"Invalid branch name: {value!r}")
    return value


def repo_name(value):
    parts = value.split("/")
    if len(parts) != 2 or not all(NAME.fullmatch(part) for part in parts):
        fail("--repo must be OWNER/REPO")
    return value


def branch(repo, name):
    return api(f"repos/{repo}/branches/{name}", missing_ok=True)


def ruleset(name, branches, require_pr=False):
    rules = [
        {"type": "deletion"},
        {"type": "non_fast_forward"},
        {"type": "required_linear_history"},
    ]
    if require_pr:
        rules.append({"type": "pull_request", "parameters": {
            "allowed_merge_methods": ["squash"],
            "dismiss_stale_reviews_on_push": True,
            "require_code_owner_review": False,
            "require_last_push_approval": False,
            "required_approving_review_count": 0,
            "required_review_thread_resolution": True,
        }})
    return {
        "name": RULE_PREFIX + name,
        "target": "branch",
        "enforcement": "active",
        "conditions": {"ref_name": {
            "include": [f"refs/heads/{item}" for item in branches],
            "exclude": [],
        }},
        "rules": rules,
    }


def existing_rulesets(repo):
    # Rulesets with these names belong to this script; leave all others alone.
    result = subprocess.run(
        ["gh", "api", "--paginate", "--slurp",
         f"repos/{repo}/rulesets?includes_parents=false&per_page=100"],
        text=True, capture_output=True, check=False,
    )
    if result.returncode:
        fail(f"Cannot list rulesets: {result.stderr.strip()}")
    return {item["name"]: item["id"]
            for page in json.loads(result.stdout) for item in page
            if item["name"].startswith(RULE_PREFIX)}


def configure(args):
    repo = repo_name(args.repo)
    info = api(f"repos/{repo}")
    default = branch_name(info["default_branch"])
    environments = [branch_name(item.strip()) for item in args.environments.split(",")]
    if not environments or any(not item for item in environments):
        fail("Provide at least one environment branch")
    if len(set([default, *environments])) != len(environments) + 1:
        fail("Environment branches must be distinct from each other and the default branch")
    if not branch(repo, default):
        fail(f"Default branch {default} has no commit; initialize the repository first")

    print(f"Repository: {repo}; flow: {default} -> {' -> '.join(environments)}")
    print("Repository: disable merge commits and rebase merges; enable squash merges")
    print("Default branch: PR required, squash only, linear history, no force push/deletion")
    print("Environments: linear history, no force push/deletion; fast-forward promotion")
    for name in environments:
        if not branch(repo, name):
            print(f"Create {name} from its predecessor")
    if not args.apply:
        print("Preview only. Add --apply to write these settings.")
        return

    api(f"repos/{repo}", "PATCH", {
        "allow_merge_commit": False,
        "allow_squash_merge": True,
        "allow_rebase_merge": False,
        "delete_branch_on_merge": True,
    })
    predecessor = default
    for name in environments:
        if not branch(repo, name):
            sha = branch(repo, predecessor)["commit"]["sha"]
            api(f"repos/{repo}/git/refs", "POST", {
                "ref": f"refs/heads/{name}", "sha": sha,
            })
        predecessor = name

    owned = existing_rulesets(repo)
    for payload in (ruleset("development", [default], True),
                    ruleset("environments", environments)):
        name = payload["name"]
        if name in owned:
            api(f"repos/{repo}/rulesets/{owned[name]}", "PUT", payload)
            print(f"Updated ruleset {name}")
        else:
            api(f"repos/{repo}/rulesets", "POST", payload)
            print(f"Created ruleset {name}")


def promote(args):
    repo = repo_name(args.repo)
    info = api(f"repos/{repo}")
    default = branch_name(info["default_branch"])
    environments = [branch_name(item.strip()) for item in args.environments.split(",")]
    if len(set([default, *environments])) != len(environments) + 1:
        fail("Environment branches must be distinct")
    target = branch_name(args.to)
    if target not in environments:
        fail(f"Target must be one of: {', '.join(environments)}")
    source = [default, *environments][environments.index(target)]
    if not branch(repo, target) or not branch(repo, source):
        fail("Source and target branches must exist; run configure first")
    comparison = api(f"repos/{repo}/compare/{target}...{source}")
    if comparison["status"] not in ("ahead", "identical"):
        fail(f"Cannot fast-forward {target} from {source}: branches have diverged")
    sha = branch(repo, source)["commit"]["sha"]
    print(f"Promote {source} ({sha}) -> {target}")
    if not args.apply:
        print("Preview only. Add --apply to promote.")
        return
    if comparison["status"] == "identical":
        print("Already up to date")
        return
    # GitHub verifies ancestry again, so a concurrent target update cannot be overwritten.
    api(f"repos/{repo}/git/refs/heads/{target}", "PATCH", {
        "sha": sha, "force": False,
    })
    print(f"Promoted {target} to {sha}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("configure", "promote"))
    parser.add_argument("--repo", required=True, help="OWNER/REPO")
    parser.add_argument("--environments", default="staging,production",
                        help="Comma-separated promotion order (default: staging,production)")
    parser.add_argument("--to", help="Target environment branch for promote")
    parser.add_argument("--apply", action="store_true", help="Write changes (default: preview)")
    args = parser.parse_args()
    if shutil.which("gh") is None:
        fail("GitHub CLI (gh) is required: https://cli.github.com/")
    if args.command == "promote":
        if not args.to:
            parser.error("promote requires --to")
        promote(args)
    else:
        configure(args)


if __name__ == "__main__":
    main()
