
# iTerm 2 shell integration
# test -e {$HOME}/.iterm2_shell_integration.fish ; and source {$HOME}/.iterm2_shell_integration.fish

status --is-interactive; and source (rbenv init -|psub)

# Go path
set -x GOPATH $HOME/go
set -x GOROOT /usr/local/opt/go/libexec

# PATH modifications (Go, Python 3)
set -g fish_user_paths /usr/local/opt/curl/bin $GOPATH/bin $GOROOT/bin /usr/local/opt/python/libexec/bin $fish_user_paths
# Hack, don't try this at home
set -g fish_user_paths /Users/francois/.nvm/versions/node/v14.10.0/bin $fish_user_paths

# auto path for cd command
set -x CDPATH . ~/ ~/Expensidev/ ~/code

if command -v pyenv 1>/dev/null 2>&1;
  pyenv init - | source;
end

# Theme modifications
### Enable nerd fonts for bobthefish
set -g theme_nerd_fonts yes
### Colors
set fish_color_search_match --background='343434'

# Ruby brew link
# export RUBY_CONFIGURE_OPTS="--with-openssl-dir="(brew --prefix openssl@1.1)
