function fssh -d "Fuzzy-find a SSH host via ripgrep and SSH into it"
    rg -N -o 'Host (.*)' ~/.ssh/config -r '$1' | rg '[^*]' | tr ' ' "\n" | fzf | read -l result; and ssh "$result"
end
