-----------------------------------------------
-- Set up
-----------------------------------------------
local hyper = {'shift', 'ctrl', 'alt', 'cmd'}
local altCmd = {'ctrl', 'cmd'}
hs.window.animationDuration = 0;

-----------------------------------------------
-- Reload config on write
-----------------------------------------------
hs.pathwatcher.new(os.getenv('HOME') .. '/.hammerspoon/', hs.reload):start()
hs.alert.show('Config loaded')

-----------------------------------------------
-- Open the hammerspoon console
-----------------------------------------------
hs.hotkey.bind(altCmd, 'x', hs.openConsole)

-----------------------------------------------
-- hyper + x key for window resizing
-----------------------------------------------
local function resizeWindow(windowGetter, transform)
  return function()
    local window = windowGetter()
    local frame = window:frame()
    local screen = window:screen()
    local max = screen:frame()

    local changes = transform(max)
    frame.x = changes.x
    frame.y = changes.y
    frame.w = changes.w
    frame.h = changes.h

    window:setFrame(frame)
  end
end

local position = {
  rightTopQuarter = function(max)
    return { x = max.x + (max.w / 2), y = max.y, w = max.w / 2, h = max.h / 2 }
  end,
  leftBottomQuarter = function(max)
    return { x = max.x + (max.w / 2), y = max.y + (max.h / 2), w = max.w / 2, h = max.h / 2 }
  end,
  rightBottomQuarter = function(max)
    return { x = max.x, y = max.y + (max.h / 2), w = max.w / 2, h = max.h / 2 }
  end,
  leftTopQuarter = function(max)
    return { x = max.x, y = max.y, w = max.w / 2, h = max.h / 2 }
  end,
  full = function(max)
    return { x = max.x, y = max.y, w = max.w, h = max.h }
  end,
  rightHalf = function(max)
    return { x = max.x + (max.w / 2), y = max.y, w = max.w / 2, h = max.h }
  end,
  leftHalf = function(max)
    return { x = max.x, y = max.y, w = max.w / 2, h = max.h }
  end,
  guake = function(max)
    return { x = 0, y = 0, w = max.w, h = max.h / 2.2 }
  end
}

local windowPositionBindings = {
  d = position.leftHalf,
  g = position.rightHalf,
  f = position.full,
  r = position.leftTopQuarter,
  t = position.rightTopQuarter,
  v = position.leftBottomQuarter,
  c = position.rightBottomQuarter
}

for key, pos in pairs(windowPositionBindings) do
  hs.hotkey.bind(hyper, key, resizeWindow(hs.window.focusedWindow, pos))
end

-----------------------------------------------
-- Hyper i to show window hints
-----------------------------------------------
hs.hotkey.bind(hyper, 'i', hs.hints.windowHints)

-----------------------------------------------
-- Hyper hjkl to switch window focus
-----------------------------------------------
local windowFocusBindings = {
  k = 'focusWindowNorth',
  j = 'focusWindowSouth',
  l = 'focusWindowEast',
  h = 'focusWindowWest'
}

for key, action in pairs(windowFocusBindings) do
  hs.hotkey.bind(hyper, key, function()
    local window = hs.window.focusedWindow()
    if window then
      window[action](window)
    else
      hs.alert.show("No active window")
    end
  end)
end

-----------------------------------------------
-- Move to app
-----------------------------------------------
local appBindings = {
  e = 'Evernote',
  w = 'Firefox Developer Edition',
  i = 'Slack',
  l = 'Spotify'
}

for key, appName in pairs(appBindings) do
  hs.hotkey.bind(altCmd, key, function()
    hs.application.launchOrFocus(appName)
  end)
end

-----------------------------------------------
-- Have a pulldown term experience
-----------------------------------------------
local function findAppPID(appName)
  return string.format([[ps -ax -o etime,pid,command \
  | grep  %s \
  | grep -v grep \
  | sort \
  | awk '{print $2}' \
  | head -n1
  ]], appName:lower())
end
local function launchApp(appName, callback)
  os.execute("open -nF /Applications/" .. appName .. ".app")
  hs.timer.doAfter(0.5, function ()
    local cmd = findAppPID(appName)
    print(cmd)
    local output, status = hs.execute(cmd)
    if status then
      return callback(tonumber(output))
    end
  end)
end

local function handleWindowState(appName, frame)
  local screenFrame = hs.screen.mainScreen():frame()
  local apps = {hs.application(appName)}

  -- find if we have an app with a window with the target size
  for i = 1, #apps do
    local app = apps[i]
    -- workaround getting windows from other apps with the same name
    if not app.name then
      return false
    end

    local w = app:mainWindow()
    local unit = w:frame():toUnitRect(screenFrame)

    -- handle the window visiblity
    -- if there's a frame with the target size
    if unit:equals(hs.geometry(frame)) then
      if app:isFrontmost() then
        app:hide()
      else
        app:activate()
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
  launchApp(appName, function (pid)
    local app = hs.application(pid)
    if app then
      app:mainWindow():moveToUnit(frame)
    end
  end)
end

local termApp = 'Alacritty'
local frames = {'[100,40,0,0]', '[100,100,0,0]'}
-- spawn fullscreen
hs.hotkey.bind({"alt"}, "space", function() handleTermApp(termApp, frames[1]) end)
-- spawn pulldown
hs.hotkey.bind(altCmd, "q", function() handleTermApp(termApp, frames[2]) end)

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

  local format = "%Y/%m/%d"
  local formattedDate = os.date(format, date)
  pasteString(formattedDate)
end

-- https://eastmanreference.com/complete-list-of-applescript-key-codes
local keyCodes = {18, 19, 20, 21, 23, 22, 26, 28}
for index, keyCode in ipairs(keyCodes) do
  hs.hotkey.bind(altCmd, keyCode, function() pasteDate(index) end)
end
local function pasteToday() pasteDate(0) end
hs.hotkey.bind(altCmd, ']', pasteToday)
