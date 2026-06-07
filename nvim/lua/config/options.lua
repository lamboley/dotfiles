-- ~/.config/nvim/lua/config/options.lua
-- Réglages de base de l'éditeur. `vim.opt` est l'équivalent Lua de `:set`.

local opt = vim.opt

-- Numéros de ligne (absolu + relatif pour les sauts type 5j / 3k)
opt.number = true
opt.relativenumber = true

-- Indentation : 2 espaces, pas de tabs
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

-- Recherche : insensible à la casse, sauf si majuscule présente
opt.ignorecase = true
opt.smartcase = true

-- Confort visuel
opt.wrap = false              -- pas de retour à la ligne automatique
opt.signcolumn = "yes"        -- colonne des signes toujours là (évite le saut)
opt.scrolloff = 8             -- garde 8 lignes de contexte au-dessus/dessous
opt.termguicolors = true      -- vraies couleurs (truecolor)
opt.cursorline = true         -- surligne la ligne courante

-- Comportement
opt.mouse = "a"               -- souris active (utile sur tablette)
opt.clipboard = "unnamedplus" -- partage le presse-papier système
opt.undofile = true           -- historique d'annulation persistant
opt.splitright = true         -- nouveaux splits verticaux à droite
opt.splitbelow = true         -- nouveaux splits horizontaux en bas

-- Réactivité (utile pour Esc en terminal, comme on l'a vu)
opt.timeoutlen = 300
opt.updatetime = 250
