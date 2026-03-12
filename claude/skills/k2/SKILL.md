---
name: k2
description: Show your GitHub dashboard - issues assigned to you, PRs to review, and your open PRs across Expensify repos
---

# K2 Dashboard

Show the user's current work items from GitHub, replicating the K2 browser extension dashboard.

## How to execute

### Step 1: Fetch data

Run all 5 `gh` commands **in parallel**:

```bash
gh search prs --state=open --review-requested=@me --owner=Expensify --json title,url,updatedAt,author,repository,isDraft

gh search prs --state=open --reviewed-by=@me --owner=Expensify --json title,url,updatedAt,author,repository,isDraft

gh search issues --state=open --assignee=@me --repo=Expensify/Expensify --repo=Expensify/App --repo=Expensify/Insiders --json title,url,labels,updatedAt,createdAt,repository,assignees,body --limit 100

gh search prs --state=open --assignee=@me --owner=Expensify --json title,url,updatedAt,author,repository,isDraft

gh search prs --state=open --author=@me --owner=Expensify --json title,url,updatedAt,author,repository,isDraft
```

### Step 2: Present results

Organize output into these sections, in this order:

#### 1. PRs to Review

Combine results from the review-requested and reviewed-by queries, deduplicate by URL, and **exclude PRs authored by the current user**. Sort by updatedAt (most recent first). For each PR show:
- Title (as a markdown link to the URL)
- Repository name
- Author
- Whether it's a draft

#### 2. Your Issues

Display issues grouped by priority label into sub-sections:
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

Combine results from the assigned and authored queries, deduplicate by URL. Sort by updatedAt (most recent first). For each PR show:
- Title (as a markdown link to the URL)
- Repository name
- Whether it's a draft

### Notes
- If any command fails, report the error but still show results from the other commands.
- To get the current user's GitHub username for filtering, use the author field from "Your PRs" results, or run `gh api user --jq .login`.
