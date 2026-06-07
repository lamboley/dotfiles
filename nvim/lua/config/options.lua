local opt = vim.opt

-- Numéros de ligne
opt.number = true
opt.relativenumber = true

-- Indentation
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.smartindent = true

-- Confort visuel
opt.wrap = false         -- pas de retour à la ligne automatique
opt.signcolumn = "yes"   -- colonne des signes toujours là
opt.scrolloff = 8        -- garde 8 lignes de contexte au-dessus/dessous
opt.termguicolors = true -- vraies couleurs
opt.cursorline = true    -- surligne la ligne courante

-- Comportement
opt.mouse = "a"               -- souris active
opt.clipboard = "unnamedplus" -- partage le presse-papier système
opt.undofile = true           -- historique d'annulation persistant
opt.splitright = true         -- nouveaux splits verticaux à droite
opt.splitbelow = true         -- nouveaux splits horizontaux en bas

-- Réactivité
opt.timeoutlen = 300
opt.updatetime = 250
