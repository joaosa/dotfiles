-----------------------------------------------
-- System-wide Vim Mode (VimMode.spoon)
-----------------------------------------------

local log = hs.logger.new("vim", "info")
local TIMING = require("config.constants").TIMING
local ax = require("lib.ax")
local nav = require("modules.nav")

-- Kept at module scope so the watchers are not garbage collected.
local appWatcher, keyTap, navTimer

local function setup()
    local ok, VimMode = pcall(hs.loadSpoon, "VimMode")
    if not ok then
        log.e("VimMode.spoon not installed - run make switch")
        return
    end

    local vim = VimMode:new()
    -- A reload fires no activation for the app already in front.
    ax.wake(hs.application.frontmostApplication())

    -- Apps with native vim bindings; the spoon's app watcher clears vim.enabled while they are frontmost.
    vim:disableForApp("Alacritty")
    vim:disableForApp("Obsidian")
    vim:disableForApp("Firefox Developer Edition")

    -- Karabiner sends f17 then escape on a lone caps_lock tap; the tap sees both in order before any app.
    -- f17 is always consumed. In a disabled app or while the spoon is already in normal/visual mode the
    -- escape passes through untouched. In a text field with text: enter NORMAL and swallow the escape (Slack
    -- closes a thread on escape). Anywhere else, including an empty field (nothing to edit, and some apps
    -- keep one focused while you read): toggle NAV; entering swallows the escape (the modal's own escape
    -- binding would exit again at once), leaving lets it through so a caps tap still dismisses popovers.
    local swallowEscape = false
    local f17, escape = hs.keycodes.map.f17, hs.keycodes.map.escape
    keyTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
        local key = event:getKeyCode()
        if key == f17 then
            swallowEscape = false
            if vim.enabled and vim:isMode("insert") then
                if ax.editing() then
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
    -- Then the new app starts in NAV unless a field with text is focused, as a caps tap would decide;
    -- focus settles a beat after activation (the one timer is re-armed, so only the latest switch
    -- decides) and the spoon's own watcher clears vim.enabled by then.
    appWatcher = hs.application.watcher.new(function(_, event, app)
        if event == hs.application.watcher.activated then
            vim:exit()
            nav.exit()
            ax.wake(app)
            if navTimer then
                navTimer:stop()
            end
            navTimer = hs.timer.doAfter(TIMING.WINDOW_FOCUS_DELAY, function()
                if vim.enabled and vim:isMode("insert") and not ax.editing() then
                    nav.enter()
                end
            end)
        elseif event == hs.application.watcher.launched then
            ax.wake(app)
        end
    end)
    appWatcher:start()
end

return { setup = setup }
