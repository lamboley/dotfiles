local wezterm = require('wezterm')

wezterm.on('update-right-status', function(window, _pane)
   window:set_right_status(wezterm.format({
      { Foreground = { Color = '#fab387' } },
      { Text = wezterm.strftime('%a %H:%M:%S') .. ' ' },
   }))
end)
