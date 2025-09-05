# Make fish the default shell
echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish

# Set up config files
mkdir -p ~/.config/wezterm
mkdir ~/.hammerspoon
ln -s ~/code/dotfiles/wezterm/wezterm.lua ~/.config/wezterm/wezterm.lua
ln -s ~/code/dotfiles/hammerspoon/init.lua ~/.hammerspoon/init.lua
ln -s ~/code/dotfiles/nvim/lua/config/options.lua ~/.config/nvim/lua/config/options.lua

# MacOS modifications
# Disable screenshot shadow
defaults write com.apple.screencapture "disable-shadow" -bool "true"

