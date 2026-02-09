# PATH modifications
fish_add_path /opt/homebrew/opt/curl/bin
fish_add_path /usr/local/bin ~/.rbenv/shims ~/.pyenv/shims
fish_add_path -p $HOME/.local/bin

# Android SDK
set -x ANDROID_HOME $HOME/Library/Android/sdk/
fish_add_path $ANDROID_HOME/emulator $ANDROID_HOME/platform-tools $ANDROID_HOME/tools $ANDROID_HOME/tools/bin

# Set default node version (fast-nvm-fish)
nvm use 20.19.5 >/dev/null

# auto path for cd command
set -x CDPATH . ~/ ~/Expensidev/ ~/code

if command -v pyenv 1>/dev/null 2>&1;
  pyenv init - | source;
end

### Colors
set fish_color_search_match --background='343434'
### Read the default timezone to avoid using UTC in fish_right_prompt
set -g theme_date_timezone (ls -l /etc/localtime | cut -d"/" -f8,9)

set -x RUBY_CONFIGURE_OPTS "--with-openssl-dir="(brew --prefix openssl@1.1)

### Reusable global for the extra CF certs (exports, bootstrap)
set -g EXTRA_CERTS $HOME/Expensidev/Ops-Configs/src/saltfab/cacert.pem
### Node export for scripts
set -x NODE_EXTRA_CA_CERTS $EXTRA_CERTS
set -x AWS_CA_BUNDLE $EXTRA_CERTS
set -x SSL_CERT_FILE $EXTRA_CERTS
set -x CURL_CA_BUNDLE $EXTRA_CERTS
set -x BUNDLE_SSL_CA_CERT $EXTRA_CERTS
set -x REQUESTS_CA_BUNDLE $EXTRA_CERTS

set -gx EDITOR nvim
set -gx RIPGREP_CONFIG_PATH ~/.ripgreprc

# Interactive shell init
if status is-interactive
    source (rbenv init - | psub)

    # Auto-change node version on cd
    _load_nvm
end

# Added by Antigravity
fish_add_path /Users/francois/.antigravity/antigravity/bin
