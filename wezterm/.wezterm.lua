-- Pull in the wezterm API
local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Apparence
config.color_scheme = "Dracula (Official)"
config.font = wezterm.font("FiraCode Nerd Font")
config.font_size = 11
config.window_background_opacity = 0.85

-- Minimalisme
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"

-- Size
config.window_close_confirmation = "NeverPrompt"
config.initial_cols = 160
config.initial_rows = 45

-- Keybindings
config.keys = {
	{
		key = "n",
		mods = "SHIFT|CTRL",
		action = wezterm.action.TogglePaneZoomState,
	},
}

return config
