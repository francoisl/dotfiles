function ff --description '(Fuzzy) find file'
	fd --type f | fzf --preview 'wc {} && echo "================" && cat {}'
end
