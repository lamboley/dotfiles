return function(config)
    config.color_scheme = "Dracula (Official)"
    config.font = require("wezterm").font("FiraCode Nerd Font Mono")
    config.font_size = 11
    config.window_background_opacity = 0.85
    config.hide_tab_bar_if_only_one_tab = true
    config.window_decorations = "RESIZE"

    wezterm.on('update-right-status', function(window, pane)
      window:set_right_status(wezterm.strftime(' %H:%M:%S '))
    end)
end
