-- ~/.config/nvim/lua/config/keymaps.lua
-- Raccourcis personnels. `vim.keymap.set(mode, touche, action, opts)`.

local map = vim.keymap.set

-- Sortir du mode insertion avec "jk" — fiable sur le Book Cover Keyboard
-- où la touche Esc est mal placée / absente.
map("i", "jk", "<Esc>", { desc = "Sortir du mode insertion" })

-- Effacer la surbrillance de recherche avec Échap en mode normal
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Effacer la surbrillance" })

-- Navigation entre splits avec <leader> + h/j/k/l
-- (Ctrl+h/j/k/l est intercepté par Zellij pour sa navigation entre panes)
map("n", "<leader>h", "<C-w>h", { desc = "Aller au split de gauche" })
map("n", "<leader>j", "<C-w>j", { desc = "Aller au split du bas" })
map("n", "<leader>k", "<C-w>k", { desc = "Aller au split du haut" })
map("n", "<leader>l", "<C-w>l", { desc = "Aller au split de droite" })

-- Sauvegarde rapide
map("n", "<leader>w", "<cmd>write<CR>", { desc = "Sauvegarder" })
