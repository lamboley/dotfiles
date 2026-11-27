-- Added here rather than in lua/plugins so the theme is applied before the other plugins load
vim.pack.add({ "https://github.com/folke/tokyonight.nvim" })

-- transparent: no background of its own, so the terminal's transparency shows through
require("tokyonight").setup({
	transparent = true,
	styles = {
		sidebars = "transparent",
		floats = "transparent",
	},
	-- Status line: drop the backgrounds, the mode block keeps its color
	on_highlights = function(hl)
		for _, group in ipairs({
			"StatusLine",
			"StatusLineNC",
			"MiniStatuslineDevinfo",
			"MiniStatuslineFilename",
			"MiniStatuslineFileinfo",
			"MiniStatuslineInactive",
		}) do
			hl[group] = vim.tbl_extend("force", hl[group] or {}, { bg = "NONE" })
		end
	end,
})

vim.cmd.colorscheme("tokyonight-night")
