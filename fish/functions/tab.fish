function tab --description 'Tabulate data'
	sed -e 's/'\t'/ /g' | column -t
end
