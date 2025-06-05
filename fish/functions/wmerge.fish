# Use the `gh` CLI tool to watch checks on a pull request, and merge when tests pass
function wmerge
    argparse 'r/repo=' 'w/watch-only' -- $argv
    argparse --min-args=1 -- $argv
    or begin
        echo "Missing argument: PR number"
        echo "Usage: "(status current-command)" [-r|--repo <org/repo>] [-w|--watch-only] <prNumber>"
        return 1
    end

    if set -ql _flag_repo
        echo "Using repo $_flag_repo"
    end

    set -l prNumber $argv[1]

    set -l watchCommand gh pr checks $prNumber
    if set -ql _flag_repo
        set -a watchCommand --repo $_flag_repo
    end
    set -a watchCommand --watch --fail-fast -i 4

    echo "👀 Checking PR status - $watchCommand"
    command $watchCommand
    set -l err $status

    # Beep a few times to notify checks are done
    for i in (seq 3); echo -n \a; sleep 0.1; end

    if not test $err = 0
        echo -e "\n❌ Failed to check PR status"
        return $err
    end

    echo -e "\n🚀 Checks passed"
    if not set -ql _flag_watch_only
        set -l mergeCommand gh pr merge $prNumber
        if set -ql _flag_repo
            set -a mergeCommand --repo $_flag_repo
        end
        set -a mergeCommand -m

        echo "Merging command - $mergeCommand"
        command $mergeCommand
        and echo -e "\n✅ PR $prNumber merged successfully"
        or echo -e "\n❌ Failed to merge PR $prNumber"
    end
end


complete -c wmerge -f -s w -l watch-only -d "Watch only, don't merge"

# Completion for `-r`/`--repo` - lists available git repos as options, and pipes into fzf for convenience
if functions -q list_git_repos; and command -q fzf
    complete -c wmerge -s r -l repo -r -f -a "(list_git_repos | fzf | cat)" -d "Which repo the PR belongs to"
end
