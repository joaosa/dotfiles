-----------------------------------------------
-- Alacritty Terminal Management
-----------------------------------------------

local keys = require("config.keybindings")
local config = require("config.constants")
local utils = require("lib.utils")
local windowLib = require("lib.window")
local windowMgmt = require("modules.window-management")

local altCmd = keys.altCmd
local hyper = keys.hyper
local TIMING = config.TIMING
local pluralize = utils.pluralize
local debounce = utils.debounce
local focusAndSleep = windowLib.focusAndSleep
local frames = windowMgmt.frames


-- Logger for debugging
local log = hs.logger.new('terminal', 'info')

-- Terminal window configurations
local terminalConfigs = {
    pulldown = {
        frame = frames.pulldown,
        raise = true,
        mods = { "alt" },
        key = "space"
    },
    fullscreen = {
        frame = frames.full,
        raise = false,
        hideOther = "pulldown",
        mods = altCmd,
        key = "a"
    }
}

-- Get all Alacritty windows across all instances
local function getAllTerminalWindows()
    local allWindows = {}
    for _, app in ipairs(hs.application.applicationsForBundleID("org.alacritty")) do
        for _, window in ipairs(app:allWindows()) do
            table.insert(allWindows, window)
        end
    end
    return allWindows
end

-- Find window by frame
local function getWindowByFrame(targetFrame)
    local screenFrame = hs.screen.mainScreen():frame()

    for _, window in ipairs(getAllTerminalWindows()) do
        local unit = window:frame():toUnitRect(screenFrame)
        if unit:equals(hs.geometry(targetFrame)) then
            return window
        end
    end
    return nil
end

-- Activate window with optional raise
local function activateWindow(window, raise)
    window:application():activate()
    if raise then window:raise() end
    window:focus()
end

-- Toggle terminal window
local function toggleTerminal(type)
    local config = terminalConfigs[type]
    local window = getWindowByFrame(config.frame)

    -- Create window if it doesn't exist
    if not window then
        log.i("Creating", type, "window")
        os.execute("open -n /Applications/Alacritty.app")
        hs.timer.doAfter(0.3, function()
            local wins = getAllTerminalWindows()
            local newest = wins[#wins]
            if newest then
                newest:moveToUnit(config.frame)
                activateWindow(newest, config.raise)
            end
        end)
        return
    end

    local app = window:application()
    local focused = hs.window.focusedWindow()

    -- Hide if already focused (toggle off)
    if focused and focused:id() == window:id() then
        app:hide()
        return
    end

    -- Hide other window if exclusive mode
    if config.hideOther then
        local other = getWindowByFrame(terminalConfigs[config.hideOther].frame)
        if other and other:isVisible() then
            other:application():hide()
        end
    end

    activateWindow(window, config.raise)
end

-- Find matching terminal config for a window
local function findMatchedTerminalConfig(window, windowScreen)
    local windowScreenFrame = windowScreen:frame()
    local oldFrame = window:frame()
    for configName, config in pairs(terminalConfigs) do
        local unit = oldFrame:toUnitRect(windowScreenFrame)
        if unit:equals(hs.geometry(config.frame)) then
            return { name = configName, config = config }
        end
    end
    return nil
end

-- Resize managed terminal window
local function resizeManagedWindow(window, matchedConfig, currentScreen, windowScreen, i)
    if windowScreen:id() ~= currentScreen:id() then
        log.i("Window", i, "is managed", matchedConfig.name, "- moving to main screen")
        window:moveToScreen(currentScreen, false, true)
        hs.timer.usleep(TIMING.WINDOW_OPERATION_SLEEP)
    end
    log.i("Window", i, "ensuring correct", matchedConfig.name, "size")
    focusAndSleep(window)
    window:moveToUnit(matchedConfig.config.frame)
end

-- Proportionally resize unmanaged window
local function resizeUnmanagedWindow(window, oldFrame, windowScreenFrame, screenFrame, i)
    log.i("Resizing window", i, "from", windowScreenFrame.w, "x", windowScreenFrame.h, "to", screenFrame.w, "x", screenFrame.h)

    local targetFrame = {
        x = screenFrame.x + (oldFrame.x / windowScreenFrame.w * screenFrame.w),
        y = screenFrame.y + (oldFrame.y / windowScreenFrame.h * screenFrame.h),
        w = oldFrame.w / windowScreenFrame.w * screenFrame.w,
        h = oldFrame.h / windowScreenFrame.h * screenFrame.h
    }

    focusAndSleep(window)
    window:setFrame(targetFrame, 0.2)
end

local function resizeTerminals()
    log.i("Screen configuration changed, checking terminals")

    local windows = getAllTerminalWindows()
    if #windows == 0 then
        log.i("No terminal windows to resize")
        return
    end

    local currentScreen = hs.screen.mainScreen()
    local screenFrame = currentScreen:frame()
    local resizedCount = 0

    log.i("Target screen size:", screenFrame.w, "x", screenFrame.h)

    -- Resize all visible windows
    for i, window in ipairs(windows) do
        if window:isVisible() and not window:isFullScreen() then
            local windowScreen = window:screen()
            local matchedConfig = findMatchedTerminalConfig(window, windowScreen)

            if matchedConfig then
                resizeManagedWindow(window, matchedConfig, currentScreen, windowScreen, i)
                resizedCount = resizedCount + 1
            elseif windowScreen:id() ~= currentScreen:id() then
                local windowScreenFrame = windowScreen:frame()
                local oldFrame = window:frame()
                resizeUnmanagedWindow(window, oldFrame, windowScreenFrame, screenFrame, i)
                resizedCount = resizedCount + 1
            end
        end
    end

    if resizedCount > 0 then
        hs.alert.show(string.format("Resized %d %s", resizedCount, pluralize(resizedCount, "terminal")), TIMING.ALERT_SHORT)
        log.i("Resized", resizedCount, "terminal window(s)")
    end
end

local function setup()
    -- Register hotkeys for terminal toggling
    for type, config in pairs(terminalConfigs) do
        hs.hotkey.bind(config.mods, config.key, function()
            toggleTerminal(type)
        end)
    end

    -- Auto-resize on screen changes
    local debouncedResizeTerminals = debounce(resizeTerminals, 0.5)
    local screenWatcher = hs.screen.watcher.new(debouncedResizeTerminals)
    screenWatcher:start()

    -- Manual trigger for testing: hyper+z
    hs.hotkey.bind(hyper, "z", resizeTerminals)
end

return {
    setup = setup,
}
