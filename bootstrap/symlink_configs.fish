#!/opt/homebrew/bin/fish
# Script to symlink dotfiles config files to their proper locations
# This script is idempotent and can be safely run multiple times

set DOTFILES_DIR ~/code/dotfiles

# Function to safely create a symlink
function safe_symlink
    set -l source $argv[1]
    set -l target $argv[2]

    if test -L "$target"
        echo "✓ $target already symlinked"
        return
    else if test -e "$target"
        echo "⚠ $target already exists (not a symlink), backing up to $target.backup"
        mv "$target" "$target.backup"
    end

    ln -s "$source" "$target"
    echo "✓ Created symlink: $target -> $source"
end

echo "Setting up dotfiles symlinks..."
echo ""

# Create necessary config directories
mkdir -p ~/.config/wezterm
mkdir -p ~/.config/ghostty
mkdir -p ~/.config/fish
mkdir -p ~/.config/nvim/lua/config
mkdir -p ~/.config/kitty
mkdir -p ~/.hammerspoon

# Symlink terminal configs
safe_symlink $DOTFILES_DIR/wezterm/wezterm.lua ~/.config/wezterm/wezterm.lua
safe_symlink $DOTFILES_DIR/ghostty/config ~/.config/ghostty/config

# Symlink Fish shell config
safe_symlink $DOTFILES_DIR/fish/config.fish ~/.config/fish/config.fish
safe_symlink $DOTFILES_DIR/fish/fish_plugins ~/.config/fish/fish_plugins
safe_symlink $DOTFILES_DIR/fish/functions ~/.config/fish/functions
safe_symlink $DOTFILES_DIR/fish/conf.d ~/.config/fish/conf.d

# Symlink Neovim config
safe_symlink $DOTFILES_DIR/nvim/lua/config/options.lua ~/.config/nvim/lua/config/options.lua

# Symlink Git config
safe_symlink $DOTFILES_DIR/git/.gitconfig ~/.gitconfig

# Symlink Ripgrep config
safe_symlink $DOTFILES_DIR/ripgreprc ~/.ripgrepc

# Symlink Hammerspoon config
safe_symlink $DOTFILES_DIR/hammerspoon/init.lua ~/.hammerspoon/init.lua

# Symlink Kitty config
safe_symlink $DOTFILES_DIR/kitty/kitty.conf ~/.config/kitty/kitty.conf
safe_symlink $DOTFILES_DIR/kitty/font-nerd-symbols.conf ~/.config/kitty/font-nerd-symbols.conf

# Symlink Vim config
safe_symlink $DOTFILES_DIR/vim/.vimrc ~/.vimrc

echo ""
echo "✓ Config file symlinks complete!"
