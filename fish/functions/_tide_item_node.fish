function _tide_item_node
    if path is $_tide_parent_dirs/package.json
        nvm current | string match -qr "v(?<v>.*)"
        _tide_print_item node $tide_node_icon' ' $v
    end
end
