-- Config Neovim minimale - zéro plugin, portable (marche partout, hors-ligne).

vim.g.mapleader = " "

local opt = vim.opt
opt.number = true             -- numéros de ligne
opt.relativenumber = true     -- relatifs (saut en 5j, 3k...)
opt.cursorline = true         -- surligne la ligne courante
opt.mouse = "a"               -- souris / tactile (utile sur tablette)
opt.expandtab = true          -- tabulations -> espaces
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true        -- indentation auto
opt.ignorecase = true         -- recherche insensible à la casse...
opt.smartcase = true          -- ...sauf si tu mets une majuscule
opt.termguicolors = true      -- vraies couleurs (24-bit)
opt.scrolloff = 5             -- garde du contexte autour du curseur
opt.signcolumn = "yes"        -- gutter fixe (pas de saut horizontal)
opt.undofile = true           -- undo persistant entre sessions
opt.clipboard = "unnamedplus" -- presse-papier système (xclip / wl-clipboard / OSC52)

local map = vim.keymap.set
map("i", "jk", "<Esc>", { desc = "Sortir du mode insertion" })            -- pas besoin d'Échap
map("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Efface le surlignage" })
map("n", "<leader>w", "<cmd>write<cr>", { desc = "Sauvegarder" })
map("n", "<leader>q", "<cmd>quit<cr>", { desc = "Quitter" })
