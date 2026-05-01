#!/bin/sh
# Worktime tick — append a UTC timestamp to ~/.worktime/log, but only if the
# user has interacted with the machine recently. Run every 2 minutes by cron.
# Activity is checked via macOS's `ioreg`
#
IDLE_THRESHOLD_SEC=900  # 15 minutes — covers thinking, meetings, hallway chats

# Use absolute paths — cron's default PATH (/usr/bin:/bin) doesn't include
# /usr/sbin where ioreg lives, so a bare `ioreg` call would silently fail.
idle_ns=$(/usr/sbin/ioreg -c IOHIDSystem 2>/dev/null | /usr/bin/awk '/HIDIdleTime/ {print $NF; exit}')
[ -n "$idle_ns" ] || exit 0  # ioreg unavailable; skip silently
idle_sec=$(( idle_ns / 1000000000 ))

if [ "$idle_sec" -lt "$IDLE_THRESHOLD_SEC" ]; then
    mkdir -p "$HOME/.worktime"
    /bin/date -u +"%Y-%m-%dT%H:%M:%SZ" >> "$HOME/.worktime/log"
fi
