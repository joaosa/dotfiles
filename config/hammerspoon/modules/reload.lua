-----------------------------------------------
-- Config Reload Watcher
-----------------------------------------------

local config = require("config.constants")
local utils = require("lib.utils")
local TIMING = config.TIMING

-- Logger for debugging
local log = hs.logger.new('reload', 'info')

-- Module-level reference so the watcher is not garbage-collected
local watcher = nil

-- Debounced to prevent rapid successive reloads
local debouncedReload = utils.debounce(hs.reload, 0.5)

local function reloadConfig(files)
    log.i("File change detected:", hs.inspect(files))

    -- Check if any changed file is a .lua file
    local triggeringFile = nil

    for _, file in pairs(files) do
        if file:sub(-4) == ".lua" then
            triggeringFile = file:match("([^/]+)$") or file
            break
        end
    end

    if not triggeringFile then
        log.i("No .lua files changed, skipping reload")
        return
    end

    log.i("Reloading config triggered by:", triggeringFile)
    debouncedReload()
end

local function setup()
    -- Resolve the symlink chain to the real repo directory (home-manager
    -- links pass through an intermediate /nix/store path, and FSEvents on
    -- the immutable store directory would never fire).
    local configPath = hs.configdir .. "/init.lua"
    local realInitPath = hs.fs.pathToAbsolute(configPath) or configPath
    local configDir = realInitPath:match("(.*/)")
    log.i("Resolved config directory:", configDir)

    if hs.fs.attributes(configDir, "mode") ~= "directory" then
        log.e("Config directory does not exist:", configDir)
        return
    end

    -- FSEvents (hs.pathwatcher) is recursive, and configDir resolves to the
    -- real repo directory whose subdirectories are real directories, so one
    -- watcher covers the whole tree.
    log.i("Watching config directory:", configDir)
    watcher = hs.pathwatcher.new(configDir, reloadConfig)
    watcher:start()

    hs.alert.show("🔨 Hammerspoon Config Loaded", {}, TIMING.ALERT_MEDIUM)
end

return {
    setup = setup,
}
