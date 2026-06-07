-- ~/.config/nvim/lua/config/lazy.lua
-- Bootstrap de lazy.nvim : on le clone au premier lancement s'il est absent,
-- on l'ajoute au runtimepath, puis on l'initialise en lui indiquant où
-- trouver les specs de plugins (le dossier lua/plugins/).

-- Chemin standard où lazy.nvim doit vivre (sous ~/.local/share/nvim/lazy/)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- Si lazy.nvim n'est pas là, on le télécharge (clone superficiel du tag stable)
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Échec du clonage de lazy.nvim :\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nAppuie sur une touche pour quitter..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end

-- On met lazy.nvim en tête du runtimepath pour pouvoir le require
vim.opt.rtp:prepend(lazypath)

-- Démarrage : { import = "plugins" } dit à lazy de charger toutes les specs
-- présentes dans lua/plugins/. checker.enabled = false évite les vérifs
-- de mise à jour automatiques en arrière-plan.
require("lazy").setup({
  spec = {
    { import = "plugins" },
  },
  checker = { enabled = false },
  change_detection = { notify = false },
})
