return {

	plugin = {
		src = "https://github.com/stevearc/oil.nvim",
	},

	config = function()
		require("oil").setup({
			default_file_explorer = true,
			view_options = { show_hidden = true },
		})

		local map = function(mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, {
				desc = desc,
				silent = true,
			})
		end

		map("n", "<leader>e", "<cmd>Oil<cr>", "File Explorer (oil)")

		map("n", "-", "<cmd>Oil<cr>", "Open parent directory")
	end,
}
