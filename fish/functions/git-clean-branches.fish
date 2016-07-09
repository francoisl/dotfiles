function git-clean-branches --description 'Delete branches that are merged, except master'
    git branch --merged master | grep -v "master" | xargs -n 1 git branch -d
end
