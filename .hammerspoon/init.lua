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
-- Open console
-----------------------------------------------
hs.hotkey.bind(altCmd, 'c', hs.openConsole)

-----------------------------------------------
-- hyper + x key for window resizing
-----------------------------------------------
function resizeWindow(fn)
  return function()
    local window = hs.window.focusedWindow()
    local frame = window:frame()
    local screen = window:screen()
    local max = screen:frame()

    local changes = fn(max)
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
  hs.hotkey.bind(hyper, key, resizeWindow(position))
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
  w = 'Google Chrome Canary',
  l = 'Slack',
  q = 'iTerm',
  i = 'Spotify'
}

for key, appName in pairs(appBindings) do
  hs.hotkey.bind(altCmd, key, function()
    hs.application.launchOrFocus(appName)
  end)
end

-----------------------------------------------
-- Open/Focus Finder
-----------------------------------------------
hs.hotkey.bind(altCmd, 'n', function() os.execute('open ~') end)

-----------------------------------------------
-- Change language
-- http://stackoverflow.com/a/23741934
-----------------------------------------------
local getLanguage = hs.fnutils.cycle({
  'U.S.',
  'Portuguese'
})

hs.hotkey.bind(hyper, "space", function()
  script = [[
  set theInputSource to "%s"
  tell application "System Events" to tell process "SystemUIServer"
    click (menu bar item 1 of menu bar 1 whose description is "text input")
    click menu item theInputSource of menu 1 of result
  end tell
  ]]

  local language = getLanguage()
  -- local handle = io.popen([[
  -- defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputHistory | egrep -w 'KeyboardLayout Name'
  -- ]])
  -- local language = handle:read('*a')
  -- hs.alert(tostring(language))
  hs.applescript.applescript(script:format(language))
end)
