---
name: k2-web
description: Generate and open a browser-based K2 daily GitHub dashboard with persistent checkboxes. Use when asked for k2-web, an HTML K2 dashboard, or a browser checklist of assigned issues and pull requests.
---

# K2 Browser Dashboard

Generate a standalone HTML dashboard with the same GitHub queries and grouping as `k2`.

## Run

Run this command using the Bash tool:

```bash
python3 ~/.claude/skills/k2-web/dashboard.py
```

The script uses the authenticated `gh` user, runs the five GitHub searches concurrently,
writes `~/.local/share/k2-web/dashboard.html`, and opens it in the default browser.
The default output path stays fixed so browser checkbox state survives regeneration.

When the shell tool requires checking a directory before a command creates files,
first inspect `~/.local/share` (or the parent of a custom output path).

For a refresh without opening another tab:

```bash
python3 ~/.claude/skills/k2-web/dashboard.py --no-open
```

Then reload the existing browser tab. `--output /absolute/path/dashboard.html` selects
a custom file. Keep using the same path and browser to retain checkbox state.

## Behavior

- **PRs to review:** combine review-requested and reviewed-by searches, deduplicate,
  exclude the current user's own PRs, and sort by most recently updated.
- **Your issues:** group by Hourly, Daily, Weekly, Monthly, and No Priority; sort oldest first.
- **Your pull requests:** combine assigned and authored searches, deduplicate,
  and sort by most recently updated.
- Draft, hold, and Reviewing badges provide context. These lists don't check CI or review readiness.
- Checkboxes track work completed **today**, not permanent completion of a GitHub item.
  For example, checking a PR means today's review is done; it may need another review tomorrow.
- Checks save locally in the browser, scoped to the GitHub login and local calendar date.
  They reset each day. Returning to the same file in the same browser retains today's checks.
- Checked items remain in today's list when they disappear from a refreshed GitHub snapshot.
- Search and “hide completed” make the remaining work easier to find.
- GitHub data updates only when this script runs. Reopening or reloading the HTML doesn't fetch GitHub.
- Partial fetch failures appear in the dashboard. Total failure preserves the previous HTML file.
- The page needs no server, CDN, network connection, or runtime dependencies. Generation needs Python 3.9+ and `gh`.

## Response

After successful execution, give the user the printed file path/link, item counts,
and any fetch warnings. Keep the terminal summary short; the dashboard holds the full list.
Explain once that checkbox state is per day and saved in this browser.

## Verification

Run the Python regression tests:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 ~/.claude/skills/k2-web/test_dashboard.py
```

`test_browser.mjs` checks real browser persistence, regeneration, filtering, daily reset,
and safe rendering. Pass the path to an installed Playwright module and an existing
temporary parent directory:

```bash
node ~/.claude/skills/k2-web/test_browser.mjs /path/to/playwright/index.mjs /existing/temp/directory
```
