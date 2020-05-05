alias vl='cd /var/log'
alias tl='tail -F /var/log/syslog | grep -v "performance\|_send\|_hp2_\|APC fetch host\|Possible hosts\|Reusing socket\|nginx:"'
alias tli='tl | fgrep Integration'
