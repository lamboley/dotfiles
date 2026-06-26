-- Config Neovim minimale.

vim.g.mapleader = " "

-- nvim-tree gère l'explorateur : on désactive netrw avant tout chargement.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

local opt = vim.opt
opt.number = true
opt.relativenumber = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.ignorecase = true
opt.smartcase = true
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.smartindent = true
opt.termguicolors = true
opt.signcolumn = "yes"
opt.scrolloff = 8
opt.undofile = true

-- Effacer la surbrillance de recherche avec Échap.
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Plugins via vim.pack (gestionnaire intégré, Neovim >= 0.12).
vim.pack.add({
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/MunifTanjim/nui.nvim",
  "https://github.com/nvim-tree/nvim-web-devicons",
  "https://github.com/nvim-neo-tree/neo-tree.nvim",
  "https://github.com/akinsho/bufferline.nvim",
})

-- Arbre de fichiers à gauche.
require("neo-tree").setup({
  window = { position = "left", width = 30 },
})
vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<CR>")

-- Buffers ouverts affichés en haut.
require("bufferline").setup({})
vim.keymap.set("n", "<Tab>", "<cmd>BufferLineCycleNext<CR>")
vim.keymap.set("n", "<S-Tab>", "<cmd>BufferLineCyclePrev<CR>")

-- Navigation entre fenêtres.
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-l>", "<C-w>l")
