# Make fish the default shell
echo /usr/local/bin/fish | sudo tee -a /etc/shells
chsh -s /usr/local/bin/fish

# Restore some OMF configs
ln -s ~/code/dotfiles/omf/key_bindings.fish ~/.config/omf/key_bindings.fish
