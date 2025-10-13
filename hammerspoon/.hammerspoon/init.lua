-----------------------------------------------
-- Bootstrap SpoonInstall (pinned to commit)
-----------------------------------------------
local function bootstrapSpoonInstall()
    local spoonPath = hs.configdir .. "/Spoons/SpoonInstall.spoon"
    if not hs.fs.attributes(spoonPath) then
        local tmpFile = "/tmp/spooninstall.zip"
        -- Pinned to commit 30b4f60 (2019-08-28) - last update
        local commitSHA = "30b4f6013d48bd000a8ddecff23e5a8cce40c73c"

        hs.execute(string.format(
            "curl -sL https://github.com/Hammerspoon/Spoons/raw/%s/Spoons/SpoonInstall.spoon.zip -o %s",
            commitSHA, tmpFile
        ))
        hs.execute(string.format("unzip -q %s -d '%s/Spoons/' && rm %s", tmpFile, hs.configdir, tmpFile))
    end
    return true
end

-- Install SpoonInstall, then use it to manage EmmyLua
if bootstrapSpoonInstall() then
    hs.loadSpoon("SpoonInstall")

    -- Pin EmmyLua to commit d4b08cb (2024-08-07) - last update
    spoon.SpoonInstall.repos.default = {
        url = "https://github.com/Hammerspoon/Spoons",
        desc = "Main Hammerspoon Spoon Repository (pinned)",
    }

    spoon.SpoonInstall:andUse("EmmyLua", {
        start = true
    })
end

-----------------------------------------------
-- Configuration
-----------------------------------------------
local hyper = { "shift", "ctrl", "alt", "cmd" }
local altCmd = { "ctrl", "cmd" }

