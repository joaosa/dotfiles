-----------------------------------------------
-- System-wide Vim Mode (VimMode.spoon)
-----------------------------------------------

local log = hs.logger.new("vim", "info")
local ax = require("lib.ax")
local nav = require("modules.nav")

-- Kept at module scope so the watchers are not garbage collected.
local appWatcher, keyTap

local function setup()
    local ok, VimMode = pcall(hs.loadSpoon, "VimMode")
    if not ok then
        log.e("VimMode.spoon not installed - run make switch")
        return
    end

    local vim = VimMode:new()

    -- Apps with native vim bindings; the spoon's app watcher clears vim.enabled while they are frontmost.
    vim:disableForApp("Alacritty")
    vim:disableForApp("Obsidian")
    vim:disableForApp("Firefox Developer Edition")

    -- Karabiner sends f17 then escape on a lone caps_lock tap; the tap sees both in order before any app.
    -- f17 is always consumed. In a disabled app or while the spoon is already in normal/visual mode the
    -- escape passes through untouched. In a text field: enter NORMAL and swallow the escape (Slack closes
    -- a thread on escape). Anywhere else: toggle NAV; entering swallows the escape (the modal's own escape
    -- binding would exit again at once), leaving lets it through so a caps tap still dismisses popovers.
    local swallowEscape = false
    local f17, escape = hs.keycodes.map.f17, hs.keycodes.map.escape
    keyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
        local key = event:getKeyCode()
        if key == f17 then
            swallowEscape = false
            if vim.enabled and vim:isMode("insert") then
                if ax.focusedTextField() then
                    nav.exit()
                    vim:enter()
                    swallowEscape = true
                else
                    swallowEscape = not nav.isActive()
                    nav.toggle()
                end
            end
            return true
        end
        local swallow = swallowEscape and key == escape
        swallowEscape = false
        return swallow
    end)
    keyTap:start()

    -- The spoon only leaves normal mode on a focus change inside the app, and that observer fails for
    -- Electron apps, so a stray mode would follow an app switch. Both exits are no-ops when inactive.
    appWatcher = hs.application.watcher.new(function(_, event)
        if event == hs.application.watcher.activated then
            vim:exit()
            nav.exit()
        end
    end)
    appWatcher:start()
end

return { setup = setup }
