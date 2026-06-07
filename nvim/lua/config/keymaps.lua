local map = vim.keymap.set

-- Effacer la surbrillance de recherche avec Échap en mode normal
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Effacer la surbrillance" })

-- Navigation entre splits avec <leader> + h/j/k/l
map("n", "<leader>h", "<C-w>h", { desc = "Aller au split de gauche" })
map("n", "<leader>j", "<C-w>j", { desc = "Aller au split du bas" })
map("n", "<leader>k", "<C-w>k", { desc = "Aller au split du haut" })
map("n", "<leader>l", "<C-w>l", { desc = "Aller au split de droite" })
