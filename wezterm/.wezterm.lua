local wezterm = require("wezterm")
local config = wezterm.config_builder()

require("config.appearance")(config)
require("config.keys")(config)
require("config.platform")(config)

return config
