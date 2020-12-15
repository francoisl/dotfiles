# Permanently add /usr/local/bin to the PATH
set -U fish_user_paths /usr/local/bin $fish_user_paths

# Install fisher
echo "Installing fisher"
curl -sL https://git.io/fisher | source

# Install fisher and plugins
echo "Installing fisher plugins"
fisher update

# pyenv configs
set -Ux PYENV_ROOT $HOME/.pyenv
set -Ux fish_user_paths $PYENV_ROOT/bin $fish_user_paths
