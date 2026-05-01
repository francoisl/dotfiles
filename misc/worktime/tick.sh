#!/bin/sh
# Worktime tick — append a UTC timestamp to ~/.worktime/log, but only if the
# user has interacted with the machine recently. Run every 2 minutes by cron.
# Activity is checked via macOS's `ioreg`
#
IDLE_THRESHOLD_SEC=900  # 15 minutes — covers thinking, meetings, hallway chats

idle_ns=$(ioreg -c IOHIDSystem 2>/dev/null | awk '/HIDIdleTime/ {print $NF; exit}')
[ -n "$idle_ns" ] || exit 0  # ioreg unavailable; skip silently
idle_sec=$(( idle_ns / 1000000000 ))

if [ "$idle_sec" -lt "$IDLE_THRESHOLD_SEC" ]; then
    mkdir -p "$HOME/.worktime"
    date -u +"%Y-%m-%dT%H:%M:%SZ" >> "$HOME/.worktime/log"
fi
