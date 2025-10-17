#!/opt/homebrew/bin/fish

# Make fish the default shell
echo /opt/homebrew/bin/fish | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/fish

# Symlink all config files
fish (dirname (status -f))/symlink_configs.fish

# MacOS modifications
# Disable screenshot shadow
defaults write com.apple.screencapture "disable-shadow" -bool "true"

echo ""
echo "✓ Post-install setup complete!"

