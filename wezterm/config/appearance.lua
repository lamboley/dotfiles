local wezterm = require('wezterm')
local platform = require('utils.platform')

local function pick_gpu()
   local backends = { windows = 'Dx12', linux = 'Vulkan', mac = 'Metal' }
   local by_type = {}
   for _, a in ipairs(wezterm.gui and wezterm.gui.enumerate_gpus() or {}) do
      by_type[a.device_type] = by_type[a.device_type] or {}
      by_type[a.device_type][a.backend] = a
   end
   local adapters = by_type.DiscreteGpu or by_type.IntegratedGpu or by_type.Other or by_type.Cpu
   return adapters and adapters[backends[platform.os]]
end

return {
   -- rendering
   max_fps = 120,
   animation_fps = 120,
   front_end = 'WebGpu',
   webgpu_power_preference = 'HighPerformance',
   webgpu_preferred_adapter = pick_gpu(),
   underline_thickness = '1.5pt',

   -- font
   font = wezterm.font({ family = 'FiraCode Nerd Font Mono', weight = 'Light' }),
   font_size = platform.is_mac and 12 or 11,

   -- cursor
   cursor_blink_ease_in = 'EaseOut',
   cursor_blink_ease_out = 'EaseOut',
   default_cursor_style = 'BlinkingBlock',
   cursor_blink_rate = 650,

   -- color scheme
   color_scheme = 'Dracula (Official)',

   -- tab bar
   hide_tab_bar_if_only_one_tab = false,
   use_fancy_tab_bar = false,
   tab_max_width = 25,
   show_tab_index_in_tab_bar = false,
   switch_to_last_active_tab_when_closing_tab = true,
   tab_bar_at_bottom = true,

   -- command palette
   command_palette_fg_color = '#bd93f9',
   command_palette_bg_color = '#282a36',
   command_palette_font_size = 12,
   command_palette_rows = 25,

   -- window
   window_padding = { left = 0, right = 0, top = 10, bottom = 7.5 },
   adjust_window_size_when_changing_font_size = false,
   window_close_confirmation = 'NeverPrompt',
   window_decorations = 'RESIZE',

   -- bell
   audible_bell = 'Disabled',
   visual_bell = {
      fade_in_function = 'EaseIn',  fade_in_duration_ms = 250,
      fade_out_function = 'EaseOut', fade_out_duration_ms = 250,
      target = 'CursorColor',
   },

   window_background_opacity = 0.85,
}
