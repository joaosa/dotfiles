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
function resizeWindow(windowGetter, transform)
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

for key, position in pairs(windowPositionBindings) do
  hs.hotkey.bind(hyper, key, resizeWindow(hs.window.focusedWindow, position))
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
  q = 'iTerm',
  l = 'Spotify'
}

for key, appName in pairs(appBindings) do
  hs.hotkey.bind(altCmd, key, function()
    hs.application.launchOrFocus(appName)
  end)
end

-----------------------------------------------
-- Insert dates
-----------------------------------------------
function pasteString(string)
  local current = hs.pasteboard.getContents()

  hs.pasteboard.setContents(string)
  hs.eventtap.keyStrokes(hs.pasteboard.getContents())

  hs.pasteboard.setContents(current)
end
function pasteDate(dayDiff)
  now = os.time()
  diff = dayDiff * 24 * 60 * 60
  date = now + diff

  format = "%Y/%m/%d"
  formattedDate = os.date(format, date)
  pasteString(formattedDate)
end

-- https://eastmanreference.com/complete-list-of-applescript-key-codes
local keyCodes = {18, 19, 20, 21, 23, 22, 26, 28}
for index, keyCode in ipairs(keyCodes) do
  hs.hotkey.bind(altCmd, keyCode, function() pasteDate(index) end)
end
function pasteToday() pasteDate(0) end
hs.hotkey.bind(altCmd, ']', pasteToday)
