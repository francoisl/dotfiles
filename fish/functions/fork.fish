function fork --description Fork\ a\ Git\ branch\ from\ another\ user\'s\ GitHub\ repo
    set --local branch (echo $argv[1] | cut -d: -f2)
    set --local user_name (echo $argv[1] | cut -d: -f1)
    set --local repoName (basename (git rev-parse --show-toplevel))
    git remote add $user_name git@github.com:$user_name/$repoName.git
    git fetch $user_name
    git checkout $user_name/$branch
end
