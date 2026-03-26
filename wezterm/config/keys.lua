local wezterm = require("wezterm")

return function(config)
    config.keys = {
    {
        key = "d",
        mods = "SHIFT|CTRL",
        action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
    },
    {
        key = "e",
        mods = "SHIFT|CTRL",
        action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }),
    },
    {
        key = "w",
        mods = "SHIFT|CTRL",
        action = wezterm.action.CloseCurrentPane({ confirm = false }),
    },
    }
end