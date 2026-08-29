#!/opt/homebrew/bin/fish
# Script to symlink dotfiles config files to their proper locations
# This script is idempotent and can be safely run multiple times

set DOTFILES_DIR ~/code/dotfiles

# Targets that were left alone because they exist and differ from the repo.
# Reported as a group at the end so a skip can't scroll past unnoticed.
set -g skipped_targets

# Returns 0 when source and target hold the same contents (handles both files
# and directory trees). A type mismatch is never "the same".
function _same_contents
    set -l source $argv[1]
    set -l target $argv[2]

    if test -d "$source"; and test -d "$target"
        diff -rq "$source" "$target" >/dev/null 2>&1
        return $status
    else if test -f "$source"; and test -f "$target"
        cmp -s "$source" "$target"
        return $status
    end

    return 1
end

# Function to safely create a symlink.
#
# Never overwrites a real file or directory whose contents differ from the repo
# copy — a drifted config is skipped with a warning instead. This used to back
# up and replace unconditionally, which silently swapped live fish and kitty
# configs for stale repo versions. Reconciling drift is a judgement call, so the
# script reports it rather than guessing.
function safe_symlink
    set -l source $argv[1]
    set -l target $argv[2]

    if test -L "$target"
        # A symlink holds no contents of its own, so re-pointing a stale one is
        # lossless. Don't report it as correct when it points somewhere else.
        set -l current (readlink "$target")
        if test "$current" = "$source"
            echo "✓ $target already symlinked"
            return
        end
        echo "⚠ $target pointed at $current, re-pointing"
        rm "$target"
    else if test -e "$target"
        if _same_contents "$source" "$target"
            # Byte-identical to a copy that lives in git, so replacing it with
            # a symlink loses nothing and needs no backup.
            echo "✓ $target matches the repo copy, converting to a symlink"
            rm -rf "$target"
        else
            echo "✗ SKIPPED $target — exists and differs from the repo copy"
            echo "    diff -r $target $source"
            set -g skipped_targets $skipped_targets $target
            return 1
        end
    end

    ln -s "$source" "$target"
    echo "✓ Created symlink: $target -> $source"
end

echo "Setting up dotfiles symlinks..."
echo ""

# Create necessary config directories
mkdir -p ~/.config/wezterm
mkdir -p ~/.config/ghostty
mkdir -p ~/.config/fish
mkdir -p ~/.config/nvim/lua/config
mkdir -p ~/.config/kitty
mkdir -p ~/.hammerspoon
mkdir -p ~/.claude
mkdir -p ~/.config/uv
mkdir -p ~/.config/opencode/commands
mkdir -p ~/.config/opencode/plugins/lib

# Symlink terminal configs
safe_symlink $DOTFILES_DIR/wezterm/wezterm.lua ~/.config/wezterm/wezterm.lua
safe_symlink $DOTFILES_DIR/ghostty/config ~/.config/ghostty/config
safe_symlink $DOTFILES_DIR/starship/starship.toml ~/.config/starship.toml

# Symlink Fish shell config
safe_symlink $DOTFILES_DIR/fish/config.fish ~/.config/fish/config.fish
safe_symlink $DOTFILES_DIR/fish/fish_plugins ~/.config/fish/fish_plugins
safe_symlink $DOTFILES_DIR/fish/functions ~/.config/fish/functions
safe_symlink $DOTFILES_DIR/fish/conf.d ~/.config/fish/conf.d

# Symlink Neovim config
safe_symlink $DOTFILES_DIR/nvim/lua/config/options.lua ~/.config/nvim/lua/config/options.lua

# Symlink Git config
safe_symlink $DOTFILES_DIR/git/.gitconfig ~/.gitconfig

# Symlink Ripgrep config
safe_symlink $DOTFILES_DIR/ripgreprc ~/.ripgrepc

# Symlink Hammerspoon config
safe_symlink $DOTFILES_DIR/hammerspoon/init.lua ~/.hammerspoon/init.lua

