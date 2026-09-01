---
name: deploy-checklist
description: Triage unresolved deploy blockers on an Expensify StagingDeployCash deploy checklist. Reads the checklist issue, analyzes comments on each unchecked blocker in parallel via subagents, surfaces unchecked PRs that QA mentioned in checklist comments, and reports a status update with recommended actions (waiting for fix, needs cherry-pick, needs QA validation, can be checked off, etc.). Read-only — never posts comments or checks boxes. Pair with `/loop` for periodic monitoring (e.g. `/loop 20m /deploy-checklist`).
---

# Deploy Checklist Triage

Help the user (deploy chore owner) keep a `StagingDeployCash` deploy checklist moving by surfacing the current state of every **unchecked deploy blocker** and the action that would unblock it.

**Read-only.** Never post comments, never check checkboxes, never edit the issue. Only report.

## Step 1 — Resolve the checklist URL

If the user passed a URL as an argument, use it. Otherwise, find the latest open one:

```bash
gh issue list --repo Expensify/App --state open --label StagingDeployCash --json number,title,url,createdAt --limit 5
```

There is normally exactly one. If multiple, present them and ask which to triage. If none, tell the user and stop.

## Step 2 — Fetch and parse the checklist

Fetch the body **and the comments** in one shot:

```bash
gh issue view <number> --repo Expensify/App --json body,title,comments
```

Parse the body. The relevant sections are delimited by bold headings:

- `**This release contains changes from the following pull requests:**` — App PRs
- `**Mobile-Expensify PRs:**` — Mobile-Expensify PRs
- `**Deploy Blockers:**` — deploy blocker issues

Each item is `- [ ] URL` (unchecked) or `- [x] URL` (checked). Extract the unchecked items from each section. Ignore everything inside `<details>` blocks (chronological PR list) and the `Deployer verifications:` section — those are for the deployer, not relevant to blocker triage.

The unchecked **blockers** get deep analysis (see Step 3). The unchecked **PRs** only need a lightweight check (see Step 2a).

### Step 2a — Find unchecked PRs that QA has flagged in checklist comments

QA frequently leaves comments on the deploy checklist itself when an unchecked PR needs something — clarification, repro details, blocked on a question, etc. Surface these so the chore owner can chase them.

For each unchecked PR/Mobile-Expensify PR URL, scan **every comment** on the deploy checklist (the `comments` field you already fetched) and check if the comment text mentions:

- The PR number with `#` prefix (e.g., `#89673`)
- The PR's full URL (e.g., `https://github.com/Expensify/App/pull/89673`)
- The PR's URL path (`Expensify/App/pull/89673`)

A naive substring match on the digits alone is too noisy (numbers collide with blocker IDs, dates, etc.) — require one of the prefixed forms above.

For each match, capture:

- The PR URL/number
- The comment author and timestamp
- A short excerpt (~200 chars) of the comment around the mention, so the chore owner has context without clicking through
- The comment URL (so they can click through if they want)

This is plain text matching against the comments you already have — **no subagent needed** for this step. Skip an unchecked PR entirely if it isn't mentioned in any comment.

## Step 3 — Dispatch one subagent per unchecked blocker (in parallel)

For each unchecked blocker URL, spawn an Agent (subagent_type `general-purpose`) **in a single message** so they run concurrently. Use this prompt template, filling in the blocker URL:

