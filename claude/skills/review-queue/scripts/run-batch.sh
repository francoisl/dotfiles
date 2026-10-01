#!/usr/bin/env bash
# Review a batch of PRs concurrently.
#
# Usage: run-batch.sh <out-dir> <level> [--review-skill <name>] <repo> <number> [...]
#
# Writes one .md / .err / .verdict trio per PR into <out-dir>, plus a
# targets.txt record of what was asked for and a browser summary. Prints a short
# progress line per PR as it finishes. Exits 0 unless the arguments were malformed.

set -uo pipefail

OUT_DIR="${1:?usage: run-batch.sh <out-dir> <level> [--review-skill <name>] <repo> <number> [...]}"
LEVEL="${2:?missing level}"
shift 2

REVIEW_SKILL="code-review"
if [ "${1:-}" = "--review-skill" ]; then
    [ "$#" -ge 2 ] && [ -n "${2:-}" ] || { echo "--review-skill needs a skill name" >&2; exit 2; }
    REVIEW_SKILL="${2#/}"
    shift 2
fi
[[ "$REVIEW_SKILL" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*(:[A-Za-z0-9][A-Za-z0-9_-]*)?$ ]] \
    || { echo "invalid review skill name: $REVIEW_SKILL" >&2; exit 2; }

[ "$#" -ge 2 ] || { echo "need at least one <repo> <number> pair" >&2; exit 2; }
[ $(( $# % 2 )) -eq 0 ] || { echo "uneven <repo> <number> pairs: $*" >&2; exit 2; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JOBS="${RQ_JOBS:-3}"

mkdir -p "$OUT_DIR"
: >"$OUT_DIR/targets.txt"
while [ "$#" -ge 2 ]; do
    printf '%s %s\n' "$1" "$2" >>"$OUT_DIR/targets.txt"
    shift 2
done

count="$(wc -l <"$OUT_DIR/targets.txt" | tr -d ' ')"
echo "Reviewing $count PR(s) with /$REVIEW_SKILL at level '$LEVEL', $JOBS at a time -> $OUT_DIR"

# -L 1 feeds one "repo number" line per invocation, appended after the fixed
# args: $0=script $1=out-dir $2=level $3=skill $4=repo $5=number.
# BSD xargs (macOS) has no -a, so the list comes in on stdin.
xargs -P "$JOBS" -L 1 \
    sh -c '"$0" "$4" "$5" "$1" "$2" "$3"; printf "  done %s#%s\n" "$4" "$5"' \
    "$HERE/review-pr.sh" "$OUT_DIR" "$LEVEL" "$REVIEW_SKILL" <"$OUT_DIR/targets.txt" 2>&1 \
    | grep -v -e '^Permission allow rule' -e '^Warning: no stdin data'

echo "--- verdicts ---"
cat "$OUT_DIR"/*.verdict 2>/dev/null || echo "(no verdicts written)"

if ! python3 "$HERE/render-report.py" "$OUT_DIR" --no-open; then
    printf '%s\n' "Browser report generation failed; the verdicts and full reviews are still in $OUT_DIR." >&2
fi
