# Defined interactively
function pr --description 'Open GitHub on the page to create a PR from the current branch'
    set -l branch (command git branch | sed -n -e "s/^\* \(.*\)/\1/p")
    set -l remote (command git remote -v | grep origin | head -1 | awk '{print $2}' | sed 's/.*:\(.*\)*/\1/' | sed 's/\.git$//')
    open "https://github.com/$remote/pull/new/$branch?expand=1"
end
