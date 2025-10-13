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

-- Store pathwatcher references to prevent garbage collection
local watchers = {}

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
    -- Use Python to resolve symlinks to absolute real paths
    local cmd = string.format("python3 -c \"import os; print(os.path.realpath('%s'))\" 2>&1", path)
    local output, status = hs.execute(cmd)

    if status and output and output ~= "" then
        local resolved = output:gsub("\n", "")
        -- Verify it's not an error message
        if not resolved:match("^Traceback") and not resolved:match("Error") then
            return resolved
        end
    end

    log.w("Failed to resolve path:", path, "- using original")
    return nil
end

local function isDirectory(path)
    local output = hs.execute(string.format("test -d '%s' && echo 'yes' || echo 'no'", path))
    return output and output:match("yes") ~= nil
end

local function discoverSubdirectories(baseDir)
    -- Find all immediate subdirectories (non-recursive)
    local cmd = string.format("find '%s' -maxdepth 1 -type d -not -path '%s'", baseDir, baseDir)
    local output = hs.execute(cmd)

    if not output or output == "" then
        return {}
    end

    local subdirs = {}
    for dir in output:gmatch("[^\n]+") do
        table.insert(subdirs, dir)
    end

    return subdirs
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

    -- Watch root config directory (for init.lua and top-level files)
    if isDirectory(configDir) then
        log.i("Watching root config directory:", configDir)
        watchers.root = hs.pathwatcher.new(configDir, reloadConfig)
        watchers.root:start()
    else
        log.e("Config directory does not exist:", configDir)
        return
    end

    -- Auto-discover and watch all subdirectories
    local subdirs = discoverSubdirectories(configDir)
    log.i("Discovered subdirectories:", #subdirs)

    for i, subdirPath in ipairs(subdirs) do
        if isDirectory(subdirPath) then
            local subdirName = subdirPath:match("([^/]+)$")
            log.i("Watching subdirectory:", subdirName, "->", subdirPath)
            watchers["subdir_" .. i] = hs.pathwatcher.new(subdirPath, reloadConfig)
            watchers["subdir_" .. i]:start()
        else
            log.w("Skipping non-directory:", subdirPath)
        end
    end

    hs.alert.show(ALERTS.CONFIG_LOADED, {}, TIMING.ALERT_MEDIUM)
end

return {
    setup = setup,
}
