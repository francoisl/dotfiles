function wmerge
    argparse 'r/repo=' -- $argv
    argparse --min-args=1 -- $argv
    or begin
        echo "Missing argument: PR number"
        return
    end

    if set -ql _flag_repo
        echo "Using repo $_flag_repo"
    end

    set -l prNumber $argv[1]

    set -l watchCommand gh pr checks $prNumber
    if set -ql _flag_repo
        set -a watchCommand --repo $_flag_repo
    end
    set -a watchCommand --watch

    echo "👀 Checking PR status - $watchCommand"
    command $watchCommand
    or begin
        echo "Error checking PR status : $status"
        return 1
    end

    set mergeCommand gh pr merge $prNumber
    if set -ql _flag_repo
        set -a mergeCommand --repo $_flag_repo
    end

    echo ""
    echo "🚀 Checks passed, merging PR - $mergeCommand"
    command $mergeCommand
    and echo -e "\n✅ PR $prNumber merged successfully"
    or echo -e "\n❌ Failed to merge PR $prNumber"
    return $status
end

# Completion for `-r`/`--repo` - lists available git repos as options, and pipes into fzf for convenience
complete -c wmerge -s r -l repo -r -f -a "(__list_git_repos | fzf | cat)"
