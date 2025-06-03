function wmerge
    argparse 'r/repo=' -- $argv
    argparse --min-args=1 -- $argv
    or begin
        echo "Missing argument: PR number"
        echo "Usage: "(status current-command)" [-r|--repo <org/repo>] <prNumber>"
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

    if not test $err = 0
        echo -e "\n❌ Failed to check PR status"
        return $err
    end

    echo -e "\n🚀 Checks passed"
    set -l mergeCommand gh pr merge $prNumber
    if set -ql _flag_repo
        set -a mergeCommand --repo $_flag_repo
    end
    set -a mergeCommand -m --auto

    echo "Merging command - $mergeCommand"
    #command $mergeCommand
    #and echo -e "\n✅ PR $prNumber merged successfully"
    #or echo -e "\n❌ Failed to merge PR $prNumber"
end

