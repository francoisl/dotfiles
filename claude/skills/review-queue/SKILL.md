---
name: review-queue
description: Drain your GitHub code-review backlog. Finds the PRs waiting on your review across Expensify repos, skips the ones that aren't your turn (drafts, [HOLD], red CI, conflicts), runs a real /code-review on the cheapest ones in isolated git worktrees in parallel, and reports one verdict per PR so you can see at a glance which are ready to merge. Read-only. Use when the user wants to triage, clear, or drain their PR review queue or review backlog. Pair with `/loop` for periodic sweeps.
---

# Review Queue

Turn the user's "PRs waiting on me" list into a ranked set of verdicts, so the
small, clean PRs can be approved and merged immediately instead of sitting in the
backlog.

**Read-only.** Never post a review, comment, approval, or label. Never push. The
skill reports; the user acts.

## Arguments

All optional; the skill works with no arguments.

- **A number** (`/review-queue 10`) — review that many PRs this run. Default `6`.
  Pass it as `--limit` to `fetch-queue.py`.
- **A level** (`/review-queue high`) — review depth, one of
  `low|medium|high|max`. Default `medium`: fewer, higher-confidence findings,
  which is what triage wants. Pass it as the second argument to `run-batch.sh`.
- **A repo name** (`/review-queue Integration-Server`) — restrict to one repo via
  `--repo`.
- **PR URLs** — skip Step 1 entirely and pass those PRs straight to Step 2,
  ignoring the skip rules. Derive the repo from the URL path. For a bare PR
  number with no repo, resolve it against the queue from Step 1; if it isn't
  there, ask which repo rather than guessing.

## Step 1 — Build the queue

```bash
python3 <skill-dir>/scripts/fetch-queue.py --limit <N> [--repo <name>]
```

Prints JSON with four buckets:

- `review` — the `N` cheapest reviewable PRs, smallest churn first
- `deferred` — reviewable, but over this run's limit
- `skipped` — each with a `reason` (not the user's turn, or not reviewable)
- `errors` — PRs whose metadata could not be fetched

It skips, in priority order: drafts → `[HOLD` in the title → the user already
approved or already requested changes → merge conflicts → genuinely failing code
CI → no local clone.

**Do not re-derive any of this.** The script already resolved the user's login,
CI state, and review history. Read its output and move on.

Two things worth knowing about the output:

- `ci_gates_ignored` lists failing checks that gate on *"has a human reviewed
  this yet"* rather than code health — Expensify's `Verify peer review / Check
  independent approval` fails on **every** unreviewed PR. These are deliberately
  not treated as CI failure; if they were, the whole queue would be skipped.
  Don't report them as problems.
- Ranking is by churn ascending, but churn is only a cost proxy, **not** a
  difficulty proxy. A 700-line mechanical test conversion is easier to clear than
  a 120-line refactor of initialisation order. Use churn to pick what to spend
  reviews on; use the verdict, never the size, to decide what's mergeable.

If `review` is empty, say so, show the skip reasons, and stop.

## Step 2 — Run the reviews in parallel

Pass every selected PR to the batch driver as `<repo> <number>` pairs:

```bash
<skill-dir>/scripts/run-batch.sh /tmp/review-queue-$(date +%Y%m%d-%H%M%S) medium \
  Integration-Server 9254 \
  Web-Expensify 55605 \
  IS-Templates 5924
```

**Run this in the background** (`run_in_background: true`). A single PR takes
roughly 4 minutes and can take much longer on a big repo, so any real batch will
blow past a foreground timeout. It runs 3 reviews concurrently (`RQ_JOBS` to
change that) and prints every verdict at the end.

Each PR's review is self-contained: it fetches the PR head into a per-PR ref,
creates a detached git worktree at that commit, runs `/code-review` there in a
headless `claude -p`, classifies the report into a verdict, and removes the
worktree. It always exits 0 and always writes a `.verdict`, so a single failure
cannot sink the batch or silently drop a PR.

Why a worktree: the user's clones normally sit on unrelated feature branches with
uncommitted work. Reviewing in place would feed the review that WIP as
"surrounding context". The worktree gives it the PR's actual code and leaves the
user's working tree untouched.

While the batch runs, do not poll in a tight loop. Wait for the background task
to report completion.

## Step 3 — Report

Read only the verdict files — they are a few lines each:

```bash
cat <out-dir>/*.verdict
```

**Do not read the full `.md` reports into context** unless the user asks about a
specific PR. That's the whole point of the verdict files; a full report can run
to 16KB. File paths in both the verdicts and the reports are repo-relative, so
they're still meaningful after the worktree is gone.

Group by verdict, most-actionable first:

1. **✅ Ready to merge** (`READY_TO_MERGE`) — the payoff. These are the ones the
   user can approve and merge now.
2. **🟡 Minor nits only** (`MINOR_NITS`) — mergeable; mention the nits so the
   user can decide whether to bother.
3. **🔴 Needs changes** (`NEEDS_CHANGES`) — real bugs found. Lead with the
   blocking finding.
4. **🤔 Needs your judgement** (`NEEDS_HUMAN`) — includes PRs whose review
   failed outright; say which, and why.

For each PR show:

- `[<repo>#<number> — title](url)` as a link
- author, churn (`+/-` lines), file count
- the `ONE_LINER`
- the `TOP` findings, one per line, for anything not `READY_TO_MERGE`
- the path to the full report

Then a **⏭️ Skipped** section (one line each: PR link + reason), and a
**📋 Not reviewed this run** section listing `deferred` PRs with their sizes, so
the cap is never silent.

End with a one-line summary:

```
<T> awaiting review · <R> reviewed · <A> ready to merge · <N> need changes · <S> skipped · <D> deferred
```

## Notes

- **Read-only, always.** Even when a verdict is `READY_TO_MERGE`, do not approve
  it. Report it and let the user click.
- **Trust the verdict, report the uncertainty.** If a verdict is `NEEDS_HUMAN`
  because the review failed, say that plainly rather than dressing it up as a
  finding.
- A `READY_TO_MERGE` verdict means *the review found nothing blocking* — not that
  the PR is correct. Don't oversell it.
- **Cost.** Each PR costs two headless `claude` sessions (a full review plus a
  cheap classifier). Reviewing 6 PRs is a real spend; don't quietly raise the
  limit, and don't re-review PRs already covered earlier in the conversation.
- **Loop-friendly.** Under `/loop`, report and stop; the next iteration re-fetches
  fresh state. Nothing is cached between runs.
- **Nothing is left behind.** Each review removes its worktree and its
  `refs/review-queue/pr-<N>` ref on exit, including on failure or timeout. If a
  run is killed hard, `git -C <clone> worktree prune` and
  `git -C <clone> for-each-ref refs/review-queue/` will show any stragglers.
- Env overrides: `RQ_OWNER` (default `Expensify`), `RQ_CLONE_ROOT` (default
  `~/Expensidev`), `RQ_JOBS` (concurrent reviews, default 3), `RQ_TIMEOUT`
  (per-review seconds, default 1200), `RQ_CLASSIFY_MODEL` (default `haiku`),
  `RQ_CI_IGNORE` (regex of review-gate check names to not count as CI failure).
