local wezterm = require("wezterm")
local config = wezterm.config_builder()

require("wezterm.appearance")(config)
require("wezterm.keys")(config)
require("wezterm.platform")(config)

return config
