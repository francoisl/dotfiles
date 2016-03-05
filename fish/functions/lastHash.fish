function lastHash --description 'Display the hash of the last commit on the current branch. --short or -s options available'
    if begin contains -- --short $argv
        or contains -- -s $argv
    end
        git rev-parse HEAD | cut -c 1-8
    else
        git rev-parse HEAD
    end
end
