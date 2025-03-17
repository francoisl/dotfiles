# Make fish the default shell
echo /usr/local/bin/fish | sudo tee -a /etc/shells
chsh -s /usr/local/bin/fish

# Set up config files
mkdir -p ~/.config/wezterm
mkdir ~/.hammerspoon
ln -s ~/code/dotfiles/wezterm/wezterm.lua ~/.config/wezterm/wezterm.lua
ln -s ~/code/dotfiles/hammerspoon/init.lua ~/.hammerspoon/init.lua
