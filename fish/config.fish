# PATH modifications
fish_add_path /opt/homebrew/opt/curl/bin
fish_add_path /usr/local/bin ~/.rbenv/shims ~/.pyenv/shims

# Android SDK
set -x ANDROID_HOME $HOME/Library/Android/sdk/
fish_add_path $ANDROID_HOME/emulator $ANDROID_HOME/platform-tools $ANDROID_HOME/tools $ANDROID_HOME/tools/bin

# Set default node version (fast-nvm-fish)
nvm use 20.10.0 >/dev/null

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

set -x RUBY_CONFIGURE_OPTS "--with-openssl-dir="(brew --prefix openssl@1.1)

### Reusable global for the extra CF certs (exports, bootstrap)
set -g EXTRA_CERTS $HOME/Expensidev/Ops-Configs/saltfab/cacert.pem
### Node export for scripts
set -x NODE_EXTRA_CA_CERTS $EXTRA_CERTS

# Interactive shell init
if status is-interactive
    source (rbenv init - | psub)

    # Auto-change node version on cd
    _load_nvm
end
