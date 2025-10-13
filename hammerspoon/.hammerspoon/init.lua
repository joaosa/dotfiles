-----------------------------------------------
-- Configuration
-----------------------------------------------
local hyper = { "shift", "ctrl", "alt", "cmd" }
local altCmd = { "ctrl", "cmd" }

-- Timing constants (seconds unless noted)
local TIMING = {
    CLIPBOARD_RESTORE_DELAY = 0.3,
    WINDOW_FOCUS_DELAY = 0.15,
    PASTE_DELAY = 0.1,
    WINDOW_CREATE_DELAY = 0.3,
    WINDOW_RESIZE_ANIMATION = 0.2,
    SCREEN_RESIZE_DEBOUNCE = 0.5,
    WINDOW_OPERATION_SLEEP = 50000, -- microseconds
    WHISPER_TIMEOUT = 30,
    ALERT_SHORT = 1,
    ALERT_MEDIUM = 2,
    ALERT_LONG = 3,
    SHUTDOWN_DELAY = 2,
}

-- Alert messages
local ALERTS = {
    CONFIG_LOADED = "🔨 Hammerspoon Config Loaded",
    NO_ACTIVE_WINDOW = "No active window",
    CANNOT_RESIZE = "Cannot resize: no active window",
    CANNOT_FOCUS = "Cannot focus window: no active window",
    CANNOT_MOVE = "Cannot move window: no active window",
    NOTHING_TO_PASTE = "Nothing to paste",
    NO_WIFI = "No WiFi connected",
    DISPLAY_NOT_FOUND = "Display %d not found",
    SHUTDOWN_CANCELLED = "🛑 Shutdown cancelled",
    GOOD_NIGHT = "💤 Good night!",
    WHISPER_TRANSCRIBING = "🎤 Transcribing...",
    WHISPER_RECORDING = "🎤 Recording...",
    WHISPER_TIMEOUT = "❌ Timeout",
    WHISPER_NOT_INSTALLED = "❌ Whisper not installed",
    WHISPER_NO_SPEECH = "❌ No speech\nCheck mic permissions",
    WHISPER_FAILED = "❌ Failed (code %d)",
    WHISPER_RECORDING_FAILED = "❌ Recording failed",
    WHISPER_SUCCESS_PREFIX = "✓ ",
}

-- Application paths and identifiers
local APP_PATHS = {
    TERMINAL = "/Applications/Alacritty.app",
    TERMINAL_BUNDLE = "org.alacritty",
}

-- Whisper configuration
local WHISPER_PATHS = {
    TEMP_FILE = os.getenv("HOME") .. "/.hammerspoon_whisper.wav",
    MODEL = os.getenv("HOME") .. "/.local/share/whisper/ggml-base.en.bin",
}

local WHISPER_CONFIG = {
    PREVIEW_LENGTH = 40,
    SOX_SUCCESS_CODES = {[0] = true, [2] = true},
    SOX_ARGS = {"-d", "-r", "16000", "-c", "1"},
    TRANSCRIBE_ARGS_BASE = {"-m", "--no-timestamps"},
}

