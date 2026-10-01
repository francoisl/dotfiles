---
name: review-queue
description: Drain your GitHub code-review backlog and open a browser summary grouped by PR. Finds PRs waiting on your review, skips those that aren't your turn, runs /code-review or an optional named review skill in isolated worktrees in parallel, and shows verdicts, findings, full reports, and saved handled checkboxes. Read-only. Use when asked to review, triage, clear, or drain a PR review queue. Pair with /loop for periodic sweeps.
---

# Review Queue

Turn the user's "PRs waiting on me" list into a ranked set of verdicts, so the
small, clean PRs can be approved and merged immediately instead of sitting in the
backlog. Open the results in a browser, with one card per PR and an expandable
full review. Handled checkboxes track which results the user has acted on.

**Read-only.** Never post a review, comment, approval, or label. Never push. The
skill reports; the user acts.

## Arguments

All optional; the skill works with no arguments.

- **A number** (`/review-queue 10`) — review that many PRs this run. Default `6`.
  Pass it as `--limit` to `fetch-queue.py`.
- **A level** (`/review-queue high`) — review depth, one of
  `low|medium|high|max`. Default `medium`: fewer, higher-confidence findings,
  which is what the default `/code-review` uses for triage. Pass it as the second
  argument to `run-batch.sh`. For `ce-code-review`, `high` or `max` forces the
  full review workflow; `low` or `medium` lets CE choose its own depth. Other
  skills use their own defaults.
- **A review skill** (`/review-queue ce-code-review` or
  `/review-queue 3 high ce-code-review`) — use that skill for every PR this run.
  Default `code-review`; selecting another skill does not change future runs.
  Also accept `--review-skill <name>` or natural wording such as “using ce-code-review”.
  Pass it to `run-batch.sh` as `--review-skill <name>` after the level and before
  the repo/PR pairs. Skill names may include a plugin prefix, such as
  `compound-engineering:ce-code-review`, and an optional leading `/`.
  Resolve the name against the skills available to the headless Claude runner;
  plugin skills must be installed and enabled there. The installed CE skill is
  `ce-code-review` (singular); resolve “ce-code-reviews” to it. Never silently
  substitute the default when the requested skill is unavailable.
- **A repo name** (`/review-queue Integration-Server`) — restrict to one repo via
  `--repo`.
- **Browser output is the default.** “Terminal only” or “without opening” passes
  `--no-open` to the browser renderer. At the start of the run, check whether the
  stable latest report already exists. If it does, use `--no-open` unless the
  user asks to open it. Check before Step 2 creates the report so the first run
  still opens a tab. The existing tab updates automatically. Under `/loop`, open
  the first report only; generate later reports without new tabs.
- **“Open the last report”** — open `~/.local/share/review-queue/index.html`
  without fetching GitHub or starting new reviews. Say it contains saved results.
- **PR URLs** — skip Step 1 entirely and pass those PRs straight to Step 2,
  ignoring the skip rules. Derive the repo from the URL path. For a bare PR
  number with no repo, resolve it against the queue from Step 1; if it isn't
  there, ask which repo rather than guessing.

## Step 1 — Build the queue

Choose a unique `<out-dir>` under the shell tool's approved temporary directory.
Check that parent with `ls` before generating files. Use this same directory in
every step so the queue metadata and reviews stay together.

```bash
python3 <skill-dir>/scripts/fetch-queue.py --limit <N> [--repo <name>] --output <out-dir>/queue.json
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

If `review` is empty, skip Step 2 and go to Step 3. The browser report still
shows skipped, deferred, and failed metadata lookups.

## Step 2 — Run the reviews in parallel

Pass every selected PR to the batch driver as `<repo> <number>` pairs:

```bash
<skill-dir>/scripts/run-batch.sh <out-dir> medium \
  Integration-Server 9254 \
  Web-Expensify 55605 \
  IS-Templates 5924
```

For a full-depth CE review, for example:

```bash
<skill-dir>/scripts/run-batch.sh <out-dir> high --review-skill ce-code-review \
  Integration-Server 9254 \
  Web-Expensify 55605
