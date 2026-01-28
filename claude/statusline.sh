#!/bin/bash
# Read JSON input from stdin
input=$(cat)

# Extract values using jq
MODEL_DISPLAY=$(echo "$input" | jq -r '.model.display_name')
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir')
COST=$(printf "%.4f" $(echo "$input" | jq -r '.cost.total_cost_usd'))
LINES_ADDDED=$(echo "$input" | jq -r '.cost.total_lines_added')
LINES_REMOVED=$(echo "$input" | jq -r '.cost.total_lines_removed')
PERCENT_USED=$(echo "$input" | jq -r '.context_window.used_percentage // 0')

# Show git branch if in a git repo
GIT_BRANCH=""
SUFFIX="|  ${COST}"
if git rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git branch --show-current 2>/dev/null)
    if [ -n "$BRANCH" ]; then
        GIT_BRANCH=" |  $BRANCH"
    fi
    SUFFIX+=" | 󰦒 ${LINES_ADDDED}/${LINES_REMOVED}"
fi

echo "󱚤 $MODEL_DISPLAY |  ${CURRENT_DIR##*/}$GIT_BRANCH $SUFFIX |  ${PERCENT_USED}%" | lolcat --force

