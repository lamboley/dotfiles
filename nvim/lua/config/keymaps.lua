-- ~/.config/nvim/lua/config/keymaps.lua
-- Raccourcis personnels. `vim.keymap.set(mode, touche, action, opts)`.

local map = vim.keymap.set

-- Sortir du mode insertion avec "jk" — fiable sur le Book Cover Keyboard
-- où la touche Esc est mal placée / absente.
map("i", "jk", "<Esc>", { desc = "Sortir du mode insertion" })

-- Effacer la surbrillance de recherche avec Échap en mode normal
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Effacer la surbrillance" })

-- Navigation entre splits avec Ctrl + h/j/k/l
map("n", "<C-h>", "<C-w>h", { desc = "Aller au split de gauche" })
map("n", "<C-j>", "<C-w>j", { desc = "Aller au split du bas" })
map("n", "<C-k>", "<C-w>k", { desc = "Aller au split du haut" })
map("n", "<C-l>", "<C-w>l", { desc = "Aller au split de droite" })

-- Sauvegarde rapide
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Sauvegarder" })
