-- Pull in the wezterm API
local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Apparence
config.color_scheme = "Dracula (Official)"
config.font = wezterm.font("FiraCode Nerd Font Mono")
config.font_size = 11
config.window_background_opacity = 0.75

-- Minimalisme
config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"

-- Windows: Use PowerShell
if wezterm.target_triple == "x86_64-pc-windows-msvc" then
    config.default_prog = { "pwsh.exe" }
end

-- Keybindings
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

return config
