function nipp --description '"npm i and better patch-package" - Run `npm i` and propose to delete Node modules that make patch-package fail'
    set npm_output (npm i | tee /dev/tty)
    set bad_packages (echo $npm_output | rg -o -e 'Failed to apply patch for package (\S+) at path' -e 'The patches for (\S+) have changed' -r '$1' | sed -e 's/\x1b\[[0-9;]*m//g')

    if test -z "$bad_packages"
        return
    end

    echo
    set_color magenta
    echo "The following react_native packages might need to be deleted:"
    set_color normal
    for p in $bad_packages
        echo "💩> " $p
    end

    set_color blue
    read_confirm "Do you want to delete these packages?"
    set choice $status
    set_color normal
    if test $choice -eq 0
        for p in $bad_packages
            echo "Deleting node_modules/$p"
            rm -rf "node_modules/$p"
        end
    end
end
