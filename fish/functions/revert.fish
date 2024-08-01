function revert
    set -l prNumber $argv[1]
    set -l revertBranchName (whoami)"-revert-$prNumber"

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
        exit 1
    end

    git revert -m 1 $mergeCommit
end
