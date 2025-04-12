local wezterm = require 'wezterm'

local config = wezterm.config_builder()
local act = wezterm.action

-- Set fish as the default shell. Not needed after chsh
-- config.default_prog = { '/opt/homebrew/bin/fish', '-l' }

-- Set font, disable ligatures
config.font = wezterm.font 'JetBrains Mono'
config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }

-- ------------------------------------------------------------------------------------
-- General appearance
-- ------------------------------------------------------------------------------------
-- Theme and color overrides
config.color_scheme = 'tokyonight'
config.colors = {
    background = '#1a1b26',
    cursor_bg = '#8e91b1',
    cursor_fg = '#12131a',
}

config.enable_scroll_bar = true
config.scrollback_lines = 500000

-- Resize on startup
wezterm.on("gui-startup", function(cmd)
	local screen = wezterm.gui.screens().main
	local width_ratio = 0.95
    local height_ratio = 0.85
	local width, height = screen.width * width_ratio, screen.height * height_ratio
	local tab, pane, window = wezterm.mux.spawn_window(cmd or {
		position = { x = (screen.width - width) / 2, y = (screen.height - height) / 2 },
	})
	window:gui_window():set_inner_size(width, height)
end)
config.window_decorations = "RESIZE"


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

local function get_cwd(tab)
    return tab.active_pane.current_working_dir.file_path or ""
end

-- Remove all path components and return only the last value
local function remove_abs_path(path) return path:gsub("(.*[/\\])(.*)", "%2") end

-- Return the pretty path of the tab's current working directory
local function get_display_cwd(tab)
    local current_dir = get_cwd(tab)
    local HOME_DIR = string.format("file://%s", os.getenv("HOME"))
    return current_dir == HOME_DIR and "~/" or remove_abs_path(current_dir)
end

local function format_title(tab)
    local cwd = get_display_cwd(tab)

    local active_title = tab.active_pane.title

    local description = (not active_title or active_title == cwd) and "~" or active_title
    return string.format(" %s ", description)
end

local function has_unseen_output(tab)
    if not tab.is_active then
        for _, pane in ipairs(tab.panes) do
            if pane.has_unseen_output then return true end
        end
    end
    return false
end

-- Returns manually set title (from `tab:set_title()` or `wezterm cli set-tab-title`) or creates a new one
local function get_tab_title(tab)
    local title = tab.tab_title
    if title and #title > 0 then return title end
    return format_title(tab)
end

local function string_to_color(str, isActive)
    -- Convert the string to a unique integer
    local hash = 0
    for i = 1, #str do
        hash = string.byte(str, i) + ((hash << 5) - hash)
    end

    -- Convert the integer to a unique color
    local c = string.format("%06X", hash & 0x00FFFFFF)
    local color = wezterm.color.parse("#" .. (string.rep("0", 6 - #c) .. c):upper())

    if not isActive then
        color = color:darken(0.4)
    end
    return color
end

local function select_contrasting_fg_color(color)
    -- Note: this could use `return color:complement_ryb()` instead if you prefer or other builtins!

    ---@diagnostic disable-next-line: unused-local
    local lightness, _a, _b, _alpha = color:laba()
    if lightness > 55 then
        return "#000000" -- Black has higher contrast with colors perceived to be "bright"
    end
    return "#FFFFFF" -- White has higher contrast
end

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
    local title = get_tab_title(tab)
    local color = string_to_color(get_cwd(tab), tab.is_active)
    local fg_color = select_contrasting_fg_color(color)
    -- local fg_color = "white"
    local prefix = ""
    local fullscreen_prefix = ""


    if tab.is_active then
      prefix = wezterm.nerdfonts.fa_chevron_right
    end
    if has_unseen_output(tab) then
      prefix = wezterm.nerdfonts.cod_bell_dot
    end
    if tab.active_pane.is_zoomed then
      fullscreen_prefix = wezterm.nerdfonts.cod_screen_full
    end
    return {
      { Background = { Color = color } },
      { Foreground = { Color = fg_color } },
      { Text = fullscreen_prefix },
      { Text = prefix },
      { Text = title },
    }
end)

-- config.window_background_image = '/Users/francois/Desktop/recordings/term.png'
config.window_background_image_hsb = {
  brightness = 0.05,
  hue = 1,
  saturation = 1,
}

config.window_background_opacity = 0.976
config.macos_window_background_blur = 5
config.inactive_pane_hsb = {
  saturation = 0.6,
  brightness = 0.5,
}

wezterm.on('toggle-opacity', function(window, pane)
  local overrides = window:get_config_overrides() or {}
  if not overrides.window_background_opacity then
    overrides.window_background_opacity = 0.7
  elseif overrides.window_background_opacity == 0.7 then
    overrides.window_background_opacity = 0.4
    overrides.macos_window_background_blur = 0
  else
    overrides.macos_window_background_blur = nil
    overrides.window_background_opacity = nil
  end
  window:set_config_overrides(overrides)
end)

-- ------------------------------------------------------------------------------------
-- Key bindings
-- ------------------------------------------------------------------------------------

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
  {
    key = 'Enter',
    mods = 'SUPER|SHIFT',
    action = act.TogglePaneZoomState,
  },
}

return config
