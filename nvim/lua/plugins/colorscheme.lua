return {
  -- Thème Catppuccin Mocha (cohérent avec helix / zellij / alacritty), fond
  -- transparent pour se fondre dans le pane zellij.
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = true,
    },
  },

  -- LazyVim utilise tokyonight par défaut -> on force catppuccin.
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "catppuccin" },
  },
}
