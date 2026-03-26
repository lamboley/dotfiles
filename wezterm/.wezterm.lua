-- Pull in the wezterm API
local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Apparence
config.color_scheme = "Solarized Dark (Gogh)"
-- config.font = wezterm.font("JetBrainsMono Nerd Font")
config.font = wezterm.font("FiraCode Nerd Font")
config.font_size = 14
config.window_background_opacity = 0.85
config.window_padding = { left = 10, right = 10, top = 10, bottom = 10 }

-- Minimalisme
--config.hide_tab_bar_if_only_one_tab = true
config.enable_tab_bar = false
config.window_decorations = "RESIZE"

-- Keybindings
config.keys = {
	{
		key = "n",
		mods = "SHIFT|CTRL",
		action = wezterm.action.ToggleFullScreen,
	},
}

return config
