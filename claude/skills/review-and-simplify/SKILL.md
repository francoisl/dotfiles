---
name: review-and-simplify
description: Run an AI code review on a PR (via /code-review-ai:ai-review), summarize findings, then run /simplify to clean up the code, and summarize the changes. Use when the user wants a two-pass review-then-simplify workflow on a pull request.
---

# Review and Simplify

A two-pass workflow that runs an AI code review on a PR and then simplifies the changed code, summarizing the results between each pass.

## When to use

The user wants to both audit a PR for quality/security/performance issues **and** then clean up the code for simplicity in a single command. The argument passed to this skill is the PR identifier (e.g., a PR number, URL, or branch reference) that gets forwarded to the review step.

## How to execute

Run these steps **sequentially** — each step depends on the previous one completing.

### Step 1: Run the AI review

Invoke the `code-review-ai:ai-review` skill via the Skill tool, passing through the user's argument (the PR identifier) as the skill's `args`. Wait for it to complete before continuing.

### Step 2: Summarize the review findings

After the review completes, output a **brief** summary (5-10 lines max) that captures:

- Total issues found, grouped by severity (CRITICAL / HIGH / MEDIUM / LOW)
- The 3-5 most important findings, each as a one-line bullet with file:line and category
- Anything blocking (e.g., security/correctness issues that should be fixed before merge)

Keep this tight — the goal is a scannable triage, not a full report. Skip restating what the review tool already printed in detail.

### Step 3: Run /simplify

Invoke the `simplify` skill via the Skill tool with no arguments (or pass through any simplify-relevant scope if the user specified one). This will review the changed code for reuse, quality, and efficiency, and apply fixes.

### Step 4: Summarize what simplify changed

After `simplify` completes, output a **brief** summary of what it actually changed:

- Files modified and the kind of change in each (e.g., "removed unused helper", "inlined single-use variable", "deduplicated branch")
- Any items `simplify` flagged but did NOT change (and why — e.g., needed user judgment)
- Net effect: lines added/removed if available, or a one-line qualitative read

If `simplify` made no changes, say so in one line.

## Output shape

The full skill output should look roughly like:

```
## AI Review Findings
<brief summary from Step 2>

## Simplify Changes
<brief summary from Step 4>
```

Do not re-print the full review report or the full simplify output — both already streamed during their own runs. This skill's job is to chain the two and add a tight summary at each handoff.

## Notes

- If Step 1 fails (e.g., PR not found, review tool errors), report the failure and stop — do not proceed to `simplify`.
- If `simplify` makes changes the user hasn't approved being persisted, follow `simplify`'s own conventions for confirming/applying edits — don't override them here.
- Treat the user's argument as opaque; pass it through to `ai-review` verbatim rather than parsing it.
