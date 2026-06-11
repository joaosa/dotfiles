-----------------------------------------------
-- Element Hints (vimium-style click targets)
-- altCmd+. labels every clickable element in the focused window; type the
-- label to AXPress it (mouse-click fallback). esc or a mouse click cancels,
-- backspace edits.
-----------------------------------------------

local keys = require("config.keybindings")
local altCmd = keys.altCmd

local ax = require("hs.axuielement")
local log = hs.logger.new('element-hints', 'info')

local HINT_CHARS = "asdfghjklqwertyuiopzxcvbnm"
-- Traversal budget so huge accessibility trees (Electron) stay responsive
local MAX_VISITED = 2500

-- Module-level state; also keeps the canvas and eventtap referenced so they
-- are not garbage-collected while active.
local state = {
    canvas = nil,
    tap = nil,
    hints = {},
    typed = "",
    screenFrame = nil,
}

local function cancel()
    if state.canvas then
        state.canvas:delete()
        state.canvas = nil
    end
    if state.tap then
        state.tap:stop()
        state.tap = nil
    end
    state.hints = {}
    state.typed = ""
    state.screenFrame = nil
end

-- Fixed-length labels (no label is a prefix of another): each index encoded
-- as `len` base-#HINT_CHARS digits.
local function makeLabels(n)
    local base = #HINT_CHARS
    local len = 1
    while base ^ len < n do
        len = len + 1
    end
    local labels = {}
    for i = 0, n - 1 do
        local label, v = "", i
        for _ = 1, len do
            label = HINT_CHARS:sub(v % base + 1, v % base + 1) .. label
            v = math.floor(v / base)
        end
        labels[i + 1] = label
    end
    return labels
end

local function isPressable(el)
    local ok, actions = pcall(function() return el:actionNames() end)
    return ok and actions ~= nil and hs.fnutils.contains(actions, "AXPress")
end

local function collectClickable(winEl, winFrame)
    local found = {}
    local visited = 0
    local function walk(el)
        if visited >= MAX_VISITED then return end
        visited = visited + 1

        -- One IPC round-trip per node instead of one per attribute
        local ok, attrs = pcall(function() return el:allAttributeValues() end)
        if not ok or not attrs then return end

        local frame = attrs.AXFrame
        local visible = frame and frame.w > 2 and frame.h > 2
            and hs.geometry(frame):intersect(winFrame).area > 0
        if visible and isPressable(el) then
            found[#found + 1] = { element = el, frame = frame }
        end

        for _, child in ipairs(attrs.AXChildren or {}) do
            walk(child)
        end
    end
    walk(winEl)
    return found, visited
end

local function press(hint)
    local pressed = pcall(function() return hint.element:performAction("AXPress") end)
    if not pressed then
        hs.eventtap.leftClick(hs.geometry(hint.frame).center)
    end
end

-- Hints whose labels start with the typed prefix
local function matching()
    return hs.fnutils.filter(state.hints, function(hint)
        return hint.label:sub(1, #state.typed) == state.typed
    end)
end

local function canvasElements(hints)
    local elements = {}
    for _, hint in ipairs(hints) do
        local x = hint.frame.x - state.screenFrame.x
        local y = hint.frame.y - state.screenFrame.y
        local w = 8 + 9 * #hint.label
        elements[#elements + 1] = {
            type = "rectangle",
            action = "fill",
            fillColor = { red = 1, green = 0.85, blue = 0.3, alpha = 0.95 },
            roundedRectRadii = { xRadius = 3, yRadius = 3 },
            frame = { x = x, y = y, w = w, h = 16 },
        }
        elements[#elements + 1] = {
            type = "text",
            text = hint.label:upper(),
            textColor = { black = 1 },
            textSize = 11,
            textAlignment = "center",
            frame = { x = x, y = y + 1, w = w, h = 14 },
        }
    end
    return elements
end

local function render(hints)
    state.canvas:replaceElements(canvasElements(hints))
end

local function startTap()
    local types = hs.eventtap.event.types
    state.tap = hs.eventtap.new({ types.keyDown, types.leftMouseDown }, function(ev)
        if ev:getType() == types.leftMouseDown then
            cancel()
            return false -- let the click through
        end

        local key = hs.keycodes.map[ev:getKeyCode()]
        if key == "escape" then
            cancel()
        elseif key == "delete" then
            state.typed = state.typed:sub(1, -2)
            render(matching())
        elseif type(key) == "string" and #key == 1 and HINT_CHARS:find(key, 1, true) then
            state.typed = state.typed .. key
            local m = matching()
            if #m == 0 then
                cancel()
            elseif #m == 1 and m[1].label == state.typed then
                cancel()
                press(m[1])
            else
                render(m)
            end
        end
        return true -- consume keys while hints are up
    end)
    state.tap:start()
end

local function show()
    cancel()

    local win = hs.window.focusedWindow()
    if not win then
        hs.alert.show("No focused window")
        return 0
    end

    -- Wake up accessibility trees in Electron apps before walking
    local app = win:application()
    local appEl = ax.applicationElement(app)
    pcall(function() appEl:setAttributeValue("AXManualAccessibility", true) end)

    local started = hs.timer.secondsSinceEpoch()
    local winFrame = hs.geometry(win:frame())
    local found, visited = collectClickable(ax.windowElement(win), winFrame)
    log.i(string.format("found %d clickable of %d visited in %.2fs",
        #found, visited, hs.timer.secondsSinceEpoch() - started))

    if #found == 0 then
        hs.alert.show("No clickable elements")
        return 0
    end

    local labels = makeLabels(#found)
    state.hints = found
    for i, hint in ipairs(state.hints) do
        hint.label = labels[i]
    end

    state.screenFrame = win:screen():frame()
    state.canvas = hs.canvas.new(state.screenFrame)
    render(state.hints)
    state.canvas:show()
    startTap()
    return #found
end

local function setup()
    hs.hotkey.bind(altCmd, ".", show)
end

return {
    setup = setup,
    show = show,
    cancel = cancel,
}
