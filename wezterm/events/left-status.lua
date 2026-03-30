local wezterm = require('wezterm')
local nf = wezterm.nerdfonts

wezterm.on('update-right-status', function(window, _pane)
   local name = window:active_key_table()
   local icon

   if window:leader_is_active() then
      icon = nf.md_key
      name = ''
   elseif name then
      icon = nf.md_table_key
      name = ' ' .. string.upper(name)
   end

   if icon then
      window:set_left_status(wezterm.format({
         { Background = { Color = '#fab387' } },
         { Foreground = { Color = '#1c1b19' } },
         { Attribute = { Intensity = 'Bold' } },
         { Text = ' ' .. icon .. (name or '') .. ' ' },
      }))
   end
end)
