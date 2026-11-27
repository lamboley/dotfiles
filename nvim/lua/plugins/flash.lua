return {

	plugin = {
		src = "https://github.com/folke/flash.nvim",
	},

	config = function()
		local flash = require("flash")
		flash.setup({})

		local map = function(mode, lhs, rhs, desc)
			vim.keymap.set(mode, lhs, rhs, { desc = desc, silent = true })
		end

		map({ "n", "x", "o" }, "s", function()
			flash.jump()
		end, "Flash")
		map({ "n", "x", "o" }, "S", function()
			flash.treesitter()
		end, "Flash Treesitter")
		map("o", "r", function()
			flash.remote()
		end, "Remote Flash")
		map({ "o", "x" }, "R", function()
			flash.treesitter_search()
		end, "Treesitter Search")
		map("c", "<C-s>", function()
			flash.toggle()
		end, "Toggle Flash Search")
	end,
}
