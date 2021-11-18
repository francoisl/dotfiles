function fssh -d "Fuzzy-find a SSH host via ripgrep and SSH into it"
    rg -No 'Host (.*)' ~/.ssh/config -r '$1' | rg -v '\*' | tr ' ' "\n" | fzf | read -l result; and ssh "$result"
end
