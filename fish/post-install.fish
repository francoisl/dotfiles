# Permanently add /usr/local/bin to the PATH
set -U fish_user_paths /usr/local/bin $fish_user_paths

# Install fisher
echo "Installing fisher"
curl https://git.io/fisher --create-dirs -sLo ~/.config/fish/functions/fisher.fish

# Install common fisher plugins
echo "Installing fisher plugins"
fisher add edc/bass
fisher add FabioAntunes/fish-nvm
