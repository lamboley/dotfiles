return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          hidden = true, -- show dotfiles (.git, .gitignore…)
          ignored = true, -- show gitignored files
        },
      },
    },
  },
}
