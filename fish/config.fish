# iTerm 2 shell integration
# test -e {$HOME}/.iterm2_shell_integration.fish ; and source {$HOME}/.iterm2_shell_integration.fish

# Path to the local dotfile repo. Used to source stuff
set -l dotfile_config_path ~/code/dotfiles/fish/

#set -x GOPATH $HOME/go
#set -x GOROOT /usr/local/opt/go/libexec

# PATH modifications (Go, Python 3)
fish_add_path /usr/local/opt/curl/bin $GOPATH/bin $GOROOT/bin /usr/local/opt/python/libexec/bin
# fish_add_path /usr/local/bin /opt/homebrew/bin ~/.rbenv/shims ~/.pyenv/shims
fish_add_path /usr/local/bin ~/.rbenv/shims ~/.pyenv/shims

# Set default node version (fast-nvm-fish recommended)
nvm use 14.21.1 >/dev/null

# auto path for cd command
set -x CDPATH . ~/ ~/Expensidev/ ~/code

if command -v pyenv 1>/dev/null 2>&1;
  pyenv init - | source;
end

# Theme modifications
### Change bobthefish theme color set (bobthefish_display_colors --all)
set theme_color_scheme nord
### Enable nerd fonts for bobthefish
set -g theme_nerd_fonts yes
set -g theme_display_git_untracked no

### Colors
set fish_color_search_match --background='343434'
### Read the default timezone to avoid using UTC in fish_right_prompt
set -g theme_date_timezone (ls -l /etc/localtime | cut -d"/" -f8,9)

# Android SDK
fish_add_path $HOME/Library/Android/sdk/emulator $HOME/Library/Android/sdk/platform-tools

set -x RUBY_CONFIGURE_OPTS "--with-openssl-dir="(brew --prefix openssl@1.1)

# Interactive shell init
if status is-interactive
    source (rbenv init -|psub)

    # Auto-change node version on cd
    _load_nvm

    # Load fish abbreviations
    test -e $dotfile_config_path/abbr.fish; and source $dotfile_config_path/abbr.fish
end
