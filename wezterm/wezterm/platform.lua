return function(config)
    if require("wezterm").target_triple == "x86_64-pc-windows-msvc" then
        config.default_prog = { "pwsh.exe" }
    end
end