function revert --description 'Revert a PR'
    argparse 'no-new-branch' 'no-edit' -- $argv
    set -l prNumber $argv[1]

    if set -q _flag_no_new_branch
        set revertBranchName (git rev-parse --abbrev-ref HEAD)
    else
        set revertBranchName (whoami)"-revert-$prNumber"
    end

    if test "$revertBranchName" = "main"
        echo "Cannot revert PRs on the main branch"
        return 1
    end

    echo "Reverting PR $prNumber on branch $revertBranchName"

    # Create the revert branch if we're not on it
    if test (git rev-parse --abbrev-ref HEAD) != $revertBranchName
        git checkout main 2>/dev/null
        git checkout -b $revertBranchName
    end

    # Get the merge commit's hash
    set -l mergeCommit (gh pr view $prNumber --json mergeCommit -q .mergeCommit.oid)

    if test -z $mergeCommit
        echo "PR $prNumber does not exist or has not been merged yet"
        return 1
    end

    git revert $_flag_no_edit -m 1 $mergeCommit
end

complete -c revert -l no-new-branch -d 'Create the revert commit on the current branch'
complete -c revert -l no-edit -d 'Do not use the commit message editor'
complete -c revert -f -a "(git log --merges --oneline | head -50 | rg -o 'Merge pull request #(\\d+)' -r '\$1')"
