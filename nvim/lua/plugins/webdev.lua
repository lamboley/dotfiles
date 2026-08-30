-- HTML / CSS / Emmet — complète les extras lang.typescript et lang.vue
-- (activés dans lazyvim.json), qui couvrent JS/TS et Vue3. Il manque les
-- serveurs HTML/CSS/Emmet et les parsers Treesitter css/scss. Tout s'installe
-- user-local via Mason (~/.local/share/nvim/mason), aucun sudo.
-- Le formatage n'est pas géré ici : voir vim.g.autoformat dans config/options.
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
          -- Liste par défaut de nvim-lspconfig, moins `pug`/`eruby`/etc. qu'on
          -- n'écrit pas. `javascript` en est volontairement ABSENT : dans un
          -- .js sans JSX, Emmet n'a rien d'utile à proposer, mais il répond
          -- quand même à tout — sur `myArrayTest.po` il lit `.po` comme un
          -- sélecteur de classe et renvoie `<myArrayTest class="po">`, qui
          -- vient concurrencer `pop`/`push`/`shift` du LSP TypeScript.
          -- Ne le rajouter que si tu écris du JSX dans des fichiers .js.
          filetypes = {
            "html",
            "css",
            "scss",
            "sass",
            "less",
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
