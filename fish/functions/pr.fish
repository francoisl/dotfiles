function pr --description 'Open GitHub on the page to create a PR from the current branch'
	set -l branch (command git branch | sed -n -e "s/^\* \(.*\)/\1/p")
    set -l repo (command git remote -v show | sed -E 's/.*:Expensify\/(.*)\.git .*/\1/' | head -n 1)
    echo "https://github.com/Expensify/$repo/pull/new/$branch?expand=1"
    open "https://github.com/Expensify/$repo/pull/new/$branch?expand=1"
end
