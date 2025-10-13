-----------------------------------------------
-- Config Reload Watcher
-----------------------------------------------

local config = require("config.constants")
local TIMING = config.TIMING

local ALERTS = {
    CONFIG_LOADED = "🔨 Hammerspoon Config Loaded",
}

-- Logger for debugging
local log = hs.logger.new('reload', 'info')

local function reloadConfig(files)
    log.i("Files changed:", hs.inspect(files))
    for _, file in pairs(files) do
        if file:sub(-4) == ".lua" then
            log.i("Lua file detected, reloading...")
            hs.reload()
            return
        end
    end
end

local function setup()
    -- Resolve symlink to find actual config directory
    local configPath = hs.configdir .. "/init.lua"
    local output = hs.execute("readlink " .. configPath)
    if output and output ~= "" then
        local realPath = output:gsub("\n", "")
        -- Extract directory from resolved path
        local configDir = realPath:match("(.*/)")
        log.i("Watching config directory:", configDir)
        hs.pathwatcher.new(configDir, reloadConfig):start()
    else
        -- Fallback to watching the config directory directly
        hs.pathwatcher.new(hs.configdir, reloadConfig):start()
    end

    hs.alert.show(ALERTS.CONFIG_LOADED, {}, TIMING.ALERT_MEDIUM)
end

return {
    setup = setup,
}
