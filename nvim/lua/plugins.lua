local plugin_dir = vim.fn.stdpath("config") .. "/lua/plugins"

local plugins = {}
local configs = {}

for _, file in ipairs(vim.fn.readdir(plugin_dir)) do
	if file:match("%.lua$") then
		local mod = require("plugins." .. file:gsub("%.lua$", ""))

		if mod.plugin then
			if mod.plugin.src then
				plugins[#plugins + 1] = mod.plugin
			else
				vim.list_extend(plugins, mod.plugin)
			end
		end

		if type(mod.config) == "function" then
			configs[#configs + 1] = { name = file, run = mod.config }
		end
	end
end

if vim.pack then
	vim.pack.add(plugins)
else
	-- Neovim 0.11 has no native package manager.
	local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
	if not vim.uv.fs_stat(lazypath) then
		local output = vim.fn.system({
			"git",
			"clone",
			"--filter=blob:none",
			"--branch=stable",
			"https://github.com/folke/lazy.nvim.git",
			lazypath,
		})
		if vim.v.shell_error ~= 0 then
			error("Could not install lazy.nvim: " .. output)
		end
	end
	vim.opt.rtp:prepend(lazypath)

	local specs = {}
	for _, plugin in ipairs(plugins) do
		local version = plugin.version
		if type(version) == "table" then
			version = ">=" .. tostring(version.from) .. " <" .. tostring(version.to)
		end
		specs[#specs + 1] = { url = plugin.src, name = plugin.name, version = version, lazy = false }
	end
	require("lazy").setup(specs, {
		change_detection = { notify = false },
	})
end

for _, config in ipairs(configs) do
	local ok, err = pcall(config.run)
	if not ok then
		vim.notify("Plugin configuration failed (" .. config.name .. "): " .. err, vim.log.levels.ERROR)
	end
end
