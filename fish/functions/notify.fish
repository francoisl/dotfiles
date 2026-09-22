function notify --description "Notify with the exit status of the previous command"
    # Capture the status first: any command below would overwrite it.
    set -l last_status $status

    if test (count $argv) -eq 0
        echo "notify: expected a message" >&2
        return 1
    end

    set -l message (string join ' ' $argv)

    # `someCommand; notify "msg"`: the previous command already finished, so
    # $status holds its exit code. Scripts always take this path: stdin there
    # is often not a terminal even without a pipe, and fish_postexec (used
    # below) only fires at the interactive prompt.
    if isatty stdin; or not status is-interactive
        __notify_send $last_status $message
        return $last_status
    end

    # `someCommand | notify "msg"`: we run at the same time as someCommand, so
    # its exit code doesn't exist yet. Pass its output through, then let a
    # one-time fish_postexec handler read $pipestatus once the line finishes.
    cat

    function __notify_postexec --on-event fish_postexec --inherit-variable message
        # Capture first: the next command would overwrite $pipestatus.
        set -l codes $pipestatus
        functions --erase __notify_postexec

        # The last entry is notify itself; the pipeline failed if any other
        # command did.
        set -l result 0
        for code in $codes[1..-2]
            if test $code -ne 0
                set result $code
                break
            end
        end

        __notify_send $result $message
    end
end

function __notify_send --argument-names code message
    if test $code -eq 0
        terminal-notifier -title "✅ $message" -message Succeeded -sound Pop
    else
        terminal-notifier -title "❌ Failed: $message" -message "Exited with status $code" -sound Funk
    end
end
