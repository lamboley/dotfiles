local t = require('wezterm').target_triple

return {
   os       = t:find('windows') and 'windows' or t:find('linux') and 'linux' or 'mac',
   is_win   = t:find('windows') ~= nil,
   is_linux = t:find('linux') ~= nil,
   is_mac   = t:find('apple') ~= nil,
}
