-----------------------------------------------
-- Alacritty Terminal Management
-----------------------------------------------

local keys = require("config.keybindings")
local config = require("config.constants")
local utils = require("lib.utils")
local windowLib = require("lib.window")
local windowMgmt = require("modules.window-management")

local altCmd = keys.altCmd
local TIMING = config.TIMING
local pluralize = utils.pluralize
local debounce = utils.debounce
local frames = windowMgmt.frames
local focusAndSleep = windowLib.focusAndSleep


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

-- Find window by frame, optionally restricted to a specific screen
local function getWindowByFrame(targetFrame, screen)
    for _, window in ipairs(getAllTerminalWindows()) do
        local winScreen = window:screen()
        if winScreen and (not screen or winScreen:id() == screen:id()) then
            local unit = window:frame():toUnitRect(winScreen:frame())
            if unit:equals(hs.geometry(targetFrame)) then
                return window
            end
        end
    end
    return nil
end

-- Focus window with optional raise (without activating the app which can switch screens)
local function focusWindow(window, raise)
    if raise then window:raise() end
    window:focus()
end

-- Move window to screen and resize
local function moveWindowToScreen(window, targetScreen, frame, raise)
    local targetSpaceID = hs.spaces.activeSpaceOnScreen(targetScreen)
    hs.spaces.moveWindowToSpace(window, targetSpaceID)
    local screenFrame = targetScreen:frame()
    local targetGeom = hs.geometry(frame)
    window:setFrame({
        x = screenFrame.x + (targetGeom.x * screenFrame.w),
        y = screenFrame.y + (targetGeom.y * screenFrame.h),
        w = targetGeom.w * screenFrame.w,
        h = targetGeom.h * screenFrame.h,
    })
    hs.timer.doAfter(0.1, function()
        focusWindow(window, raise)
    end)
end

-- Toggle terminal window
local function toggleTerminal(type)
    local cfg = terminalConfigs[type]
    local focusedWin = hs.window.focusedWindow()
    local currentScreen = focusedWin and focusedWin:screen() or hs.screen.mainScreen()

    -- First check if window exists on current screen
    local window = getWindowByFrame(cfg.frame, currentScreen)

    -- If not on current screen, check other screens
    if not window then
        local existingWindow = getWindowByFrame(cfg.frame)
        if existingWindow then
            -- Move existing window to current screen
            log.i("Moving", type, "window to screen", currentScreen:name())
            moveWindowToScreen(existingWindow, currentScreen, cfg.frame, cfg.raise)
            return
        end
    end

    -- Create window if it doesn't exist anywhere
    if not window then
        log.i("Creating", type, "window on screen", currentScreen:name())
        local windowCountBefore = #getAllTerminalWindows()

        hs.task.new("/usr/bin/open", nil, {"-n", "/Applications/Alacritty.app"}):start()

        -- Wait for new window to appear
        hs.timer.waitUntil(
            function()
                return #getAllTerminalWindows() > windowCountBefore
            end,
            function()
                local wins = getAllTerminalWindows()
                local newest = wins[#wins]
                if newest then
                    moveWindowToScreen(newest, currentScreen, cfg.frame, cfg.raise)
                end
            end,
            0.05
        )
        return
    end

    -- Hide if already focused (toggle off)
    if focusedWin and focusedWin:id() == window:id() then
        local app = window:application()
        app:hide()
        return
    end

    -- Hide other window if exclusive mode
    if cfg.hideOther then
        local other = getWindowByFrame(terminalConfigs[cfg.hideOther].frame, currentScreen)
        if other and other:isVisible() then
            other:application():hide()
        end
    end

    focusWindow(window, cfg.raise)
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
end

return {
    setup = setup,
}
