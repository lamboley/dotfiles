-- ~/.config/nvim/lua/plugins/snacks.lua
-- Snacks est une collection de modules. Hors LazyVim, on doit activer
-- explicitement ceux qu'on veut et définir nos propres raccourcis.

return {
  "folke/snacks.nvim",
  priority = 1000, -- chargé tôt
  lazy = false,    -- toujours disponible (l'explorer doit pouvoir s'ouvrir)
  opts = {
    -- Modules activés (enabled = true). Sans ça, ils ne tournent pas.
    explorer = { enabled = true },
    picker = {
      enabled = true,
      sources = {
        explorer = {
          hidden = true,  -- affiche les dotfiles (.git, .gitignore…)
          ignored = true, -- affiche les fichiers git-ignored
        },
      },
    },
  },
  -- Raccourcis (équivalents de ce que LazyVim définissait pour toi).
  keys = {
    { "<leader>e", function() Snacks.explorer() end, desc = "Explorateur de fichiers" },
    { "<leader>ff", function() Snacks.picker.files() end, desc = "Chercher des fichiers" },
    { "<leader>fg", function() Snacks.picker.grep() end, desc = "Rechercher dans les fichiers (grep)" },
    { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Chercher dans les buffers" },
  },
}
