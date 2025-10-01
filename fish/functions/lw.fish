function lw --description 'Watch logs on remote servers, then notify'
    argparse 's/server=' -- $argv
    or return

    if test (count $argv) -eq 0
        echo "Usage: lw [-s|--server=<server>] <param1> [param2] [param3] ..."
        echo "Watch syslog for lines containing any of the parameters followed by 'Job complete'"
        echo "Server defaults to log1 if not specified"
        return 1
    end

    set -l server $_flag_server
    if test -z "$server"
        set server log1
    end

    set -l regex (string join '|' $argv)
    set -l match_count (count $argv)

    set -l ssh_command "tail -F /var/log/syslog | grep -m$match_count --line-buffered -E \"($regex).*Job complete\$\"; exit"
    set -l logCommand "ssh $server '$ssh_command'; _fl_notify 'Done' 'All jobs completed'"

    echo $logCommand
    eval $logCommand
end

complete -c lw -s s -l server -d 'Remote log server to connect to' -x
