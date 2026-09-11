return {

	plugin = {
		src = "https://github.com/coder/claudecode.nvim",
	},

	config = function()
		require("claudecode").setup({})

		local map = function(mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, {
				desc = desc,
				silent = true,
			})
		end

		map("n", "<leader>ac", "<cmd>ClaudeCode<cr>", "Toggle Claude")
		map("n", "<leader>af", "<cmd>ClaudeCodeFocus<cr>", "Focus Claude")
		map("n", "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", "Add current buffer")
		map("v", "<leader>as", "<cmd>ClaudeCodeSend<cr>", "Send selection to Claude")

		map("n", "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", "Accept diff")
		map("n", "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", "Deny diff")
	end,
}
