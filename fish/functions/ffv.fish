function ffv --description '(Fuzzy) find a file & open it in Vim'
	ff | read -l result
    and vim $result
end
