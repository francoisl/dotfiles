#!/usr/bin/env python3
"""Fetch the PRs awaiting my review, enrich them with metadata, and triage.

Emits compact JSON on stdout with four buckets:

    review   - worth spending a review on, cheapest (smallest) first
    deferred - reviewable but over the run's limit
    skipped  - not my turn, or not reviewable (each with a reason)
    errors   - PRs whose metadata could not be fetched

Env:
    RQ_OWNER       GitHub owner to search (default: Expensify)
    RQ_CLONE_ROOT  where local clones live (default: ~/Expensidev)
    RQ_CI_IGNORE   regex of check names that gate on review, not code health
"""

import argparse
import json
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

OWNER = os.environ.get("RQ_OWNER", "Expensify")
CLONE_ROOT = os.path.expanduser(os.environ.get("RQ_CLONE_ROOT", "~/Expensidev"))

# Checks that gate on "has a human reviewed this yet", not on code health. These
# fail *because* it is my turn to review, so treating them as CI failure would
# skip the entire queue -- Expensify's "Verify peer review / Check independent
# approval" fails on every unreviewed PR.
#
# Deliberately narrow. Over-matching here hides real CI failures and can produce
# a false "ready to merge", which is far worse than skipping a PR: a bare
# "approval" would also swallow a failing ApprovalTests suite.
CI_IGNORE = re.compile(
    os.environ.get("RQ_CI_IGNORE",
                   r"peer[ _-]?review|independent[ _-]approval|codeowner"),
    re.IGNORECASE,
)

FIELDS = ",".join([
    "number", "title", "url", "additions", "deletions", "changedFiles",
    "isDraft", "mergeable", "reviewDecision", "labels", "author",
    "headRefOid", "statusCheckRollup", "latestReviews", "updatedAt",
])


def gh(args, timeout=180):
    return subprocess.run(["gh", *args], capture_output=True, text=True, timeout=timeout)


def die(msg):
    print(msg, file=sys.stderr)
    sys.exit(1)


def ci_state(pr):
    """Collapse statusCheckRollup into (state, ignored_gate_names).

    Rollup entries are either CheckRun (status/conclusion) or StatusContext (state),
    so both shapes have to be handled. Review-process gates are reported separately
    rather than counted as failures.
    """
    roll = pr.get("statusCheckRollup") or []
    if not roll:
        return "NONE", []
    bad = pending = 0
    ignored = []
    for c in roll:
        label = f"{c.get('workflowName') or ''} {c.get('name') or c.get('context') or ''}"
        state = (c.get("conclusion") or c.get("state") or "").upper()
        status = (c.get("status") or "").upper()
        failed = state in ("FAILURE", "ERROR", "TIMED_OUT", "STARTUP_FAILURE")
        if failed and CI_IGNORE.search(label):
            ignored.append((c.get("name") or c.get("context") or "?").strip())
            continue
        if failed:
            bad += 1
        elif status in ("QUEUED", "IN_PROGRESS", "WAITING", "PENDING") or state == "PENDING":
            pending += 1
    if bad:
        return "FAILING", ignored
    if pending:
        return "PENDING", ignored
    return "PASSING", ignored


def my_latest_review(pr, me):
    for r in pr.get("latestReviews") or []:
        if ((r.get("author") or {}).get("login") or "").lower() == me.lower():
            return (r.get("state") or "").upper()
    return None


def triage(pr, me):
    """Return a skip reason, or None if this PR is worth reviewing."""
    title = pr["title"]
    if pr.get("isDraft"):
        return "draft"
    if "[hold" in title.lower():
        return "on hold (title says [HOLD...])"
    mine = my_latest_review(pr, me)
    if mine == "APPROVED":
        return "you already approved it"
    if mine == "CHANGES_REQUESTED":
        return "you requested changes; waiting on author"
    if (pr.get("mergeable") or "").upper() == "CONFLICTING":
        return "merge conflicts; author's turn"
    if pr["_ci"] == "FAILING":
        return "CI failing; author's turn"
    if not os.path.isdir(os.path.join(CLONE_ROOT, pr["_repo"], ".git")):
        return f"no local clone at {os.path.join(CLONE_ROOT, pr['_repo'])}"
    return None


def slim(pr, extra=None):
    out = {
        "repo": pr["_repo"],
        "number": pr["number"],
        "title": pr["title"][:100],
        "author": (pr.get("author") or {}).get("login", "?"),
        "churn": pr["_churn"],
        "files": pr.get("changedFiles", 0),
        "ci": pr["_ci"],
        "url": pr["url"],
    }
    if pr["_ci_ignored"]:
        # Surfaced rather than hidden: these are review gates we deliberately
        # did not treat as CI failure.
        out["ci_gates_ignored"] = pr["_ci_ignored"]
    if extra:
        out.update(extra)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=6,
                    help="how many PRs to actually review this run")
    ap.add_argument("--repo", default=None,
                    help="only consider PRs in this repo (name, not owner/name)")
    args = ap.parse_args()

    who = gh(["api", "user", "--jq", ".login"])
    if who.returncode:
        die(f"gh api user failed: {who.stderr.strip()}")
    me = who.stdout.strip()

    search = gh(["search", "prs", "--state=open", "--review-requested=@me",
                 f"--owner={OWNER}", "--json", "url", "--limit", "100"])
    if search.returncode:
        die(f"gh search prs failed: {search.stderr.strip()}")
    urls = [x["url"] for x in json.loads(search.stdout or "[]")]

    def fetch(url):
        p = gh(["pr", "view", url, "--json", FIELDS])
        if p.returncode:
            return {"_error": p.stderr.strip()[:200], "url": url}
        pr = json.loads(p.stdout)
        pr["url"] = url
        pr["_repo"] = url.split("/")[4]
        pr["_churn"] = pr.get("additions", 0) + pr.get("deletions", 0)
        pr["_ci"], pr["_ci_ignored"] = ci_state(pr)
        return pr

    with ThreadPoolExecutor(max_workers=8) as ex:
        prs = list(ex.map(fetch, urls))

    errors = [p for p in prs if "_error" in p]
    prs = [p for p in prs if "_error" not in p]

    if args.repo:
        prs = [p for p in prs if p["_repo"].lower() == args.repo.lower()]

    reviewable, skipped = [], []
    for pr in prs:
        reason = triage(pr, me)
        if reason:
            skipped.append(slim(pr, {"reason": reason}))
        else:
            reviewable.append(pr)

    # Cheapest first: the whole point is draining quick wins out of the backlog.
    reviewable.sort(key=lambda p: (p["_churn"], p.get("changedFiles", 0)))

    print(json.dumps({
        "me": me,
        "owner": OWNER,
        "total_awaiting_review": len(urls),
        "review": [slim(p) for p in reviewable[:args.limit]],
        "deferred": [slim(p) for p in reviewable[args.limit:]],
        "skipped": skipped,
        "errors": errors,
    }, indent=1))


if __name__ == "__main__":
    main()
