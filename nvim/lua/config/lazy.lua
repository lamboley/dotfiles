-- Installe lazy.nvim si absent (branche stable).
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Échec du clone de lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nAppuie sur une touche pour quitter…" },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    -- LazyVim + ses extras par défaut.
    { "LazyVim/LazyVim", import = "lazyvim.plugins" },
    -- Tes plugins/overrides (lua/plugins/*).
    { import = "plugins" },
  },
  defaults = { lazy = false, version = false },
  -- Thème utilisé pendant l'installation initiale.
  install = { colorscheme = { "catppuccin", "habamax" } },
  checker = { enabled = true, notify = false }, -- vérifie les MAJ en silence
  performance = {
    rtp = {
      disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" },
    },
  },
})
