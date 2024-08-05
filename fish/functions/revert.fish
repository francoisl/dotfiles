function revert --description 'Revert a PR'
    set -l prNumber $argv[1]
    set revertBranchName (git rev-parse --abbrev-ref HEAD)

    if not contains -- --no-new-branch $argv
        set revertBranchName (whoami)"-revert-$prNumber"
    end
    if test "$revertBranchName" = "main"
        echo "Cannot revert PRs on the main branch"
        return 1
    end

    echo "Reverting PR $prNumber on branch $revertBranchName"

    # Create the revert branch if we're not on it
    if test (git rev-parse --abbrev-ref HEAD) != $revertBranchName
        git checkout main
        git checkout -b $revertBranchName
    end

    # Get the merge commit's hash
    set -l mergeCommit (gh pr view $prNumber --json mergeCommit -q .mergeCommit.oid)

    if test -z $mergeCommit
        echo "PR $prNumber does not exist or has not been merged yet"
        return 1
    end

    git revert -m 1 $mergeCommit
end

complete -c revert -l no-new-branch -d 'Create the revert commit on the current branch'
