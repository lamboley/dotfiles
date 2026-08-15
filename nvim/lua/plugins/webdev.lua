-- HTML / CSS / Emmet — complète les extras lang.typescript, lang.vue et
-- formatting.prettier (activés dans lazyvim.json). Ces trois-là couvrent
-- JS/TS, Vue3 et le formatage ; il ne manque que les serveurs HTML/CSS/Emmet
-- et les parsers Treesitter css/scss. Tout s'installe user-local via Mason
-- (~/.local/share/nvim/mason), aucun sudo.
return {
  -- Parsers Treesitter manquants (html/js/vue/ts viennent déjà des défauts
  -- LazyVim et de l'extra vue).
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "css", "scss" })
    end,
  },

  -- Serveurs LSP HTML / CSS / Emmet (aucun extra LazyVim ne les fournit).
  -- Ajoutés à opts.servers -> mason-lspconfig les installe automatiquement.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        html = {},
        cssls = {},
        emmet_language_server = {
          filetypes = {
            "html",
            "css",
            "scss",
            "sass",
            "less",
            "javascript",
            "javascriptreact",
            "typescriptreact",
            "vue",
          },
        },
      },
    },
  },

  -- Garantit l'install user-local des outils via Mason (ceinture + bretelles
  -- avec l'auto-install de mason-lspconfig ci-dessus).
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "html-lsp", "css-lsp", "emmet-language-server" } },
  },
}
