local wezterm = require("wezterm")
local config = wezterm.config_builder()

local home = os.getenv("HOME") or os.getenv("USERPROFILE")
package.path = home .. "/.dotfiles/wezterm/?.lua;" .. package.path

require("config.appearance")(config)
require("config.keys")(config)
require("config.platform")(config)

return config
