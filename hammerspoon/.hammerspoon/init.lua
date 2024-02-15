-----------------------------------------------
-- Set up
-----------------------------------------------
local hyper = { "shift", "ctrl", "alt", "cmd" }
local altCmd = { "ctrl", "cmd" }
local doAfter = 0.5
hs.window.animationDuration = 0

-----------------------------------------------
-- Reload config on write
-----------------------------------------------
local _ = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", hs.reload):start()
hs.alert.show("Config loaded")

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
            local window = hs.window.focusedWindow()
            window:moveToUnit(pos)
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
            local window = hs.window.focusedWindow()
            if window then
                window[action](window)
            else
                hs.alert.show("No active window")
            end
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
            hs.application.launchOrFocus(appName)
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
  ]]     ,
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
        local win = hs.window.focusedWindow()
        win:moveToScreen(displays[index], false, true)
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
    local current = hs.pasteboard.getContents()

    hs.pasteboard.setContents(string)
    hs.eventtap.keyStrokes(hs.pasteboard.getContents())

    hs.pasteboard.setContents(current)
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

hs.hotkey.bind(altCmd, "]", pasteToday)
hs.hotkey.bind(altCmd, "[", pasteYesterday)
