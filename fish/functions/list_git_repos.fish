function list_git_repos --description 'List dirs at the current path that are top-level git repos'
    for dir in (fd -I --type d --maxdepth 1)
        if git -C $dir rev-parse --is-inside-work-tree >/dev/null 2>&1
            # Ensures we're not in a sub-dir of a repo - faster than doing a pushd and checking the --show-toplevel against `realpath`
            and test -d $dir/.git
            git -C $dir config --get remote.origin.url | string replace -ra '.*:|\.git' ''
        end
    end
end
