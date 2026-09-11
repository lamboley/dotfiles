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
		map("n", "<leader>aC", "<cmd>ClaudeCode --continue<cr>", "Continue Claude")
		map("n", "<leader>ar", "<cmd>ClaudeCode --resume<cr>", "Resume Claude")
		map("n", "<leader>af", "<cmd>ClaudeCodeFocus<cr>", "Focus Claude")
		map("n", "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", "Select Claude model")
		map("n", "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", "Add current buffer")
		map("v", "<leader>as", "<cmd>ClaudeCodeSend<cr>", "Send to Claude")

		map("n", "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", "Accept diff")
		map("n", "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", "Deny diff")

		-- Add the file under the cursor from a file explorer
		vim.api.nvim_create_autocmd("FileType", {
			pattern = { "oil", "netrw", "NvimTree", "neo-tree", "minifiles", "snacks_picker_list" },
			callback = function(ev)
				vim.keymap.set("n", "<leader>as", "<cmd>ClaudeCodeTreeAdd<cr>", {
					buffer = ev.buf,
					desc = "Add file to Claude",
					silent = true,
				})
			end,
		})

		map({ "n", "t" }, "<C-/>", "<cmd>ClaudeCodeFocus<cr>", "Focus Claude")
	end,
}
