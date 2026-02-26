-----------------------------------------------
-- Window Utilities
-----------------------------------------------

local config = require("config.constants")
local TIMING = config.TIMING

-- Helper function for safe window operations
local function safeWindowOperation(operation, errorMsg)
    local window = hs.window.focusedWindow()
    if not window then
        hs.alert.show(errorMsg or "No active window")
        return false
    end
    return operation(window)
end

-- Bind hotkey for window operation
local function bindWindowOp(mods, key, operation, errorMsg)
    hs.hotkey.bind(mods, key, function()
        safeWindowOperation(operation, errorMsg)
    end)
end

-- Focus window and sleep for proper event handling
local function focusAndSleep(window)
    window:focus()
    hs.timer.usleep(TIMING.WINDOW_OPERATION_SLEEP)
end

-- Restore window context and execute action
local function withWindowRestore(app, window, action)
    if app then app:activate() end
    hs.timer.doAfter(TIMING.WINDOW_FOCUS_DELAY, function()
        if window and window:isVisible() then window:focus() end
        hs.timer.doAfter(TIMING.PASTE_DELAY, action)
    end)
end

return {
    safeWindowOperation = safeWindowOperation,
    bindWindowOp = bindWindowOp,
    focusAndSleep = focusAndSleep,
    withWindowRestore = withWindowRestore,
}
