-- Chemin standard où lazy.nvim doit vivre (sous ~/.local/share/nvim/lazy/)
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

-- Si lazy.nvim n'est pas là, on le télécharge
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

require("lazy").setup({
  spec = {
    { import = "plugins" }, -- Load all plugins inside lua/plugins/.
  },
  checker = { enabled = false }, -- Désactive les vérification de mise à jour automatiques en arrière-plan
  change_detection = { notify = false },
})
