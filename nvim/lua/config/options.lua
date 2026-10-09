vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- Support for Nerd Font
vim.g.have_nerd_font = true

-- Snacks animations
vim.g.snacks_animate = true

-- Hide deprecation warnings
vim.g.deprecation_warnings = false

local opt = vim.opt
opt.autowrite = true -- Enable auto write
opt.completeopt = "menu,menuone,noselect" -- Control appearance of completion menu
opt.confirm = true -- Confirm to save changes before exiting modified buffer
opt.cursorline = true -- Enable highlighting of the current line
opt.expandtab = true -- Use spaces instead of tabs
opt.ignorecase = true -- Ignore case
opt.laststatus = 3 -- global statusline
opt.list = true -- Show some invisible characters
opt.mouse = "a" -- Enable mouse mode
opt.number = true -- Print line number
opt.shiftround = true -- Round indent
opt.shiftwidth = 4 -- Size of an indent
opt.showmode = false -- Dont show mode since we have a statusline
opt.smartcase = true -- Don't ignore case with capitals
opt.smartindent = true -- Insert indents automatically
opt.spelllang = { "en,fr" }
opt.tabstop = 4 -- Number of spaces tabs count for
opt.termguicolors = true -- True color support
opt.undofile = true
opt.undolevels = 10000
opt.wildmode = "longest:full,full" -- Command-line completion mode