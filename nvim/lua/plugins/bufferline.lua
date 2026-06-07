-- ~/.config/nvim/lua/plugins/bufferline.lua
-- Barre d'onglets en haut montrant les buffers (fichiers) ouverts.
-- Nécessite termguicolors (déjà activé dans options.lua) et une Nerd Font
-- pour les icônes (déjà installée).

return {
  "akinsho/bufferline.nvim",
  version = "*",
  dependencies = "nvim-tree/nvim-web-devicons",
  event = "VeryLazy", -- chargé après le démarrage, n'alourdit pas le boot
  opts = {
    options = {
      diagnostics = "nvim_lsp",        -- affichera les erreurs LSP plus tard
      separator_style = "thin",        -- séparateurs sobres (proot/terminal-friendly)
      show_buffer_close_icons = false,
      show_close_icon = false,
      offsets = {
        {
          filetype = "snacks_layout_box", -- décale la barre quand l'explorer Snacks est ouvert
          text = "Explorer",
          highlight = "Directory",
          separator = true,
        },
      },
    },
  },
  keys = {
    -- Cycler entre buffers avec Tab / Shift+Tab
    { "<Tab>", "<cmd>BufferLineCycleNext<CR>", desc = "Buffer suivant" },
    { "<S-Tab>", "<cmd>BufferLineCyclePrev<CR>", desc = "Buffer précédent" },
    -- Fermer le buffer courant
    { "<leader>bd", "<cmd>bdelete<CR>", desc = "Fermer le buffer" },
    -- Aller à un buffer par sa position (1 à 5)
    { "<leader>1", "<cmd>BufferLineGoToBuffer 1<CR>", desc = "Buffer 1" },
    { "<leader>2", "<cmd>BufferLineGoToBuffer 2<CR>", desc = "Buffer 2" },
    { "<leader>3", "<cmd>BufferLineGoToBuffer 3<CR>", desc = "Buffer 3" },
    { "<leader>4", "<cmd>BufferLineGoToBuffer 4<CR>", desc = "Buffer 4" },
    { "<leader>5", "<cmd>BufferLineGoToBuffer 5<CR>", desc = "Buffer 5" },
  },
}
