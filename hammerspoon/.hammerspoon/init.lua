-----------------------------------------------
-- Configuration
-----------------------------------------------
local hyper = { "shift", "ctrl", "alt", "cmd" }
local altCmd = { "ctrl", "cmd" }
local doAfter = 0.5

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
local realPath = hs.execute("readlink " .. configPath):gsub("\n", "")
if realPath ~= "" then
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
    hs.hotkey.bind(
        altCmd,
        key,
        function()
            local app = hs.application.find(appName)
            if app and app:isRunning() then
                app:activate()
            else
                hs.application.launchOrFocus(appName)
            end
        end
    )
end

-----------------------------------------------
-- Have a pulldown term experience
-----------------------------------------------
local function findAppPID(appName)
    return string.format(
        [[ps -ax -o etime,pid,command \
  | grep  %s \
  | grep -v grep \
  | sort \
  | awk '{print $2}' \
  | head -n1
  ]],
        appName:lower()
    )
end

local function launchApp(appName, callback)
    os.execute("open -nF /Applications/" .. appName .. ".app")
    hs.timer.doAfter(
        doAfter,
        function()
            local cmd = findAppPID(appName)
            local output, status = hs.execute(cmd)
            if status then
                return callback(tonumber(output))
            end
        end
    )
end

local function handleWindowState(appName, frame)
    local screenFrame = hs.screen.mainScreen():frame()
    local apps = { hs.application(appName) }

    -- find if we have an app with a window with the target size
    for i = 1, #apps do
        local app = apps[i]
        local w = app:mainWindow()
        if not w then
            return false
        end
        local unit = w:frame():toUnitRect(screenFrame)

        -- handle the window visiblity
        -- if there's a frame with the target size
        if unit:equals(hs.geometry(frame)) then
            if app:isHidden() then
                app:activate()
            else
                app:hide()
            end
            return true
        end
    end
    return false
end

local function handleTermApp(appName, frame)
    -- process the windows we have and set them right
    -- if we manage to do that then we're good
    if handleWindowState(appName, frame) then
        return
    end

    -- otherwise we need to spawn a new app
    -- and resize its window
    launchApp(
        appName,
        function(pid)
            local app = hs.application(pid)
            if app then
                app:mainWindow():moveToUnit(frame)
            end
        end
    )
end

local termApp = "Alacritty"
-- spawn fullscreen
hs.hotkey.bind(
    { "alt" },
    "space",
    function()
        handleTermApp(termApp, frames.pulldown)
    end
)
-- spawn pulldown
hs.hotkey.bind(
    altCmd,
    "a",
    function()
        handleTermApp(termApp, frames.full)
    end
)

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

    local current = hs.pasteboard.getContents()
    hs.pasteboard.setContents(string)
    hs.eventtap.keyStrokes(string)

    -- Restore previous clipboard content after a delay
    hs.timer.doAfter(0.1, function()
        if current then
            hs.pasteboard.setContents(current)
        end
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
do
    -- Find whisper-cli
    local paths = {
        "/opt/homebrew/bin/whisper-cli",
        "/usr/local/bin/whisper-cli",
    }
    for _, path in ipairs(paths) do
        if hs.fs.attributes(path) then
            whisper.binary = path
            break
        end
    end

    -- Fallback: search Cellar
    if not whisper.binary then
        local result = hs.execute(
            "find /opt/homebrew/Cellar/whisper-cpp -name whisper-cli -type f 2>/dev/null | head -1")
        if result and result ~= "" then
            whisper.binary = result:gsub("\n", "")
        end
    end

    -- Find sox
    whisper.sox = hs.fs.attributes("/opt/homebrew/bin/sox") and "/opt/homebrew/bin/sox" or
        hs.fs.attributes("/usr/local/bin/sox") and "/usr/local/bin/sox" or nil

    -- Validate
    if not whisper.binary or not whisper.sox or not hs.fs.attributes(whisper.model) then
        log.e("Whisper setup failed - missing: " ..
            (whisper.binary and "" or "whisper-cli ") ..
            (whisper.sox and "" or "sox ") ..
            (hs.fs.attributes(whisper.model) and "" or "model"))
    end
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
        local clip = hs.pasteboard.getContents()

        -- Timeout after 30s
        local timeout = hs.timer.doAfter(30, function()
            if whisper.task then
                whisper.task:terminate()
                whisper.task = nil
                hs.alert.show("❌ Timeout")
            end
        end)

        -- Transcribe
        whisper.task = hs.task.new(whisper.binary, function(code, stdout, stderr)
            timeout:stop()
            whisper.task = nil
            pcall(os.remove, whisper.tempFile)

            if code == 0 then
                local text = stdout:gsub("^%s+", ""):gsub("%s+$", "")
                if text ~= "" and not text:match("^%[") then
                    hs.alert.show("✓ " .. text:sub(1, 40) .. (text:len() > 40 and "..." or ""))
                    -- Use existing pasteString helper
                    if app then app:activate() end
                    hs.timer.doAfter(0.15, function()
                        if win and win:isVisible() then win:focus() end
                        hs.timer.doAfter(0.1, function()
                            pasteString(text)
                            -- Restore clipboard
                            if clip and clip ~= "" then
                                hs.timer.doAfter(0.3, function()
                                    hs.pasteboard.setContents(clip)
                                end)
                            end
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

        whisper.recording = hs.task.new(whisper.sox, function(code, stdout, stderr)
            if code ~= 0 and code ~= 2 then
                hs.alert.show("❌ Recording failed")
            end
        end, { "-d", "-r", "16000", "-c", "1", whisper.tempFile }):start()
    end
end)
