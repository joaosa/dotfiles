-----------------------------------------------
-- NAV mode: Vimium-style navigation outside text fields, plus element hints.
-- altCmd+. (or f in NAV) labels every clickable element in the focused window;
-- type the label to AXPress it (mouse-click fallback). esc or a click cancels.
-----------------------------------------------

local keys = require("config.keybindings")
local altCmd = keys.altCmd

local ax = require("hs.axuielement")
local log = hs.logger.new("element-hints", "info")

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

local function cancelHints()
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

local function hintsActive() return state.canvas ~= nil end

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
        if visited >= MAX_VISITED then
            return
        end
        visited = visited + 1

        -- One IPC round-trip per node instead of one per attribute
        local ok, attrs = pcall(function() return el:allAttributeValues() end)
        if not ok or not attrs then
            return
        end

        local frame = attrs.AXFrame
        local visible = frame and frame.w > 2 and frame.h > 2 and hs.geometry(frame):intersect(winFrame).area > 0
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
    return hs.fnutils.filter(state.hints, function(hint) return hint.label:sub(1, #state.typed) == state.typed end)
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

local function render(hints) state.canvas:replaceElements(canvasElements(hints)) end

local function startTap()
    local types = hs.eventtap.event.types
    state.tap = hs.eventtap.new({ types.keyDown, types.leftMouseDown }, function(ev)
        if ev:getType() == types.leftMouseDown then
            cancelHints()
            return false -- let the click through
        end

        local key = hs.keycodes.map[ev:getKeyCode()]
        if key == "escape" then
            cancelHints()
        elseif key == "delete" then
            state.typed = state.typed:sub(1, -2)
            render(matching())
        elseif type(key) == "string" and #key == 1 and HINT_CHARS:find(key, 1, true) then
            state.typed = state.typed .. key
            local m = matching()
            if #m == 0 then
                cancelHints()
            elseif #m == 1 and m[1].label == state.typed then
                cancelHints()
                press(m[1])
            else
                render(m)
            end
        end
        return true -- consume keys while hints are up
    end)
    state.tap:start()
end

local function showHints()
    cancelHints()

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
    log.i(
        string.format(
            "found %d clickable of %d visited in %.2fs",
            #found,
            visited,
            hs.timer.secondsSinceEpoch() - started
        )
    )

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

-----------------------------------------------
-- NAV modal
-----------------------------------------------

local ax = require("lib.ax")

local BADGE = { w = 125, h = 25 }

-- hs.hotkey.modal intercepts only the keys bound below; everything else reaches the app.
-- Module-level so the modal, badge and click tap are not garbage collected.
local nav = {
    active = false,
    modal = hs.hotkey.modal.new(),
    badge = nil,
    clickTap = nil,
    pendingG = false,
    pendingGTimer = nil,
}

local function clearPendingG()
    nav.pendingG = false
    if nav.pendingGTimer then
        nav.pendingGTimer:stop()
        nav.pendingGTimer = nil
    end
end

local function badge()
    if nav.badge then
        return nav.badge
    end
    nav.badge = hs.canvas.new({ x = 0, y = 0, w = BADGE.w, h = BADGE.h })
    nav.badge:appendElements({
        type = "rectangle",
        action = "fill",
        roundedRectRadii = { xRadius = 2, yRadius = 2 },
        fillColor = { red = 76 / 255, green = 175 / 255, blue = 80 / 255, alpha = 0.95 },
        strokeColor = { white = 1.0 },
        strokeWidth = 3.0,
        withShadow = true,
    }, {
        type = "text",
        text = hs.styledtext.new("NAV", { font = { name = "Courier New", size = 14 }, color = { white = 1.0 } }),
        frame = { x = "5%", y = "10%", h = "100%", w = "95%" },
    })
    nav.badge:level("overlay")
    return nav.badge
end

local function showBadge()
    local frame = hs.screen.mainScreen():frame()
    badge():topLeft({ x = frame.x + (frame.w - BADGE.w) / 2, y = frame.y + frame.h - BADGE.h * 1.5 }):show()
end

local function exit()
    if not nav.active then
        return
    end
    nav.active = false
    clearPendingG()
    nav.modal:exit()
    if nav.clickTap then
        nav.clickTap:stop()
        nav.clickTap = nil
    end
    if nav.badge then
        nav.badge:hide()
    end
end

local function enter()
    if nav.active then
        return
    end
    cancelHints()
    nav.active = true
    nav.modal:enter()
    -- Clicking means mouse navigation; leave NAV and let the click through.
    nav.clickTap = hs.eventtap.new({ hs.eventtap.event.types.leftMouseDown }, function()
        exit()
        return false
    end)
    nav.clickTap:start()
    showBadge()
end

local function toggle()
    if nav.active then
        exit()
    else
        enter()
    end
end

local function isActive() return nav.active end

local function stroke(mods, key) hs.eventtap.keyStroke(mods, key, 0) end

-- Wraps a NAV action: if a text field has quietly taken focus (the spoon's observer misses this in
-- Electron apps) leave NAV and re-post the key so the app receives it; otherwise run the action.
local function action(mods, key, fn)
    return function()
        if ax.focusedTextField() then
            exit()
            stroke(mods, key)
            return
        end
        if key ~= "g" then
            clearPendingG()
        end
        fn()
    end
end

local function bindRepeat(mods, key, fn)
    local wrapped = action(mods, key, fn)
    nav.modal:bind(mods, key, wrapped, nil, wrapped)
end

local function bind(mods, key, fn) nav.modal:bind(mods, key, action(mods, key, fn)) end

-- Scrolling via arrow and page keys so it doubles as list navigation in Finder, Mail and Slack.
bindRepeat({}, "j", function() stroke({}, "down") end)
bindRepeat({}, "k", function() stroke({}, "up") end)
bindRepeat({}, "h", function() stroke({}, "left") end)
bindRepeat({}, "l", function() stroke({}, "right") end)
bindRepeat({}, "d", function() stroke({}, "pagedown") end)
bindRepeat({}, "u", function() stroke({}, "pageup") end)
-- Exit keys bypass the self-check so they never re-post into a field; escape is re-sent so the app
-- sees it too, matching the caps path where Karabiner's escape passes through.
nav.modal:bind({}, "i", exit)
nav.modal:bind({}, "escape", function()
    exit()
    stroke({}, "escape")
end)

local function setup() hs.hotkey.bind(altCmd, ".", showHints) end

return {
    setup = setup,
    showHints = showHints,
    cancelHints = cancelHints,
    hintsActive = hintsActive,
    enter = enter,
    exit = exit,
    toggle = toggle,
    isActive = isActive,
}
