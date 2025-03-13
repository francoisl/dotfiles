local wezterm = require 'wezterm'

local config = wezterm.config_builder()
local act = wezterm.action

-- Set fish as our default shell. Not needed after chsh
-- config.default_prog = { '/opt/homebrew/bin/fish', '-l' }

-- Set font, disable ligatures
config.font = wezterm.font 'JetBrains Mono'
config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }

-- Theme and color overrides
config.color_scheme = 'nordfox'
config.colors = {
    background = '#25242b',
    cursor_bg = '#8db3ba',
    cursor_fg = '#0b0f0f',
}
-- config.initial_cols = 212
-- config.initial_rows = 50

wezterm.on("gui-startup", function(cmd)
	local screen = wezterm.gui.screens().main
	local width_ratio = 0.95
    local height_ratio = 0.85
	local width, height = screen.width * width_ratio, screen.height * height_ratio
	local tab, pane, window = wezterm.mux.spawn_window(cmd or {
		position = { x = (screen.width - width) / 2, y = (screen.height - height) / 2 },
	})
	-- window:gui_window():maximize()
	window:gui_window():set_inner_size(width, height)
end)

config.window_background_opacity = 0.97

config.enable_scroll_bar = true

config.keys = {
  {
    key = 'k',
    mods = 'SUPER',
    action = act.Multiple {
      act.ClearScrollback 'ScrollbackAndViewport',
      act.SendKey { key = 'L', mods = 'CTRL' },
    },
  },
  {
    key = 'd',
    mods = 'SUPER',
    action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' },
  },
  {
    key = 'd',
    mods = 'SHIFT|SUPER',
    action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' },
  },
  {
    key = 'LeftArrow',
    mods = 'SUPER',
    action = act.ActivatePaneDirection 'Left',
  },
  {
    key = 'RightArrow',
    mods = 'SUPER',
    action = act.ActivatePaneDirection 'Right',
  },
  {
    key = 'UpArrow',
    mods = 'SUPER',
    action = act.ActivatePaneDirection 'Up',
  },
  {
    key = 'DownArrow',
    mods = 'SUPER',
    action = act.ActivatePaneDirection 'Down',
  },
  {
    key = '[',
    mods = 'SUPER',
    action = act.ActivatePaneDirection 'Prev',
  },
  {
    key = ']',
    mods = 'SUPER',
    action = act.ActivatePaneDirection 'Next',
  },
  {
    key = 'w',
    mods = 'CMD',
    action = act.CloseCurrentPane { confirm = true },
  },
  {
    key = 'f',
    mods = 'SUPER',
    action = act.Search { CaseInSensitiveString = '' },
  },
}


return config
