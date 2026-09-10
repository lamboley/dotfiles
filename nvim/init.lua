vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.smartindent = true
vim.opt.number = true

-- Ctrl-S sauvegarde, y compris depuis le mode insertion (on y reste).
vim.keymap.set({ "n", "v" }, "<C-s>", "<Cmd>write<CR>")
vim.keymap.set("i", "<C-s>", "<Cmd>write<CR>")
