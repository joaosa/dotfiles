-----------------------------------------------
-- Window Management (Resize, Focus, Move)
-----------------------------------------------

local keys = require("config.keybindings")
local windowLib = require("lib.window")
local hyper = keys.hyper
local altCmd = keys.altCmd
local bindWindowOp = windowLib.bindWindowOp


-- Window frame definitions
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

local function setup()
    -- Window resizing: hyper + d/g/f/r/t/c/v/s/x
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
        end, "Cannot resize: no active window")
    end

    -- Window hints: altCmd + -
    hs.hotkey.bind(altCmd, "-", hs.hints.windowHints)

    -- Window focus: altCmd + h/j/k/l
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
        end, "Cannot focus window: no active window")
    end

    -- Move to display: altCmd + 1/2/3/...
    for i = 1, 9 do
        bindWindowOp(altCmd, tostring(i), function(window)
            local displays = hs.screen.allScreens()
            if displays[i] then
                window:moveToScreen(displays[i], false, true)
                return true
            else
                hs.alert.show(string.format("Display %d not found", i))
                return false
            end
        end, "Cannot move window: no active window")
    end
end

return {
    setup = setup,
    frames = frames, -- Export frames for use by terminal module
}
