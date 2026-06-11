-----------------------------------------------
-- Config Reload Watcher
-----------------------------------------------

local config = require("config.constants")
local TIMING = config.TIMING

-- Logger for debugging
local log = hs.logger.new('reload', 'info')

-- Module-level reference so the watcher is not garbage-collected
local watcher = nil

-- Debounce timer to prevent rapid successive reloads
local reloadTimer = nil
local RELOAD_DEBOUNCE_SECONDS = 0.5

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

    -- Debounce: cancel existing timer and create new one
    if reloadTimer then
        reloadTimer:stop()
    end

    reloadTimer = hs.timer.doAfter(RELOAD_DEBOUNCE_SECONDS, function()
        log.i("Reloading config triggered by:", triggeringFile)
        hs.reload()
    end)
end

local function resolveRealPath(path)
    -- readlink -f follows the whole chain: home-manager links pass through an
    -- intermediate /nix/store path before reaching this repo, and FSEvents on
    -- the immutable store directory would never fire.
    local output, status = hs.execute(string.format("readlink -f %s 2>/dev/null", string.format("%q", path)))
    if status and output and output ~= "" then
        return output:gsub("\n", "")
    end
    local attr = hs.fs.symlinkAttributes(path)
    if attr then return path end
    log.w("Failed to resolve path:", path, "- using original")
    return nil
end

local function setup()
    -- Resolve config directory to real path
    local configPath = hs.configdir .. "/init.lua"
    local realInitPath = resolveRealPath(configPath)

    if not realInitPath then
        log.e("Failed to resolve config directory, falling back to hs.configdir")
        realInitPath = configPath
    end

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
