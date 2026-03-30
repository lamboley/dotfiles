local wezterm = require('wezterm')
local config = wezterm.config_builder()

local home = os.getenv('HOME') or os.getenv('USERPROFILE')
package.path = home .. '/.dotfiles/wezterm/?.lua;' .. package.path

require('events.left-status')
require('events.right-status')
require('events.tab-title')

local function merge(t1, t2)
    for k, v in pairs(t2) do t1[k] = v end
end

merge(config, require('config.appearance'))
merge(config, require('config.general'))
merge(config, require('config.keys'))

if require('utils.platform').is_win then
    config.default_prog = { 'pwsh.exe' }
end

return config
