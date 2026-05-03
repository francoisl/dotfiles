#!/bin/sh
# Worktime tick — append a UTC timestamp to ~/.worktime/log if the user is
# actively working. Run every 2 minutes by cron.
#
# Rules:
#   - Always require recent input (HIDIdleTime < 15 min).
#   - If the screen is locked, additionally require continuity: the previous
#     tick must be within the last 15 minutes. This prevents phantom ticks
#     from spurious overnight wake events that briefly reset HIDIdleTime
#     while the laptop is locked but no one is using it.
#
# Use absolute paths — cron's PATH (/usr/bin:/bin) doesn't include /usr/sbin
# where ioreg lives, so a bare `ioreg` call would silently fail.

IDLE_THRESHOLD_SEC=900       # 15 min — covers thinking, meetings, hallway chats
LOCK_CONTINUITY_SEC=900      # 15 min — when locked, last tick must be this fresh

LOG_FILE="$HOME/.worktime/log"

# 1. Recent input?
idle_ns=$(/usr/sbin/ioreg -c IOHIDSystem 2>/dev/null | /usr/bin/awk '/HIDIdleTime/ {print $NF; exit}')
[ -n "$idle_ns" ] || exit 0
idle_sec=$(( idle_ns / 1000000000 ))
[ "$idle_sec" -lt "$IDLE_THRESHOLD_SEC" ] || exit 0

# 2. If locked, last tick must be recent (continuity check).
locked=$(/usr/sbin/ioreg -n Root -d 1 2>/dev/null | /usr/bin/awk '/IOConsoleLocked/ {print $NF; exit}')
if [ "$locked" = "Yes" ]; then
    last_tick=$(/usr/bin/tail -1 "$LOG_FILE" 2>/dev/null)
    [ -n "$last_tick" ] || exit 0
    last_epoch=$(/bin/date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$last_tick" +%s 2>/dev/null)
    [ -n "$last_epoch" ] || exit 0
    now_epoch=$(/bin/date -u +%s)
    [ $(( now_epoch - last_epoch )) -le "$LOCK_CONTINUITY_SEC" ] || exit 0
fi

mkdir -p "$HOME/.worktime"
/bin/date -u +"%Y-%m-%dT%H:%M:%SZ" >> "$LOG_FILE"
