return {
   scrollback_lines = 20000,

   hyperlink_rules = {
      { regex = '\\((\\w+://\\S+)\\)',       format = '$1', highlight = 1 },
      { regex = '\\[(\\w+://\\S+)\\]',       format = '$1', highlight = 1 },
      { regex = '\\{(\\w+://\\S+)\\}',       format = '$1', highlight = 1 },
      { regex = '<(\\w+://\\S+)>',           format = '$1', highlight = 1 },
      { regex = '\\b\\w+://\\S+[)/a-zA-Z0-9-]+',         format = '$0' },
      { regex = '\\b\\w+@[\\w-]+(\\.[\\w-]+)+\\b',       format = 'mailto:$0' },
   },
}
