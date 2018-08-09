# Path to Oh My Fish install.
set -gx OMF_PATH "/Users/francois/.local/share/omf"

# Customize Oh My Fish configuration path.
#set -gx OMF_CONFIG "/Users/francois/.config/omf"

# Load oh-my-fish configuration.
source $OMF_PATH/init.fish

# Go source
set -x GOPATH $HOME/go
set -x GOROOT /usr/local/opt/go/libexec
set PATH $GOPATH/bin $GOROOT/bin $PATH

# Aliases
alias cat ccat
alias ocat /bin/cat