-- Get Sleep Focus bedtime from macOS
local function getSleepFocusBedtime()
    local cmd = [[python3 -c "
import json, datetime, os
with open(os.path.expanduser('~/Library/DoNotDisturb/DB/Assertions.json')) as f:
    data = json.load(f)
for r in data['data'][0].get('storeAssertionRecords', []):
    d = r.get('assertionDetails', {})
    if d.get('assertionDetailsModeIdentifier') == 'com.apple.sleep.sleep-mode':
        ts = r.get('assertionStartDateTimestamp', 0)
        t = datetime.datetime(2001,1,1,tzinfo=datetime.timezone.utc) + datetime.timedelta(seconds=ts)
        local_t = t.astimezone()
        print(local_t.hour, local_t.minute)
        break
" 2>/dev/null]]

    local output = hs.execute(cmd)
    if output then
        local hour, minute = output:match("(%d+)%s+(%d+)")
        if hour and minute then
            return tonumber(hour), tonumber(minute)
        end
    end
    return nil, nil
end

-- Scheduled shutdown configuration
local hour, minute = getSleepFocusBedtime()
local shutdownConfig = {
    enabled = hour ~= nil,
    hour = hour,
    minute = minute,
    warnings = { 10, 5 }
}

-- Performance settings
hs.window.animationDuration = 0
hs.window.setFrameCorrectness = true

-- Logger for debugging
local log = hs.logger.new('config', 'info')

-- Helper function for safe window operations
local function safeWindowOperation(operation, errorMsg)
    local window = hs.window.focusedWindow()
    if not window then
        hs.alert.show(errorMsg or ALERTS.NO_ACTIVE_WINDOW)
        return false
    end
    return operation(window)
end

-----------------------------------------------
-- Utility Helpers
-----------------------------------------------

-- Find binary in common paths or via fallback command
local function findBinary(name, paths, fallbackCmd)
    for _, path in ipairs(paths) do
        if hs.fs.attributes(path) then
            return path
        end
    end

    if fallbackCmd then
        local result = hs.execute(fallbackCmd)
        if result and result ~= "" then
            return result:gsub("\n", "")
        end
    end

    return nil
end

-- Execute function with clipboard preservation
local function withClipboard(fn)
    local current = hs.pasteboard.getContents()
    fn()
    if current then
        hs.timer.doAfter(TIMING.CLIPBOARD_RESTORE_DELAY, function()
            hs.pasteboard.setContents(current)
        end)
    end
end

-- Launch or focus application
local function launchOrFocusApp(appName)
    local app = hs.application.find(appName)
    if app and app:isRunning() then
        app:activate()
    else
        hs.application.launchOrFocus(appName)
    end
end

-- Focus window and sleep for proper event handling
local function focusAndSleep(window)
    window:focus()
    hs.timer.usleep(TIMING.WINDOW_OPERATION_SLEEP)
end

-- Trim whitespace from string
local function trim(str)
    return str:gsub("^%s+", ""):gsub("%s+$", "")
end

-- Pluralize string based on count
local function pluralize(count, singular, plural)
    return count == 1 and singular or (plural or singular .. "s")
end

-- Build missing dependencies message
local function missingDeps(deps)
    local missing = {}
    for name, value in pairs(deps) do
        if not value then
            table.insert(missing, name)
        end
    end
    return #missing > 0 and table.concat(missing, " ") or nil
end

-- Bind hotkey for window operation
local function bindWindowOp(mods, key, operation, errorMsg)
    hs.hotkey.bind(mods, key, function()
        safeWindowOperation(operation, errorMsg)
    end)
end

-- Create a debounced version of a function
local function debounce(fn, delay)
    local timer = nil
    return function()
        if timer then timer:stop() end
        timer = hs.timer.doAfter(delay, fn)
    end
end

-- Restore window context and execute action
local function withWindowRestore(app, window, action)
    if app then app:activate() end
    hs.timer.doAfter(TIMING.WINDOW_FOCUS_DELAY, function()
        if window and window:isVisible() then window:focus() end
        hs.timer.doAfter(TIMING.PASTE_DELAY, action)
    end)
end

-----------------------------------------------
-- Reload config on write
-----------------------------------------------
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

-----------------------------------------------
-- Open the hammerspoon console
-----------------------------------------------
hs.hotkey.bind(altCmd, "x", hs.openConsole)

-----------------------------------------------
-- hyper + x key for window resizing
-----------------------------------------------
local frames = {
    rightTopQuarter = "[100,50,50,0]",
    leftBottomQuarter = "[50,100,0,50]",
    rightBottomQuarter = "[100,100,50,50]",
    leftTopQuarter = "[50,50,0,0]",
    full = "[100,100,0,0]",
    rightHalf = "[100,100,50,0]",
    leftHalf = "[50,100,0,0]",
    topHalf = "[100,50,0,0]",
    bottomHalf = "[0,50,100,100]",
    pulldown = "[100,40,0,0]"
}

local windowPositionBindings = {
    d = frames.leftHalf,
    g = frames.rightHalf,
    f = frames.full,
    r = frames.leftTopQuarter,
    t = frames.rightTopQuarter,
    c = frames.leftBottomQuarter,
    v = frames.rightBottomQuarter,
    s = frames.topHalf,
    x = frames.bottomHalf
}

for key, pos in pairs(windowPositionBindings) do
    bindWindowOp(hyper, key, function(window)
        window:moveToUnit(pos)
        return true
    end, ALERTS.CANNOT_RESIZE)
end

-----------------------------------------------
-- altCmd i to show window hints
-----------------------------------------------
hs.hotkey.bind(altCmd, "-", hs.hints.windowHints)

-----------------------------------------------
-- altCmd hjkl to switch window focus
-----------------------------------------------
local windowFocusBindings = {
    k = "focusWindowNorth",
    j = "focusWindowSouth",
    l = "focusWindowEast",
    h = "focusWindowWest"
}

for key, action in pairs(windowFocusBindings) do
    bindWindowOp(altCmd, key, function(window)
        window[action](window)
        return true
    end, ALERTS.CANNOT_FOCUS)
end

-----------------------------------------------
-- Move to app
-----------------------------------------------
local appBindings = {
    e = "Obsidian",
    w = "Firefox Developer Edition",
    i = "Slack",
    o = "Spotify",
    u = "Mail",
    n = "Notion"
}

for key, appName in pairs(appBindings) do
    hs.hotkey.bind(altCmd, key, function()
        launchOrFocusApp(appName)
    end)
end

-----------------------------------------------
-- Alacritty terminal management (0-2 windows on-demand)
-----------------------------------------------

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
    for _, app in ipairs(hs.application.applicationsForBundleID(APP_PATHS.TERMINAL_BUNDLE)) do
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
        os.execute("open -n " .. APP_PATHS.TERMINAL)
        hs.timer.doAfter(TIMING.WINDOW_CREATE_DELAY, function()
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

-- Register hotkeys
for type, config in pairs(terminalConfigs) do
    hs.hotkey.bind(config.mods, config.key, function()
        toggleTerminal(type)
    end)
end

-----------------------------------------------
-- Move to display
-----------------------------------------------
-- ref https://stackoverflow.com/questions/54151343/how-to-move-an-application-between-monitors-in-hammerspoon
local displays = hs.screen.allScreens()
for i = 1, #displays do
    bindWindowOp(altCmd, tostring(i), function(window)
        if displays[i] then
            window:moveToScreen(displays[i], false, true)
            return true
        else
            hs.alert.show(string.format(ALERTS.DISPLAY_NOT_FOUND, i))
            return false
        end
    end, ALERTS.CANNOT_MOVE)
end

-----------------------------------------------
-- Insert dates
-----------------------------------------------
local function pasteString(string)
    if not string or string == "" then
        hs.alert.show(ALERTS.NOTHING_TO_PASTE)
        return
    end

    withClipboard(function()
        hs.pasteboard.setContents(string)
        hs.eventtap.keyStrokes(string)
    end)
end

-- Date shortcuts
hs.hotkey.bind(altCmd, "]", function()
    pasteString(os.date("%Y-%m-%d"))
end)
hs.hotkey.bind(altCmd, "[", function()
    pasteString(os.date("%Y-%m-%d", os.time() - 86400))
end)

-----------------------------------------------
-- Additional Utilities
-----------------------------------------------

local utilityBindings = {
    w = function() -- Show WiFi network
        local wifi = hs.wifi.currentNetwork()
        hs.alert.show(wifi and ("WiFi: " .. wifi) or ALERTS.NO_WIFI, {},
            wifi and TIMING.ALERT_LONG or TIMING.ALERT_MEDIUM)
    end,
    l = hs.caffeinate.lockScreen, -- Lock screen
    s = hs.caffeinate.systemSleep  -- Sleep
}

for key, fn in pairs(utilityBindings) do
    hs.hotkey.bind(hyper, key, fn)
end

-----------------------------------------------
-- Speech to text with Whisper
-----------------------------------------------
local whisper = {
    recording = nil,
    task = nil,
    tempFile = WHISPER_PATHS.TEMP_FILE,
    model = WHISPER_PATHS.MODEL,
    binary = nil,
    sox = nil,
}

-- Find and cache binaries on load
whisper.binary = findBinary("whisper-cli",
    { "/opt/homebrew/bin/whisper-cli", "/usr/local/bin/whisper-cli" },
    "find /opt/homebrew/Cellar/whisper-cpp -name whisper-cli -type f 2>/dev/null | head -1"
)

whisper.sox = findBinary("sox",
    { "/opt/homebrew/bin/sox", "/usr/local/bin/sox" }
)

-- Validate dependencies
local missing = missingDeps({
    ["whisper-cli"] = whisper.binary,
    ["sox"] = whisper.sox,
    ["model"] = hs.fs.attributes(whisper.model)
})
if missing then
    log.e("Whisper setup failed - missing: " .. missing)
end

-- Ctrl+Cmd+D: Toggle recording/transcribe
hs.hotkey.bind(altCmd, "d", function()
    if whisper.recording then
        -- Stop recording and transcribe
        whisper.recording:terminate()
        whisper.recording = nil
        hs.alert.show(ALERTS.WHISPER_TRANSCRIBING)

        local win = hs.window.focusedWindow()
        local app = hs.application.frontmostApplication()

        -- Timeout after 30s
        local timeout = hs.timer.doAfter(TIMING.WHISPER_TIMEOUT, function()
            if whisper.task then
                whisper.task:terminate()
                whisper.task = nil
                hs.alert.show(ALERTS.WHISPER_TIMEOUT)
            end
        end)

        -- Transcribe
        whisper.task = hs.task.new(whisper.binary, function(code, stdout)
            timeout:stop()
            whisper.task = nil
            pcall(os.remove, whisper.tempFile)

            if code == 0 then
                local text = trim(stdout)
                if text ~= "" and not text:match("^%[") then
                    local preview = text:sub(1, WHISPER_CONFIG.PREVIEW_LENGTH)
                    if text:len() > WHISPER_CONFIG.PREVIEW_LENGTH then
                        preview = preview .. "..."
                    end
                    hs.alert.show(ALERTS.WHISPER_SUCCESS_PREFIX .. preview)
                    withWindowRestore(app, win, function()
                        pasteString(text)
                    end)
                else
                    hs.alert.show(ALERTS.WHISPER_NO_SPEECH)
                end
            else
                hs.alert.show(string.format(ALERTS.WHISPER_FAILED, code))
            end
        end, { "-m", whisper.model, "-f", whisper.tempFile, "--no-timestamps" }):start()
    else
        -- Start recording
        if not whisper.binary or not whisper.sox then
            hs.alert.show(ALERTS.WHISPER_NOT_INSTALLED)
            return
        end

        pcall(os.remove, whisper.tempFile)
        hs.alert.show(ALERTS.WHISPER_RECORDING)

        local soxArgs = {table.unpack(WHISPER_CONFIG.SOX_ARGS)}
        table.insert(soxArgs, whisper.tempFile)
        whisper.recording = hs.task.new(whisper.sox, function(code)
            if not WHISPER_CONFIG.SOX_SUCCESS_CODES[code] then
                hs.alert.show(ALERTS.WHISPER_RECORDING_FAILED)
            end
        end, soxArgs):start()
    end
end)

-----------------------------------------------
-- Auto-resize terminals on screen changes
-----------------------------------------------
-- Resizes Alacritty windows proportionally when docking/undocking
-- Focuses window + uses animation to trigger proper resize events
-- Alacritty sends SIGWINCH → tmux auto-resizes (no commands needed)

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
    window:setFrame(targetFrame, TIMING.WINDOW_RESIZE_ANIMATION)
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

local debouncedResizeTerminals = debounce(resizeTerminals, TIMING.SCREEN_RESIZE_DEBOUNCE)

local screenWatcher = hs.screen.watcher.new(debouncedResizeTerminals)
screenWatcher:start()

-- Manual trigger for testing: hyper+z
hs.hotkey.bind(hyper, "z", resizeTerminals)

-----------------------------------------------
-- Scheduled Shutdown
-----------------------------------------------
local shutdownTimer = nil

local function cancelShutdown()
    if shutdownTimer then
        shutdownTimer:stop()
        shutdownTimer = nil
        hs.alert.show(ALERTS.SHUTDOWN_CANCELLED)
    end
end

if shutdownConfig.enabled then
    shutdownTimer = hs.timer.doAt(
        string.format("%02d:%02d", shutdownConfig.hour, shutdownConfig.minute),
        function()
            hs.alert.show(ALERTS.GOOD_NIGHT)
            hs.timer.doAfter(TIMING.SHUTDOWN_DELAY, hs.caffeinate.systemSleep)
        end
    )
end

hs.hotkey.bind(hyper, "p", cancelShutdown)
