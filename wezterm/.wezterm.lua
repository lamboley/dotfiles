-- Pull in the wezterm API
local wezterm = require("wezterm")

local config = {}

--config.hide_tab_bar_if_only_one_tab = true
--config.window_decorations = "RESIZE"

config.keys = {
	{
		key = "n",
		mods = "SHIFT|CTRL",
		action = wezterm.action.ToggleFullScreen,
	},
}

return config
