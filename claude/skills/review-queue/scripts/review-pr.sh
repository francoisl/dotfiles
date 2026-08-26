#!/usr/bin/env bash
# Review one PR in a throwaway git worktree at the PR's head, then classify the
# result into a compact verdict.
#
# Usage: review-pr.sh <repo-name> <pr-number> <out-dir> [level]
#
# Writes:
#   <out-dir>/<repo>-<pr>.md        full review report
#   <out-dir>/<repo>-<pr>.err       stderr from the review
#   <out-dir>/<repo>-<pr>.verdict   compact verdict block (ALWAYS written)
#
# Always exits 0 and always writes a .verdict, so one bad PR can neither sink
# the batch nor silently vanish from the aggregate report.
#
# Why two passes: /code-review carries its own output-format instructions and
# ignores an appended "emit a verdict block" instruction -- and its shape varies
# run to run (raw findings JSON one time, prose the next). So the verdict is
# produced by a separate cheap classifier pass over the finished report.

set -uo pipefail

REPO_NAME="${1:?usage: review-pr.sh <repo-name> <pr-number> <out-dir> [level]}"
PR="${2:?missing pr number}"
OUT_DIR="${3:?missing out dir}"
LEVEL="${4:-medium}"

CLONE_ROOT="${RQ_CLONE_ROOT:-$HOME/Expensidev}"
CLONE="$CLONE_ROOT/$REPO_NAME"
TIMEOUT="${RQ_TIMEOUT:-1200}"
CLASSIFY_TIMEOUT="${RQ_CLASSIFY_TIMEOUT:-300}"
CLASSIFY_MODEL="${RQ_CLASSIFY_MODEL:-haiku}"

mkdir -p "$OUT_DIR"
OUT="$OUT_DIR/${REPO_NAME}-${PR}.md"
ERR="$OUT_DIR/${REPO_NAME}-${PR}.err"
VERDICT="$OUT_DIR/${REPO_NAME}-${PR}.verdict"

# Per-PR ref: concurrent runs against the same clone must not race on
# FETCH_HEAD, which is shared repo-wide.
REF="refs/review-queue/pr-${PR}"
WT="$(mktemp -u -d "${TMPDIR:-/tmp}/rq-${REPO_NAME}-${PR}-XXXXXX")"

