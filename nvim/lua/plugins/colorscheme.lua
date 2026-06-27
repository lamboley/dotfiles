return {
  -- Thème dracula (cohérent avec helix / zellij / alacritty), fond transparent
  -- pour se fondre dans le pane zellij.
  {
    "Mofiqul/dracula.nvim",
    lazy = false,
    priority = 1000,
    opts = { transparent_bg = true },
  },

  -- LazyVim utilise tokyonight par défaut -> on force dracula.
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "dracula" },
  },
}
