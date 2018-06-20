function git-clean-branches --description 'Delete branches that are merged, except master, and optionally prune'
    git branch --merged master | grep -v master | xargs -n 1 git branch -d
    # prune unreachable local and remote objects?
    if contains -- --prune $argv
        git prune --progress
        git remote prune origin
    end
end