cleanup() {
    git -C "$CLONE" worktree remove --force "$WT" >/dev/null 2>&1 || rm -rf "$WT"
    git -C "$CLONE" update-ref -d "$REF" >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

bail() {
    cat >"$VERDICT" <<EOF
PR: ${REPO_NAME}#${PR}
VERDICT: NEEDS_HUMAN
BLOCKING: 0
TOTAL: 0
ONE_LINER: $1
TOP: none
REPORT: $OUT
EOF
    exit 0
}

[ -d "$CLONE/.git" ] || bail "No local clone at $CLONE, so the review never ran."

git -C "$CLONE" fetch origin "pull/${PR}/head:${REF}" --force --quiet 2>>"$ERR" \
    || bail "Could not fetch pull/${PR}/head from ${REPO_NAME}."

SHA="$(git -C "$CLONE" rev-parse "$REF" 2>>"$ERR")" \
    || bail "Could not resolve ${REF} in ${REPO_NAME}."

# git serialises worktree admin with a lock; retry when several reviews of the
# same repo start at once.
added=""
for _ in 1 2 3 4 5; do
    if git -C "$CLONE" worktree add --detach "$WT" "$SHA" >/dev/null 2>>"$ERR"; then
        added="yes"
        break
    fi
    sleep 2
done
[ -n "$added" ] || bail "Could not create a worktree for ${REPO_NAME}#${PR} at ${SHA:0:12}."

cd "$WT" || bail "Could not enter worktree ${WT}."

# ---- Pass 1: the actual review, at the PR's head, in an isolated worktree ----
timeout "$TIMEOUT" claude -p "/code-review $LEVEL $PR" \
    --permission-mode dontAsk \
    --output-format text \
    --strict-mcp-config \
    --disallowed-tools Edit Write NotebookEdit \
    </dev/null >"$OUT" 2>>"$ERR"
rc=$?

[ "$rc" -eq 124 ] && bail "Review timed out after ${TIMEOUT}s; too large for auto-triage."
[ -s "$OUT" ] || bail "Review exited ${rc} with no output; see ${ERR}."

# The review cites paths inside the throwaway worktree, which is deleted before
# the user ever reads the report. Rewrite them to repo-relative. Both the
# /var/... and resolved /private/var/... forms show up on macOS.
WT_REAL="$(cd "$WT" && pwd -P 2>/dev/null || echo "$WT")"
sed -i '' -e "s|${WT_REAL}/||g" -e "s|${WT}/||g" "$OUT" 2>/dev/null || true

# Startup warnings can land on stdout; keep them out of the classifier's input.
CLEAN="$OUT_DIR/.${REPO_NAME}-${PR}.clean"
grep -v -e '^Permission allow rule' -e '^Warning: no stdin data' "$OUT" >"$CLEAN"
# If filtering left nothing, the report was warnings only -- classify the raw
# output rather than handing the classifier an empty report.
[ -s "$CLEAN" ] || cp "$OUT" "$CLEAN"

# ---- Pass 2: classify the report into a verdict ----
{
    cat <<EOF
You are classifying a completed code review of ${REPO_NAME}#${PR} as part of a
batch triage of a pull-request review queue. The user is deciding which PRs they
can merge right now and which need their attention.

Read the report below and output ONLY the following block. No preamble, no code
fence, nothing after it.

VERDICT: <READY_TO_MERGE | MINOR_NITS | NEEDS_CHANGES | NEEDS_HUMAN>
BLOCKING: <integer count of findings that should block the merge>
TOTAL: <integer count of all findings>
ONE_LINER: <one sentence, max 25 words, on whether this is safe to merge and why>
TOP: <up to 3 findings as "path:line - short issue", joined by " | ", or "none">

VERDICT rules:
  READY_TO_MERGE - no findings, or only trivial nits with no behavioural risk.
  MINOR_NITS     - real findings, but none affect correctness, security or data integrity.
  NEEDS_CHANGES  - at least one genuine correctness, security, data-loss or regression bug.
  NEEDS_HUMAN    - the report is inconclusive, or the change is too domain-specific to judge.

Be calibrated: a false READY_TO_MERGE costs the user far more than a false
NEEDS_CHANGES, but inflating nits into blockers defeats the triage. Make
ONE_LINER decision-useful -- say what the risk is, not that a review happened.

---REPORT---
EOF
    cat "$CLEAN"
} >"$OUT_DIR/.${REPO_NAME}-${PR}.prompt"

raw="$(timeout "$CLASSIFY_TIMEOUT" claude -p \
    --model "$CLASSIFY_MODEL" \
    --permission-mode dontAsk \
    --output-format text \
    --strict-mcp-config \
    <"$OUT_DIR/.${REPO_NAME}-${PR}.prompt" 2>>"$ERR")"

rm -f "$CLEAN" "$OUT_DIR/.${REPO_NAME}-${PR}.prompt"

# Tolerant extraction: the classifier reliably emits the fields but often drops
# the surrounding fence lines, so key off the field names instead.
body="$(printf '%s\n' "$raw" | grep -E '^(VERDICT|BLOCKING|TOTAL|ONE_LINER|TOP):')"

if [ -z "$body" ] || ! printf '%s' "$body" | grep -q '^VERDICT:'; then
    bail "Review completed but could not be classified; read the report at ${OUT}."
fi

{
    echo "PR: ${REPO_NAME}#${PR}"
    printf '%s\n' "$body"
    echo "REPORT: $OUT"
} >"$VERDICT"

exit 0
