function _fl_notify
    if test (count $argv) -eq 0
        echo "_fl_notify: expected a message" >&2
        return 1
    end

    if test (count $argv) -eq 1
        terminal-notifier -message "$argv[1]"
    else
        terminal-notifier -title "$argv[1]" -message "$argv[2]"
    end
end
