-- Réglages d'affichage du LSP (les serveurs eux-mêmes sont dans webdev.lua).
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      -- Les annotations grises inline (`: any`, `: undefined`, noms de
      -- paramètres...). Bascule ponctuelle : <leader>uh
      inlay_hints = { enabled = false },
      diagnostics = {
        -- Plus de message d'erreur collé en bout de ligne ("';' expected").
        -- Restent : le signe dans la colonne de gauche + le soulignement.
        -- <leader>cd ouvre le détail de la ligne, ]d / [d naviguent,
        -- <leader>xx ouvre la liste (Trouble), <leader>ud coupe tout.
        virtual_text = false,
      },
    },
  },
}
