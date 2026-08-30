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

-- Sauvegarde. LazyVim mappe <C-s>, mais zellij le réserve à son mode scroll
-- (shared_except "locked" "scroll" "search") et il n'atteint jamais nvim.
-- Alt+s est libre des deux côtés.
map({ "i", "x", "n", "s" }, "<A-s>", "<cmd>w<cr><esc>", { desc = "Sauvegarder le fichier" })

-- Désindenter avec Shift+Tab (vim ne le mappe pas ; les équivalents natifs
-- sont <C-d> en insertion et << / < en normal / visuel).
-- Attention : on ne mappe pas <Tab> en mode normal, le terminal l'envoie comme
-- <C-i>, ce qui casserait le saut avant dans la jumplist.
map("i", "<S-Tab>", "<C-d>", { desc = "Désindenter" })
map("n", "<S-Tab>", "<<", { desc = "Désindenter" })
map("x", "<S-Tab>", "<gv", { desc = "Désindenter" })
map("x", "<Tab>", ">gv", { desc = "Indenter" })

-- Commenter/décommenter en Ctrl+/ (réflexe VSCode), en plus de gcc / gc.
-- Le terminal envoie souvent 0x1f pour Ctrl+/, que nvim voit comme <C-_> :
-- on mappe les deux formes. LazyVim utilise <C-/> en mode normal pour le
-- terminal Snacks ; on le lui reprend (il reste sur <leader>ft, et <C-/>
-- depuis le terminal continue de le masquer).
for _, key in ipairs({ "<C-/>", "<C-_>" }) do
  map("n", key, "gcc", { remap = true, desc = "Commenter la ligne" })
  map("x", key, "gc", { remap = true, desc = "Commenter la sélection" })
  map("i", key, "<C-o>gcc", { remap = true, desc = "Commenter la ligne" })
end
