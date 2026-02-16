---
name: k2
description: Show your GitHub dashboard - issues assigned to you, PRs to review, and your open PRs across Expensify repos
---

# K2 Dashboard

Show the user's current work items from GitHub, replicating the K2 browser extension dashboard.

## How to execute

### Step 1: Check cache freshness

Cache lives in `~/.cache/k2/`. Run this command first:

```bash
# Check if cache exists and is less than 6 hours old
find ~/.cache/k2 -name "prs_review_requested.json" -newermt "6 hours ago" 2>/dev/null | head -1
```

- If the command outputs a file path, the cache is **fresh** — skip to Step 3 (read cache).
- If the command outputs nothing (empty), the cache is **stale or missing** — proceed to Step 2.

### Step 2: Fetch fresh data

Run `mkdir -p ~/.cache/k2` first, then run all 5 `gh` commands **in parallel**, writing output to cache files:

```bash
gh search prs --state=open --review-requested=@me --owner=Expensify --json title,url,updatedAt,author,repository,isDraft > ~/.cache/k2/prs_review_requested.json

gh search prs --state=open --reviewed-by=@me --owner=Expensify --json title,url,updatedAt,author,repository,isDraft > ~/.cache/k2/prs_reviewed_by.json

gh search issues --state=open --assignee=@me --repo=Expensify/Expensify --repo=Expensify/App --repo=Expensify/Insiders --json title,url,labels,updatedAt,createdAt,repository,assignees,body --limit 100 > ~/.cache/k2/issues_assigned.json

gh search prs --state=open --assignee=@me --owner=Expensify --json title,url,updatedAt,author,repository,isDraft > ~/.cache/k2/prs_assigned.json

gh search prs --state=open --author=@me --owner=Expensify --json title,url,updatedAt,author,repository,isDraft > ~/.cache/k2/prs_authored.json
```

After all commands complete, proceed to Step 3.

### Step 3: Read cache and present results

Read all 5 JSON files from `~/.cache/k2/` using the Read tool, then present the data as described below.

Also check when the cache was last updated:

```bash
stat -f "%Sm" -t "%Y-%m-%d %H:%M" ~/.cache/k2/prs_review_requested.json
```

Show the cache timestamp at the top of the output, e.g. "Data as of: 2025-01-15 14:30". If the data was just fetched, say "Data as of: just now".

### Presenting results

Organize output into these sections, in this order:

#### 1. PRs to Review

Combine results from `prs_review_requested.json` and `prs_reviewed_by.json`, deduplicate by URL, and **exclude PRs authored by the current user**. Sort by updatedAt (most recent first). For each PR show:
- Title (as a markdown link to the URL)
- Repository name
- Author
- Whether it's a draft

#### 2. Your Issues

Display issues from `issues_assigned.json`, grouped by priority label into sub-sections:
- **Hourly** - issues with the "Hourly" label
- **Daily** - issues with the "Daily" label
- **Weekly** - issues with the "Weekly" label
- **Monthly** - issues with the "Monthly" label
- **No Priority** - issues without any of the above labels

Within each group, sort by createdAt (oldest first, as older issues are higher priority). For each issue show:
- Title (as a markdown link to the URL)
- Repository name
- All label names
- Whether it's on hold (title contains "[hold" case-insensitive)
- Whether it's under review (has "Reviewing" label)

#### 3. Your Pull Requests

Combine results from `prs_assigned.json` and `prs_authored.json`, deduplicate by URL. Sort by updatedAt (most recent first). For each PR show:
- Title (as a markdown link to the URL)
- Repository name
- Whether it's a draft

### Notes
- If any command fails, report the error but still show results from the other commands.
- To get the current user's GitHub username for filtering, use the author field from "Your PRs" results, or run `gh api user --jq .login`.
- If the user says "refresh" or "force refresh", skip the cache check and go straight to Step 2 to fetch fresh data.
