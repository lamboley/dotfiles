local wezterm = require('wezterm')
local nf = wezterm.nerdfonts

local UNSEEN_ICONS = {}
for i = 1, 9 do UNSEEN_ICONS[i] = nf['md_numeric_' .. i .. '_box_multiple'] end
UNSEEN_ICONS[10] = nf.md_numeric_9_plus_box_multiple

local COLORS = {
   default = { bg = '#45475A', fg = '#1C1B19' },
   hover   = { bg = '#5D87A3', fg = '#1C1B19' },
   active  = { bg = '#74c7ec', fg = '#11111B' },
}

local locked_titles = {}

local function build_title(raw_title, max_width, has_unseen)
   local title = raw_title
   local inset = 6 + (has_unseen and 2 or 0)

   if raw_title == 'Debug' then
      title = nf.fa_bug .. ' DEBUG'
      inset = inset - 2
   end

   if #title > max_width - inset then
      title = title:sub(1, max_width - inset)
   else
      title = title .. string.rep(' ', max_width - #title - inset)
   end

   return title
end

local function count_unseen(panes)
   local count = 0
   for _, pane in ipairs(panes) do
      if pane.has_unseen_output then count = math.min(count + 1, 10) end
   end
   return count
end

wezterm.on('format-tab-title', function(tab, _tabs, _panes, _config, hover, max_width)
   local c = COLORS[tab.is_active and 'active' or (hover and 'hover' or 'default')]
   local unseen = count_unseen(tab.panes)
   local title = build_title(locked_titles[tab.tab_id] or tab.active_pane.title, max_width, unseen > 0)

   local items = {
      { Background = { Color = c.bg } },
      { Foreground = { Color = c.fg } },
      { Attribute = { Intensity = 'Bold' } },
      { Text = ' ' .. title },
      'ResetAttributes',
   }

   if unseen > 0 then
      table.insert(items, { Background = { Color = c.bg } })
      table.insert(items, { Foreground = { Color = '#FFA066' } })
      table.insert(items, { Text = ' ' .. UNSEEN_ICONS[unseen] })
      table.insert(items, 'ResetAttributes')
   end

   table.insert(items, { Background = { Color = c.bg } })
   table.insert(items, { Text = ' ' })
   table.insert(items, 'ResetAttributes')

   return items
end)

wezterm.on('tabs.manual-update-tab-title', function(window, pane)
   window:perform_action(
      wezterm.action.PromptInputLine({
         description = wezterm.format({
            { Foreground = { Color = '#FFFFFF' } },
            { Attribute = { Intensity = 'Bold' } },
            { Text = 'Enter new name for tab' },
         }),
         action = wezterm.action_callback(function(_window, _pane, line)
            if line then locked_titles[window:active_tab():tab_id()] = line end
         end),
      }),
      pane
   )
end)

wezterm.on('tabs.reset-tab-title', function(window, _pane)
   locked_titles[window:active_tab():tab_id()] = nil
end)

wezterm.on('tabs.toggle-tab-bar', function(window, _pane)
   local cfg = window:effective_config()
   window:set_config_overrides({ enable_tab_bar = not cfg.enable_tab_bar })
end)
