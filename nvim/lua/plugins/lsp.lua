return {

	plugin = {
		{ src = "https://github.com/neovim/nvim-lspconfig" },
		{ src = "https://github.com/mason-org/mason.nvim" },
		{ src = "https://github.com/mason-org/mason-lspconfig.nvim" },
		{ src = "https://github.com/WhoIsSethDaniel/mason-tool-installer.nvim" },
		{ src = "https://github.com/saghen/blink.cmp", version = vim.version.range("1.x") },
		{ src = "https://github.com/L3MON4D3/LuaSnip", version = vim.version.range("2.x") },
		{ src = "https://github.com/rafamadriz/friendly-snippets" },
	},

	config = function()
		require("mason").setup({})
		require("mason-lspconfig").setup({})
		require("mason-tool-installer").setup({
			ensure_installed = {
				"lua_ls",
				"bashls",
				"shellcheck",
				"stylua",
				"shfmt",
				"prettier",
			},
		})

		-- Load friendly-snippets
		require("luasnip").setup({})
		require("luasnip.loaders.from_vscode").lazy_load()

		require("blink.cmp").setup({
			keymap = {
				preset = "super-tab",
				-- super-tab leaves <CR> unbound
				["<CR>"] = { "accept", "fallback" },
			},

			snippets = { preset = "luasnip" },

			sources = {
				default = { "lsp", "path", "snippets", "buffer" },
			},

			completion = {
				documentation = { auto_show = true },
				-- VSCode-like: first item preselected, <Tab> and <CR> both accept.
				-- auto_insert = false so navigating the list doesn't edit the buffer.
				list = { selection = { preselect = true, auto_insert = false } },
			},

			signature = {
				enabled = true,
				window = { show_documentation = false },
			},
		})

		vim.lsp.config("*", {
			capabilities = require("blink.cmp").get_lsp_capabilities(),
		})

		vim.lsp.config("lua_ls", {
			-- root here, not the .git parent, so "lua/" resolves
			root_dir = vim.fn.stdpath("config"),
			settings = {
				Lua = {
					runtime = { path = { "lua/?.lua", "lua/?/init.lua" } },
				},
			},
		})

		vim.api.nvim_create_autocmd("LspAttach", {
			callback = function(args)
				local opts = { buffer = args.buf }
				vim.keymap.set(
					{ "n", "v" },
					"<leader>ca",
					vim.lsp.buf.code_action,
					vim.tbl_extend("force", opts, { desc = "Code action" })
				)
				vim.keymap.set(
					"n",
					"<leader>rn",
					vim.lsp.buf.rename,
					vim.tbl_extend("force", opts, { desc = "Rename symbol" })
				)
				vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover docs" }))
			end,
		})
		vim.lsp.enable({ "lua_ls", "bashls" })
	end,
}
