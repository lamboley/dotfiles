-- Config Neovim minimale.

vim.g.mapleader = " "

-- Signale aux plugins (icônes) qu'une Nerd Font est dispo. NB : nvim n'a PAS de
-- réglage de police — c'est le TERMINAL (alacritty) qui fournit FiraCode Nerd Font.
vim.g.have_nerd_font = true

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
  "https://github.com/Mofiqul/dracula.nvim",
  "https://github.com/nvim-lua/plenary.nvim",
  "https://github.com/MunifTanjim/nui.nvim",
  "https://github.com/echasnovski/mini.icons",
  "https://github.com/nvim-neo-tree/neo-tree.nvim",
  "https://github.com/akinsho/bufferline.nvim",
  "https://github.com/nvim-lualine/lualine.nvim",
  { src = "https://github.com/nvim-treesitter/nvim-treesitter", version = "master" },
  "https://github.com/rcarriga/nvim-notify",
  "https://github.com/folke/noice.nvim",
})

-- Thème dracula, fond transparent -> se fond dans le pane zellij (le bg dracula
-- de zellij transparaît, pas de rectangle qui jure avec le cadre).
require("dracula").setup({ transparent_bg = true })
vim.cmd.colorscheme("dracula")

-- Icônes : mini.icons (plus cohérent) remplace nvim-web-devicons via un mock.
-- DOIT tourner avant neo-tree/bufferline/lualine qui consomment les icônes.
require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons()

-- Arbre de fichiers à gauche.
require("neo-tree").setup({
  window = { position = "left", width = 30 },
})
vim.keymap.set("n", "<leader>e", "<cmd>Neotree toggle<CR>")

-- Buffers ouverts affichés en haut.
require("bufferline").setup({
  options = {
    separator_style = "slant",            -- onglets en biseau (style powerline)
    indicator = { style = "underline" },  -- soulignement de l'onglet actif
    diagnostics = "nvim_lsp",             -- pastilles erreurs/warnings (si LSP)
    show_buffer_close_icons = true,
    offsets = {                           -- réserve la colonne de neo-tree
      { filetype = "neo-tree", text = "Explorer", text_align = "left", separator = true },
    },
  },
})
vim.keymap.set("n", "<Tab>", "<cmd>BufferLineCycleNext<CR>")
vim.keymap.set("n", "<S-Tab>", "<cmd>BufferLineCyclePrev<CR>")

-- Coloration syntaxique riche (treesitter, branche master stable = pas le churn
-- de la réécriture). Compile les parsers au 1er lancement (besoin d'un compilo C).
require("nvim-treesitter.configs").setup({
  ensure_installed = { "lua", "vim", "vimdoc", "regex", "go", "bash", "yaml", "json", "toml", "markdown", "markdown_inline", "dockerfile", "gitcommit" },
  auto_install = true,
  highlight = { enable = true },
  indent = { enable = true },
})

-- Barre de statut (thème auto -> suit dracula).
require("lualine").setup({
  options = { theme = "auto", globalstatus = true },
})

-- Cmdline + messages dans des popups flottants centrés (la « boîte » type LazyVim).
require("noice").setup({
  presets = { command_palette = true },
})

-- Navigation entre fenêtres.
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
vim.keymap.set("n", "<C-l>", "<C-w>l")
