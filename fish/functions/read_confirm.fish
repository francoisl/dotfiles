function read_confirm --description 'Read user confirmation with customizable question'
	while true
        read -p 'echo $argv "[y/n]:"' -l confirm

        switch $confirm
            case Y y
                return 0
            case '' N n
                return 1
        end
    end
end
