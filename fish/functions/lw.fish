function lw --description 'Watch logs on remote servers, then notify'
    if test (count $argv) -eq 0
        echo "Usage: lw <param1> [param2] [param3] ..."
        echo "Watch syslog for lines containing any of the parameters followed by 'Job complete'"
        return 1
    end

    set -l regex (string join '|' $argv)
    set -l match_count (count $argv)

    set -l ssh_command "tail -F /var/log/syslog | grep -m$match_count --line-buffered -E \"($regex).*Job complete\$\"; exit"
    set -l logCommand "ssh log1 '$ssh_command'; _fl_notify 'Done'"

    echo $logCommand
    eval $logCommand
end