-- Timing constants (seconds)
local TIMING = {
    CLIPBOARD_RESTORE_DELAY = 0.3,
    WINDOW_FOCUS_DELAY = 0.15,
    PASTE_DELAY = 0.1,
    WINDOW_CREATE_DELAY = 0.3,
    WINDOW_RESIZE_ANIMATION = 0.2,
    SCREEN_RESIZE_DEBOUNCE = 0.5,
    WINDOW_OPERATION_SLEEP = 50000, -- microseconds
    WHISPER_TIMEOUT = 30,
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
        hs.alert.show(errorMsg or "No active window")
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

-----------------------------------------------
-- Reload config on write
-----------------------------------------------
local function reloadConfig(files)
    log.i("Files changed:", hs.inspect(files))
    local doReload = false
    for _, file in pairs(files) do
        log.i("Checking file:", file)
        if file:sub(-4) == ".lua" then
            log.i("Lua file detected, reloading...")
            doReload = true
            break
        end
    end
    if doReload then
        hs.reload()
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

hs.alert.show("🔨 Hammerspoon Config Loaded", {}, 2)

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
    hs.hotkey.bind(
        hyper,
        key,
        function()
            safeWindowOperation(
                function(window)
                    window:moveToUnit(pos)
                    return true
                end,
                "Cannot resize: no active window"
            )
        end
    )
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
    hs.hotkey.bind(
        altCmd,
        key,
        function()
            safeWindowOperation(
                function(window)
                    window[action](window)
                    return true
                end,
                "Cannot focus window: no active window"
            )
        end
    )
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
local termApp = "Alacritty"
local termBundleID = "org.alacritty"

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
    for _, app in ipairs(hs.application.applicationsForBundleID(termBundleID)) do
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
        os.execute("open -n /Applications/" .. termApp .. ".app")
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
local function moveWindowToDisplay(displays, index)
    return function()
        safeWindowOperation(
            function(window)
                if displays[index] then
                    window:moveToScreen(displays[index], false, true)
                    return true
                else
                    hs.alert.show("Display " .. index .. " not found")
                    return false
                end
            end,
            "Cannot move window: no active window"
        )
    end
end

local displays = hs.screen.allScreens()
for i = 1, #displays do
    hs.hotkey.bind(altCmd, tostring(i), moveWindowToDisplay(displays, i))
end

-----------------------------------------------
-- Insert dates
-----------------------------------------------
local function pasteString(string)
    if not string or string == "" then
        hs.alert.show("Nothing to paste")
        return
    end

    withClipboard(function()
        hs.pasteboard.setContents(string)
        hs.eventtap.keyStrokes(string)
    end)
end

local function pasteDate(dayDiff)
    local now = os.time()
    local diff = dayDiff * 24 * 60 * 60
    local date = now + diff

    local format = "%Y-%m-%d"
    local formattedDate = os.date(format, date)
    pasteString(formattedDate)
end

local function pasteToday() pasteDate(0) end

local function pasteYesterday() pasteDate(-1) end

-- Date shortcuts
hs.hotkey.bind(altCmd, "]", pasteToday)
hs.hotkey.bind(altCmd, "[", pasteYesterday)

-----------------------------------------------
-- Additional Utilities
-----------------------------------------------

-- Show current WiFi network
hs.hotkey.bind(hyper, "w", function()
    local wifi = hs.wifi.currentNetwork()
    if wifi then
        hs.alert.show("WiFi: " .. wifi, {}, 3)
    else
        hs.alert.show("No WiFi connected", {}, 2)
    end
end)

-- Lock screen
hs.hotkey.bind(hyper, "l", function()
    hs.caffeinate.lockScreen()
end)

-- Sleep
hs.hotkey.bind(hyper, "s", function()
    hs.caffeinate.systemSleep()
end)

-----------------------------------------------
-- Speech to text with Whisper
-----------------------------------------------
local whisper = {
    recording = nil,
    task = nil,
    tempFile = os.getenv("HOME") .. "/.hammerspoon_whisper.wav",
    model = os.getenv("HOME") .. "/.local/share/whisper/ggml-base.en.bin",
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
if not whisper.binary or not whisper.sox or not hs.fs.attributes(whisper.model) then
    log.e("Whisper setup failed - missing: " ..
        (whisper.binary and "" or "whisper-cli ") ..
        (whisper.sox and "" or "sox ") ..
        (hs.fs.attributes(whisper.model) and "" or "model"))
end

-- Ctrl+Cmd+D: Toggle recording/transcribe
hs.hotkey.bind(altCmd, "d", function()
    if whisper.recording then
        -- Stop recording and transcribe
        whisper.recording:terminate()
        whisper.recording = nil
        hs.alert.show("🎤 Transcribing...")

        local win = hs.window.focusedWindow()
        local app = hs.application.frontmostApplication()

        -- Timeout after 30s
        local timeout = hs.timer.doAfter(TIMING.WHISPER_TIMEOUT, function()
            if whisper.task then
                whisper.task:terminate()
                whisper.task = nil
                hs.alert.show("❌ Timeout")
            end
        end)

        -- Transcribe
        whisper.task = hs.task.new(whisper.binary, function(code, stdout)
            timeout:stop()
            whisper.task = nil
            pcall(os.remove, whisper.tempFile)

            if code == 0 then
                local text = stdout:gsub("^%s+", ""):gsub("%s+$", "")
                if text ~= "" and not text:match("^%[") then
                    hs.alert.show("✓ " .. text:sub(1, 40) .. (text:len() > 40 and "..." or ""))
                    -- Return to original window and paste
                    if app then app:activate() end
                    hs.timer.doAfter(TIMING.WINDOW_FOCUS_DELAY, function()
                        if win and win:isVisible() then win:focus() end
                        hs.timer.doAfter(TIMING.PASTE_DELAY, function()
                            pasteString(text)
                        end)
                    end)
                else
                    hs.alert.show("❌ No speech\nCheck mic permissions")
                end
            else
                hs.alert.show("❌ Failed (code " .. code .. ")")
            end
        end, { "-m", whisper.model, "-f", whisper.tempFile, "--no-timestamps" }):start()
    else
        -- Start recording
        if not whisper.binary or not whisper.sox then
            hs.alert.show("❌ Whisper not installed")
            return
        end

        pcall(os.remove, whisper.tempFile)
        hs.alert.show("🎤 Recording...")

        whisper.recording = hs.task.new(whisper.sox, function(code)
            if code ~= 0 and code ~= 2 then
                hs.alert.show("❌ Recording failed")
            end
        end, { "-d", "-r", "16000", "-c", "1", whisper.tempFile }):start()
    end
end)

-----------------------------------------------
-- Auto-resize terminals on screen changes
-----------------------------------------------
-- Resizes Alacritty windows proportionally when docking/undocking
-- Focuses window + uses animation to trigger proper resize events
-- Alacritty sends SIGWINCH → tmux auto-resizes (no commands needed)

local resizeDebounceTimer = nil

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
            local windowScreenFrame = windowScreen:frame()
            local oldFrame = window:frame()

            -- Check if window matches one of our managed terminal configs
            local matchedConfig = nil
            for configName, config in pairs(terminalConfigs) do
                local unit = oldFrame:toUnitRect(windowScreenFrame)
                if unit:equals(hs.geometry(config.frame)) then
                    matchedConfig = { name = configName, config = config }
                    break
                end
            end

            if matchedConfig then
                -- Managed window: move to main screen if needed, then maintain exact size
                if windowScreen:id() ~= currentScreen:id() then
                    log.i("Window", i, "is managed", matchedConfig.name, "- moving to main screen")
                    window:moveToScreen(currentScreen, false, true)
                    hs.timer.usleep(TIMING.WINDOW_OPERATION_SLEEP)
                end

                log.i("Window", i, "ensuring correct", matchedConfig.name, "size")
                window:focus()
                hs.timer.usleep(TIMING.WINDOW_OPERATION_SLEEP)
                window:moveToUnit(matchedConfig.config.frame)
                resizedCount = resizedCount + 1

            elseif windowScreen:id() ~= currentScreen:id() then
                -- Unknown window moving between screens: proportional resize
                log.i("Resizing window", i, "from", windowScreenFrame.w, "x", windowScreenFrame.h, "to", screenFrame.w, "x", screenFrame.h)

                -- Calculate proportional position and size
                local xRatio = oldFrame.x / windowScreenFrame.w
                local yRatio = oldFrame.y / windowScreenFrame.h
                local wRatio = oldFrame.w / windowScreenFrame.w
                local hRatio = oldFrame.h / windowScreenFrame.h

                local targetFrame = {
                    x = screenFrame.x + (xRatio * screenFrame.w),
                    y = screenFrame.y + (yRatio * screenFrame.h),
                    w = wRatio * screenFrame.w,
                    h = hRatio * screenFrame.h
                }

                -- Focus window first (required for events)
                window:focus()
                hs.timer.usleep(TIMING.WINDOW_OPERATION_SLEEP)

                -- Use animated resize to trigger proper events
                window:setFrame(targetFrame, TIMING.WINDOW_RESIZE_ANIMATION)
                resizedCount = resizedCount + 1
            end
        end
    end

    if resizedCount > 0 then
        hs.alert.show(string.format("Resized %d terminal%s", resizedCount, resizedCount > 1 and "s" or ""), 1)
        log.i("Resized", resizedCount, "terminal window(s)")
    end
end

local function debouncedResizeTerminals()
    if resizeDebounceTimer then
        resizeDebounceTimer:stop()
    end
    resizeDebounceTimer = hs.timer.doAfter(TIMING.SCREEN_RESIZE_DEBOUNCE, resizeTerminals)
end

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
        hs.alert.show("🛑 Shutdown cancelled")
    end
end

if shutdownConfig.enabled then
    shutdownTimer = hs.timer.doAt(
        string.format("%02d:%02d", shutdownConfig.hour, shutdownConfig.minute),
        function()
            hs.alert.show("💤 Good night!")
            hs.timer.doAfter(2, hs.caffeinate.systemSleep)
        end
    )
end

hs.hotkey.bind(hyper, "p", cancelShutdown)