> You are analyzing one Expensify deploy blocker to determine its current state. The blocker is here: `<URL>`. The blocker is currently unchecked on a `StagingDeployCash` deploy checklist, meaning the deploy chore owner needs to know what (if anything) to do about it.
>
> **Read-only — do not post comments, do not edit anything.**
>
> Gather data with these `gh` commands (run in parallel):
>
> ```bash
> gh issue view <NUMBER> --repo Expensify/App --json title,state,labels,assignees,body,closedAt
> gh issue view <NUMBER> --repo Expensify/App --comments --json comments
> gh api repos/Expensify/App/issues/<NUMBER>/timeline --paginate -H "Accept: application/vnd.github.mockingbird-preview+json"
> ```
>
> The timeline call surfaces cross-references (linked PRs, mentions). For any PR linked from the blocker (in the body, comments, or timeline), check its state:
>
> ```bash
> gh pr view <PR_NUMBER> --repo Expensify/App --json state,isDraft,mergedAt,merged,title,url
> ```
>
> Then classify the blocker into exactly **one** of these statuses and explain the recommended action.
>
> Status taxonomy (use these exact labels):
>
> - `NO_ACTIVITY` — Issue is new or stalled with no engineering engagement. Recommend: ping the assignee.
> - `INVESTIGATING` — Engineer is engaged, proposal/comments exist, but no fix PR yet. Recommend: wait, optionally note time since last activity.
> - `FIX_IN_REVIEW` — A fix PR is linked and is open (not merged). Recommend: wait for the fix to merge.
> - `NEEDS_CP` — A fix PR has been merged to `main` but there's no evidence it has been cherry-picked to `staging`. Recommend: cherry-pick to staging.
> - `NEEDS_QA` — Fix has been cherry-picked to staging (look for comments like "CP'd to staging", "cherry-picked", PR with `CP Staging` label, or the GitHub Actions cherry-pick bot) but QA hasn't confirmed it. Recommend: ask QA to validate.
> - `RESOLVED` — QA has confirmed the fix works (look for explicit confirmation comments from the Applause/QA team), OR the issue has been demoted/closed. Recommend: this can be checked off the deploy checklist.
> - `NEEDS_HUMAN` — Anything else: contradictory signals, unusual flow, demoted-but-not-closed, etc. Recommend: explain why the chore owner should look at it directly.
>
> Distinguishing `NEEDS_CP` vs `NEEDS_QA` is the most common mistake. A PR being merged to `main` is **not** the same as cherry-picked to `staging`. Look for explicit signals of cherry-picking (commit on the staging branch, a separate "CP" PR, the cherry-pick bot, or a comment from the engineer confirming the CP).
>
> Return a strict format:
>
> ```
> STATUS: <one of the labels above>
> TITLE: <issue title, truncated to ~80 chars>
> ASSIGNEE: <github login or "unassigned">
> SUMMARY: <one or two sentences on the current state, mentioning linked PR numbers if any>
> ACTION: <one sentence — exactly what the chore owner should do next, or "none">
> LAST_ACTIVITY: <ISO date of most recent comment or event>
> ```
>
> Keep the entire response under 200 words.

### Practical guidance for spawning

- Send **one message** with N `Agent` tool uses (one per blocker) so they run in parallel. Don't loop sequentially.
- If there are more than ~15 unchecked blockers, batch in groups of 15 to keep the parent context manageable.
- Use `subagent_type: "general-purpose"`.
- Each subagent's response is small (~200 words), so the cost is bounded.

## Step 4 — Aggregate and render the report

Collect every subagent response. Render in this order:

### Blockers — group by `STATUS`

Action-first, then waiting-on-others, then resolved:

1. **🚨 Needs your attention** — `NEEDS_HUMAN`, `NO_ACTIVITY`
2. **🍒 Ready to cherry-pick** — `NEEDS_CP`
3. **🧪 Ready for QA validation** — `NEEDS_QA`
4. **☑️ Can be checked off** — `RESOLVED`
5. **⏳ Waiting** — `FIX_IN_REVIEW`, `INVESTIGATING`

For each blocker show:

- Issue link as `[#NUMBER — title](url)` (use the descriptive-title-with-number form per CLAUDE.md)
- Assignee
- One-line summary
- Recommended action (skip for `RESOLVED` / `WAITING` if the action is "none")
- Last activity (relative — "3h ago", "2d ago")

### PRs flagged in checklist comments

Render this section only if Step 2a found any matches. Title it **💬 Unchecked PRs mentioned in comments**. For each flagged PR show:

- PR link as `[#NUMBER — title](url)` (fetch the PR title with `gh pr view` if you don't already have it)
- Who mentioned it and when (relative time)
- The comment excerpt
- The comment URL

Skip unchecked PRs that aren't mentioned in comments — they're just routine pending QA work.

### Header summary

End the report with a one-line **header summary**:

```
Checklist: <title> — <U>/<T> PRs unchecked (<F> flagged) · <BU>/<BT> blockers unchecked · <COUNTS by status>
```

E.g. `5/53 PRs unchecked (2 flagged) · 8/9 blockers unchecked · 2 need CP · 1 needs QA · 4 waiting · 1 needs attention`.

## Things to remember

- **Never post anything to GitHub.** No comments, no edits, no checkbox toggles. Read-only.
- **Don't re-derive things you already see.** The checklist body has the canonical list of unchecked items; don't try to infer from PR labels.
- **Trust the user to act.** Recommend actions; don't try to perform them.
- **Loop-friendly:** when invoked via `/loop`, output the report and stop. The next iteration will re-fetch fresh data.
- **No deep PR-by-PR analysis** — for unchecked PRs, only surface the ones QA mentioned in checklist comments (Step 2a). Routine pending QA work doesn't belong in the report.
