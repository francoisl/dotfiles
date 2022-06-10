
# iTerm 2 shell integration
# test -e {$HOME}/.iterm2_shell_integration.fish ; and source {$HOME}/.iterm2_shell_integration.fish

set -x GOPATH $HOME/go
set -x GOROOT /usr/local/opt/go/libexec

# PATH modifications (Go, Python 3)
set -g fish_user_paths /usr/local/opt/curl/bin $GOPATH/bin $GOROOT/bin /usr/local/opt/python/libexec/bin $fish_user_paths
fish_add_path /usr/local/opt/sqlite/bin

# Set default node version (fast-nvm-fish recommended)
nvm use 14.19.3

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

# Ruby brew link
# export RUBY_CONFIGURE_OPTS="--with-openssl-dir="(brew --prefix openssl@1.1)

# rbenv init. Must be on the last line
status --is-interactive; and source (rbenv init -|psub)
