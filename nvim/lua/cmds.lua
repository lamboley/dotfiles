-- Automates the downloading of Tree-sitter parsers on the first run
vim.api.nvim_create_autocmd("User", {
	pattern = { "PackInstallPost", "PackUpdatePost" },
	callback = function()
		pcall(vim.cmd, "TSUpdate")
	end,
})

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.hl.on_yank()
  end,
})