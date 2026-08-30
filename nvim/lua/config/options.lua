-- Chargé avant lazy.nvim. LazyVim a déjà de bons défauts ; on ajuste juste
-- l'indentation (tu utilisais 4) et un peu de marge de défilement.
local opt = vim.opt
opt.shiftwidth = 4
opt.tabstop = 4
opt.scrolloff = 8

-- Le formatage est géré par le Makefile de chaque projet, pas par l'éditeur.
-- LazyVim active le format-on-save par défaut : on le coupe.
-- Formatage à la demande : <leader>cf. Réactiver : <leader>uf (global) ou
-- <leader>uF (buffer courant).
vim.g.autoformat = false

-- L'extra linting.eslint enregistre lui aussi un formateur (EslintFixAll au
-- save). On le laisse en linter pur.
vim.g.lazyvim_eslint_auto_format = false
