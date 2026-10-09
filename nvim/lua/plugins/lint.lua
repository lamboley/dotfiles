-- nvim-lint runs command-line linters that have no language server
-- and turns their output into regular Neovim diagnostics.
-- Tools that do have a language server (eslint, gopls, shellcheck via bashls...)
-- are NOT listed here, the LSP already reports them.
return {

	plugin = {
		src = "https://github.com/mfussenegger/nvim-lint",
	},

	config = function()
		local lint = require("lint")

		lint.linters_by_ft = {
			markdown = { "markdownlint-cli2" },
			go = { "golangcilint" },
		}

		-- Lint once the filetype is known (on open), after every save, and when leaving insert mode.
		-- FileType rather than BufReadPost: this autocmd is registered before Neovim's own
		-- filetype detection, so on BufReadPost the filetype would still be empty.
		-- try_lint only runs the linters listed for the buffer's filetype,
		-- and does nothing for filetypes that are not in the table above.
		vim.api.nvim_create_autocmd({ "FileType", "BufWritePost", "InsertLeave" }, {
			group = vim.api.nvim_create_augroup("lint", { clear = true }),
			callback = function()
				if vim.bo.modifiable then
					lint.try_lint()
				end
			end,
		})
	end,
}
