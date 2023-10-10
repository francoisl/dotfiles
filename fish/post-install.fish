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

# Tide config
### Default: pwd git newline character
set -U tide_left_prompt_items pwd git
set -U tide_right_prompt_items cmd_duration context jobs direnv node python java php ruby go terraform elixir time

### pwd item
set -e tide_pwd_icon
set -U tide_pwd_bg_color 454C5C

### git item
set -U tide_git_bg_color A8BD91
set -U tide_git_bg_color_unstable B3666C # C4A000
set -U tide_git_icon  # 
set -U tide_git_truncation_length 64 # 24

### ruby item
set -U tide_ruby_bg_color B30975 # B31209

# Backup icons btf
##      | 
