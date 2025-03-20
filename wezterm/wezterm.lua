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


config.window_decorations = "RESIZE"
-- The filled in variant of the < symbol
local SOLID_LEFT_ARROW = wezterm.nerdfonts.ple_left_half_circle_thick
-- pl_right_hard_divider

-- The filled in variant of the > symbol
local SOLID_RIGHT_ARROW = wezterm.nerdfonts.ple_right_half_circle_thick
-- pl_left_hard_divider

-- This function returns the suggested title for a tab.
-- It prefers the title that was set via `tab:set_title()`
-- or `wezterm cli set-tab-title`, but falls back to the
-- title of the active pane in that tab.
function tab_title(tab_info)
  local title = tab_info.tab_title
  -- if the tab title is explicitly set, take that
  if title and #title > 0 then
    return title
  end
  -- Otherwise, use the title from the active pane
  -- in that tab
  return tab_info.active_pane.title
end

wezterm.on(
  'format-tab-title',
  function(tab, tabs, panes, config, hover, max_width)
    local edge_background = '#25242b'
    local background = '#25242b'
    local foreground = '#BCBCBC'

    if tab.is_active then
      edge_background = '#2f5180'
      background = '#2f5180'
      foreground = '#E4E4E4'
    end

    local edge_foreground = background

    local title = tab_title(tab)

    -- ensure that the titles fit in the available space,
    -- and that we have room for the edges.
    -- title = wezterm.truncate_right(title, max_width - 2)

    return {
      { Background = { Color = edge_background } },
      { Foreground = { Color = edge_foreground } },
      { Text = SOLID_LEFT_ARROW },
      { Background = { Color = background } },
      { Foreground = { Color = foreground } },
      { Text = title },
      { Background = { Color = edge_background } },
      { Foreground = { Color = edge_foreground } },
      { Text = SOLID_RIGHT_ARROW },
    }
  end
)


-- config.window_background_image = '/Users/francois/Desktop/recordings/term.png'
config.window_background_image_hsb = {
  brightness = 0.05,
  hue = 1,
  saturation = 1,
}


config.window_background_opacity = 0.976
config.inactive_pane_hsb = {
  saturation = 0.6,
  brightness = 0.5,
}

wezterm.on('toggle-opacity', function(window, pane)
  local overrides = window:get_config_overrides() or {}
  if not overrides.window_background_opacity then
    overrides.window_background_opacity = 0.7
  else
    overrides.window_background_opacity = nil
  end
  window:set_config_overrides(overrides)
end)


config.enable_scroll_bar = true
config.scrollback_lines = 500000

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
  {
    key = 'u',
    mods = 'SUPER',
    action = act.EmitEvent 'toggle-opacity',
  },
}


return config
