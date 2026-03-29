return function(config)
    config.color_scheme = "Dracula (Official)"
    config.font = require("wezterm").font("FiraCode Nerd Font Mono")
    config.font_size = 11
    config.window_background_opacity = 0.85
    config.hide_tab_bar_if_only_one_tab = true
    config.window_decorations = "RESIZE"
end
