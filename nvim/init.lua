-- ~/.config/nvim/init.lua
-- Point d'entrée. On définit la touche leader AVANT de charger lazy.nvim
-- (sinon les raccourcis <leader>... des plugins seraient mal enregistrés),
-- puis on délègue tout le reste aux modules sous lua/.

-- Leader = Espace (convention moderne). Doit être défini en tout premier.
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Réglages de l'éditeur et raccourcis perso
require("config.options")
require("config.keymaps")

-- Bootstrap + démarrage de lazy.nvim (qui chargera lua/plugins/)
require("config.lazy")
