# Permanently add /usr/local/bin to the PATH
set -U fish_user_paths /usr/local/bin $fish_user_paths

# Install fisher
echo "Installing fisher"
curl -sL https://git.io/fisher | source

# Install fisher and plugins
echo "Installing fisher plugins"
fisher update

# pyenv configs
echo "Setting up pyenv variables"
set -Ux PYENV_ROOT $HOME/.pyenv
set -Ux fish_user_paths $PYENV_ROOT/bin $fish_user_paths

# Install fzf completions and key bindings
echo "Installing fzf key bindings and completions"
set brewPrefix (brew --prefix)
$brewPrefix/opt/fzf/install

# Enable nord theme for bobthefish
set theme_color_scheme nord
