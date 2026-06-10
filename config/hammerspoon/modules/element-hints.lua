-----------------------------------------------
-- Element Hints (vimium-style click targets)
-- altCmd+. labels every clickable element in the focused window; type the
-- label to AXPress it (mouse-click fallback). esc cancels, backspace edits.
-----------------------------------------------

local keys = require("config.keybindings")
local altCmd = keys.altCmd

local ax = require("hs.axuielement")
local log = hs.logger.new('element-hints', 'info')

local HINT_CHARS = "asdfghjklqwertyuiopzxcvbnm"
-- Traversal budgets so huge accessibility trees (Electron) stay responsive
local MAX_VISITED = 2500
local MAX_DEPTH = 60

-- Module-level state; also keeps the canvas and eventtap referenced so they
-- are not garbage-collected while active.
local state = {
    canvas = nil,
    tap = nil,
    hints = {},
    typed = "",
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
end

-- Fixed-length labels (no label is a prefix of another)
local function makeLabels(n)
    local len = 1
    while (#HINT_CHARS) ^ len < n do
        len = len + 1
    end
    local labels = {}
    local function gen(prefix)
        if #labels >= n then return end
        if #prefix == len then
            labels[#labels + 1] = prefix
            return
        end
        for i = 1, #HINT_CHARS do
            gen(prefix .. HINT_CHARS:sub(i, i))
        end
    end
    gen("")
    return labels
end

local function isPressable(el)
    local ok, actions = pcall(function() return el:actionNames() end)
    if not ok or not actions then return false end
    for _, action in ipairs(actions) do
        if action == "AXPress" then return true end
    end
    return false
end

local function collectClickable(winEl, winFrame)
    local found = {}
    local visited = 0
    local function walk(el, depth)
        if visited >= MAX_VISITED or depth > MAX_DEPTH then return end
        visited = visited + 1

        local frame = el:attributeValue("AXFrame")
        local visible = frame and frame.w > 2 and frame.h > 2
            and hs.geometry(frame):intersect(winFrame).area > 0
        if visible and isPressable(el) then
            found[#found + 1] = { element = el, frame = frame }
        end

        local children = el:attributeValue("AXChildren")
        if children then
            for _, child in ipairs(children) do
                walk(child, depth + 1)
            end
        end
    end
    walk(winEl, 0)
    return found, visited
end

local function press(hint)
    local pressed = pcall(function() return hint.element:performAction("AXPress") end)
    if not pressed then
        local f = hint.frame
        hs.eventtap.leftClick({ x = f.x + f.w / 2, y = f.y + f.h / 2 })
    end
end

local function canvasElements(screenFrame)
    local elements = {}
    for _, hint in ipairs(state.hints) do
        if hint.label:sub(1, #state.typed) == state.typed then
            local x = hint.frame.x - screenFrame.x
            local y = hint.frame.y - screenFrame.y
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
    end
    return elements
end

local function render(screenFrame)
    state.canvas:replaceElements(canvasElements(screenFrame))
end

local function matchingCount()
    local count = 0
    for _, hint in ipairs(state.hints) do
        if hint.label:sub(1, #state.typed) == state.typed then
            count = count + 1
        end
    end
    return count
end

local function startTap(screenFrame)
    state.tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(ev)
        local key = hs.keycodes.map[ev:getKeyCode()]
        if key == "escape" then
            cancel()
        elseif key == "delete" then
            state.typed = state.typed:sub(1, -2)
            render(screenFrame)
        elseif type(key) == "string" and #key == 1 and HINT_CHARS:find(key, 1, true) then
            state.typed = state.typed .. key
            for _, hint in ipairs(state.hints) do
                if hint.label == state.typed then
                    cancel()
                    press(hint)
                    return true
                end
            end
            if matchingCount() == 0 then
                cancel()
            else
                render(screenFrame)
            end
        end
        return true -- consume everything while hints are up
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

    local screenFrame = win:screen():frame()
    state.canvas = hs.canvas.new(screenFrame)
    render(screenFrame)
    state.canvas:show()
    startTap(screenFrame)
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
