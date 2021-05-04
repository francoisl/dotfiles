function mainBranch
    git branch | grep -q " master" && echo master; or echo main
end
