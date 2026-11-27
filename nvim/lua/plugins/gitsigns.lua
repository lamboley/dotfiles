return {

	plugin = {
		src = "https://github.com/lewis6991/gitsigns.nvim",
	},

	config = function()
		require("gitsigns").setup({
			on_attach = function(bufnr)
				local gitsigns = require("gitsigns")
				local map = function(mode, lhs, rhs, desc)
					vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
				end

				-- Navigation (falls back to the built-in ]c / [c in diff mode)
				map("n", "]c", function()
					if vim.wo.diff then
						vim.cmd.normal({ "]c", bang = true })
					else
						gitsigns.nav_hunk("next")
					end
				end, "Next Hunk")
				map("n", "[c", function()
					if vim.wo.diff then
						vim.cmd.normal({ "[c", bang = true })
					else
						gitsigns.nav_hunk("prev")
					end
				end, "Prev Hunk")

				-- Actions
				map("n", "<leader>hs", gitsigns.stage_hunk, "Stage/Unstage Hunk")
				map("n", "<leader>hr", gitsigns.reset_hunk, "Reset Hunk")
				map("v", "<leader>hs", function()
					gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, "Stage Selection")
				map("v", "<leader>hr", function()
					gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
				end, "Reset Selection")
				map("n", "<leader>hp", gitsigns.preview_hunk, "Preview Hunk")
				map("n", "<leader>hb", function()
					gitsigns.blame_line({ full = true })
				end, "Blame Line")
				map("n", "<leader>hd", gitsigns.diffthis, "Diff This")
			end,
		})
	end,
}
