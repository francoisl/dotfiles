#!/bin/bash
NOTIFY_FILE="$HOME/Expensidev/.host-notify"

/opt/homebrew/bin/fswatch -o "$NOTIFY_FILE" | while read event; do
  msg=$(cat "$NOTIFY_FILE" 2>/dev/null)
  if [ -n "$msg" ]; then
      /opt/homebrew/bin/terminal-notifier -title "Dev VM" -message "$msg"
  fi
done
