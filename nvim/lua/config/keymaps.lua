-- Keymaps additionnels (chargés après ceux de LazyVim).
-- LazyVim fournit déjà <leader>e (explorer), <leader>ff (fichiers), etc.
-- Voir :LazyVim ou https://www.lazyvim.org/keymaps

-- Navigation entre fenêtres (splits) en Ctrl+flèche, en complément des
-- <C-h/j/k/l> de LazyVim. Alt+flèche reste réservé à zellij ; Ctrl+flèche est
-- libre dans alacritty (seul Alt+Return y est mappé) comme dans zellij.
local map = vim.keymap.set
map("n", "<C-Left>", "<C-w>h", { desc = "Aller à la fenêtre de gauche" })
map("n", "<C-Down>", "<C-w>j", { desc = "Aller à la fenêtre du bas" })
map("n", "<C-Up>", "<C-w>k", { desc = "Aller à la fenêtre du haut" })
map("n", "<C-Right>", "<C-w>l", { desc = "Aller à la fenêtre de droite" })

-- Idem depuis un terminal (panneau Claude, terminaux) : sort du mode terminal
-- avant de changer de fenêtre.
map("t", "<C-Left>", "<C-\\><C-n><C-w>h", { desc = "Aller à la fenêtre de gauche" })
map("t", "<C-Down>", "<C-\\><C-n><C-w>j", { desc = "Aller à la fenêtre du bas" })
map("t", "<C-Up>", "<C-\\><C-n><C-w>k", { desc = "Aller à la fenêtre du haut" })
map("t", "<C-Right>", "<C-\\><C-n><C-w>l", { desc = "Aller à la fenêtre de droite" })
