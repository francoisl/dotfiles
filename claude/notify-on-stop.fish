#!/usr/bin/env fish
# Use `terminal-notifier` to show a notification when Claude finishes or needs attention,
# if wezterm is not active, or if another tab/pane is active.
# Usage: notify-on-stop.fish [--needs-permission]

if contains -- --needs-permission $argv
    set message "Claude needs permission"
else
    set message "Claude is done"

    # The Stop hook also fires when the main loop parks itself waiting on
    # backgrounded subagents/workflows. Those always finish and trigger Stop
    # again, so stay quiet until none are left in flight. Deliberately ignores
    # other background task types (shell, monitor, ...) since those can run
    # forever and would suppress the notification for good.
    set pending (cat | jq '[.background_tasks[]? | select(.type == "subagent" or .type == "workflow")] | length' 2>/dev/null)
    if string match -qr '^[1-9]' -- "$pending"
        exit 0
    end
end

set frontmost (osascript -e 'tell application "System Events" to get name of first process whose frontmost is true')
set focused_pane (wezterm cli list-clients --format json | jq -r '.[0].focused_pane_id')

if test "$frontmost" != "wezterm-gui"
    # WezTerm not active - use WezTerm icon and sound
    terminal-notifier -message "$message" -title "Claude Code" -sound Bottle -sender com.github.wez.wezterm
else if test "$WEZTERM_PANE" != "$focused_pane"
    # WezTerm active but different pane focused - no sender to avoid suppression
    terminal-notifier -message "$message" -title "Claude Code"
end
