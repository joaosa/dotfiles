-----------------------------------------------
-- System-wide Vim Mode (VimMode.spoon)
-----------------------------------------------

local log = hs.logger.new("vim", "info")
local ax = require("lib.ax")

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

    -- Karabiner sends f17 then escape on a lone caps_lock tap. The tap sees both in order before any app:
    -- f17 is always consumed (so it never leaks into disabled apps) and, when a text field has focus in
    -- insert mode, enters normal mode and swallows the escape that follows so the app does not also act
    -- on it (Slack closes a thread on escape). Otherwise the escape passes through as a plain escape.
    local swallowEscape = false
    local f17, escape = hs.keycodes.map.f17, hs.keycodes.map.escape
    keyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
        local key = event:getKeyCode()
        if key == f17 then
            swallowEscape = vim.enabled and vim:isMode("insert") and ax.focusedTextField() and true or false
            if swallowEscape then
                vim:enter()
            end
            return true
        end
        local swallow = swallowEscape and key == escape
        swallowEscape = false
        return swallow
    end)
    keyTap:start()

    -- The spoon only leaves normal mode on a focus change inside the app, and that observer fails for
    -- Electron apps, so a stray normal mode would follow an app switch. Exit is a no-op in insert mode.
    appWatcher = hs.application.watcher.new(function(_, event)
        if event == hs.application.watcher.activated then
            vim:exit()
        end
    end)
    appWatcher:start()
end

return { setup = setup }
