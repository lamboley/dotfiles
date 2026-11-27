-- Added here rather than in lua/plugins so the theme is applied before the other plugins load
vim.pack.add({ "https://github.com/folke/tokyonight.nvim" })

vim.cmd.colorscheme("tokyonight-night")