# Symlink Kitty config
safe_symlink $DOTFILES_DIR/kitty/kitty.conf ~/.config/kitty/kitty.conf
safe_symlink $DOTFILES_DIR/kitty/font-nerd-symbols.conf ~/.config/kitty/font-nerd-symbols.conf

# Symlink Vim config
safe_symlink $DOTFILES_DIR/vim/.vimrc ~/.vimrc

# Symlink uv config
safe_symlink $DOTFILES_DIR/uv/uv.toml ~/.config/uv/uv.toml

# Symlink Claude Code config
safe_symlink $DOTFILES_DIR/claude/settings.json ~/.claude/settings.json
safe_symlink $DOTFILES_DIR/claude/statusline.sh ~/.claude/statusline.sh
safe_symlink $DOTFILES_DIR/claude/CLAUDE.md ~/.claude/CLAUDE.md
safe_symlink $DOTFILES_DIR/claude/RTK.md ~/.claude/RTK.md
safe_symlink $DOTFILES_DIR/claude/git-conventions.md ~/.claude/git-conventions.md

# Symlink the whole output-styles dir — every style in it is ours, so new ones
# get picked up (and backed up) without touching this script.
safe_symlink $DOTFILES_DIR/claude/output-styles ~/.claude/output-styles

# Skills are symlinked individually: ~/.claude/skills also holds skills that
# don't live in this repo, so linking the whole dir would hide them.
mkdir -p ~/.claude/skills
for skill in (find $DOTFILES_DIR/claude/skills -mindepth 1 -maxdepth 1 -type d)
    safe_symlink $skill ~/.claude/skills/(basename $skill)
end

# Symlink OpenCode config individually so local package dependencies remain
# available without being committed or clobbered by the dotfiles repository.
safe_symlink $DOTFILES_DIR/opencode/opencode.jsonc ~/.config/opencode/opencode.jsonc
safe_symlink $DOTFILES_DIR/opencode/commands/crit.md ~/.config/opencode/commands/crit.md
safe_symlink $DOTFILES_DIR/opencode/plugins/crit.ts ~/.config/opencode/plugins/crit.ts
safe_symlink $DOTFILES_DIR/opencode/plugins/rtk.ts ~/.config/opencode/plugins/rtk.ts
safe_symlink $DOTFILES_DIR/opencode/plugins/lib/crit-wait-notify.js ~/.config/opencode/plugins/lib/crit-wait-notify.js

# Symlink worktime CLI into ~/.local/bin (already on PATH)
mkdir -p ~/.local/bin
safe_symlink $DOTFILES_DIR/misc/worktime/worktime ~/.local/bin/worktime

# Symlink worktime fish completions (individual file — symlinking the whole
# completions/ dir would clobber plugin-installed completions).
mkdir -p ~/.config/fish/completions
safe_symlink $DOTFILES_DIR/fish/completions/worktime.fish ~/.config/fish/completions/worktime.fish

# Set up worktime log directory and cron job. tick.sh only logs a timestamp
# when the user has interacted with the machine in the past 2 minutes — without
# that check the log captures uptime rather than activity (idle laptop counts
# as work).
mkdir -p ~/.worktime
set worktime_cron_marker 'worktime/tick.sh'
# Invoke via /bin/sh explicitly — macOS cron's default PATH is /usr/bin:/bin
# only, but otherwise this is just defensive and doesn't change behavior.
set worktime_cron_line "*/2 * * * * /bin/sh $DOTFILES_DIR/misc/worktime/tick.sh"
if crontab -l 2>/dev/null | grep -qF $worktime_cron_marker
    echo "✓ worktime cron job already installed"
else
    begin
        crontab -l 2>/dev/null
        echo $worktime_cron_line
    end | crontab -
    echo "✓ Installed worktime cron job"
end

echo ""
if test (count $skipped_targets) -gt 0
    echo "⚠ Left "(count $skipped_targets)" target(s) untouched because they differ from the repo:"
    for target in $skipped_targets
        echo "    $target"
    end
    echo ""
    echo "  Nothing was lost. Reconcile each one by hand: copy the local changes"
    echo "  into the repo, or delete the local file to accept the repo version."
    echo ""
end
echo "✓ Config file symlinks complete!"
