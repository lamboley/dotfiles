-- Automates the downloading of Tree-sitter parsers on the first run
vim.api.nvim_create_autocmd("User", {
	pattern = { "PackInstallPost", "PackUpdatePost" },
	callback = function()
		pcall(vim.cmd, "TSUpdate")
	end,
})

