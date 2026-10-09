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

vim.pack.add(plugins)

for _, config in ipairs(configs) do
	local ok, err = pcall(config.run)
	if not ok then
		vim.notify("Plugin configuration failed (" .. config.name .. "): " .. err, vim.log.levels.ERROR)
	end
end