```

**Run this in the background if the shell tool supports it.** A single PR takes
roughly 4 minutes and can take much longer on a big repo, so any real batch will
blow past a short foreground timeout. With a foreground-only tool, pass an
explicit 24-hour tool timeout (`86400000` milliseconds) and wait for completion.
It runs 3 reviews concurrently (`RQ_JOBS` to
change that) and prints every verdict at the end.

Each PR's review is self-contained: it fetches the PR head into a per-PR ref,
creates a detached git worktree at that commit, runs the selected review skill in a
headless `claude -p`, classifies the report into a verdict, and removes the
worktree. It always exits 0 and always writes a `.verdict`, so a single failure
cannot sink the batch or silently drop a PR.

The default invocation stays `/code-review <level> <PR>`. Other skills receive
the full PR URL and read-only review instructions. `ce-code-review` uses Claude's
`/compound-engineering:ce-code-review` command with `mode:agent`; `high` and `max`
also pass `depth:full`. Each verdict records `REVIEW_SKILL`. A failed review is
`NEEDS_HUMAN`, including failures that emit a report before exiting.

Why a worktree: the user's clones normally sit on unrelated feature branches with
uncommitted work. Reviewing in place would feed the review that WIP as
"surrounding context". The worktree gives it the PR's actual code and leaves the
user's working tree untouched.

While the batch runs, do not poll in a tight loop. Wait for the background task
to report completion, or for the foreground command to finish. The batch writes
the browser report automatically without opening a tab; Step 3 opens it on the
first run or reuses the existing tab.

## Step 3 — Report

Run the renderer to open the per-PR browser summary:

```bash
python3 <skill-dir>/scripts/render-report.py <out-dir>
```

Use `--no-open` for terminal-only requests, refreshes in an existing tab, or
later `/loop` iterations. The stable latest report is
`~/.local/share/review-queue/index.html`, and each batch keeps `<out-dir>/index.html`.
Relay the file link printed by the renderer so the user can bookmark it.

The latest report checks for regenerated results every 30 seconds while visible,
when the window gains focus, and when you return to the tab. It updates in place,
preserving filters, handled checks, collapsed cards, and open unchanged reviews.
Batch archives stay fixed. An older open tab needs one reload to load this behavior.

The renderer reads verdicts and full `.md` reports directly from disk.
**Do not read full reports into model context** unless the user asks about a
specific PR. Read the small verdict files only when needed for a terminal summary.

The page groups each PR's title, author, diff size, verdict, one-line summary,
top findings, and expandable full review in one card. It also includes:

- Verdict and search filters, a sidebar linking to each PR, and a hide-handled filter.
- Handled checkboxes saved in browser storage for this batch. They don't post a
  GitHub review. A changed verdict or full report starts unchecked.
- A collapse toggle on each card, plus Expand all and Collapse all. A collapsed
  card keeps its verdict, title, author, diff size, and Handled checkbox visible. Collapsed state
  saves per batch; a changed review starts expanded, and the sidebar expands the
  card it jumps to.
- Skipped, deferred, and metadata-error cards with their reasons.
- Saved review timestamps and queue-capture timestamps, clearly distinct from
  live GitHub status. Missing or invalid verdicts become `NEEDS_HUMAN`.
- An “Updated” time in the header: the newest queue-capture or review-saved time,
  in local time, with how long ago that was. Re-rendering doesn't change it.
- File links to the original full reports. Where a verdict records the reviewed
  commit, finding locations link to that exact commit on GitHub.
- Corrected results: `<repo>-<N>.corrected.verdict` takes precedence over the
  original verdict for the same PR, with a visible “Corrected review” marker.

**Keep the terminal response short:** the browser link, the counts below, and
any review failures or blocking findings that need immediate attention. Put the
full PR-by-PR breakdown in the browser unless the user asks for terminal details.

End with a one-line summary, including metadata errors when present:

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
- **Saved results only.** Rendering or reopening a batch does not fetch GitHub
  or run another review. For explicit PR URLs, `targets.txt` and verdicts are
  sufficient; absent queue metadata, cards use repository/PR identifiers.
- **Local output.** Generated HTML, its sibling `.refresh.js`, and `queue.json`
  contain private review data. Keep them outside the public dotfiles repo. The checked-in `report.html` is
  only a template. Keep the latest HTML and `.refresh.js` together for automatic
  updates. The HTML still displays its saved results without the companion file.
  The renderer needs Python 3.9+ and uses no external assets.
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

## Verification

Run the report and review-driver regression tests with Python's standard library:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 <skill-dir>/scripts/test-report.py
```

The driver tests stub Git and Claude. They check the default command, skill
selection across a batch, CE depth arguments, read-only prompts, invalid names,
and review failures without running paid AI reviews or fetching real PRs.

The browser test needs an installed Playwright module and an existing temporary parent:

```bash
node <skill-dir>/scripts/test-report-browser.mjs /path/to/playwright/index.mjs /existing/temp/directory
```

It checks the update time, per-PR grouping, safe full-review rendering, commit links, filtering,
collapsing, saved checkboxes and collapsed cards, automatic updates in an existing tab,
and resetting progress when a review changes.
