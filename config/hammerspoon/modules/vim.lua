-----------------------------------------------
-- System-wide Vim Mode (VimMode.spoon)
-----------------------------------------------

local log = hs.logger.new("vim", "info")

-- Roles VimMode.spoon's own axUtils.isTextField treats as editable text.
local textRoles = { AXTextField = true, AXTextArea = true, AXComboBox = true }

local appWatcher

local function focusedTextField()
    local element = hs.axuielement.systemWideElement():attributeValue("AXFocusedUIElement")
    return element and textRoles[element:attributeValue("AXRole")]
end

local function setup()
    local ok, VimMode = pcall(hs.loadSpoon, "VimMode")
    if not ok then
        log.e("VimMode.spoon not installed - run make switch")
        return
    end

    local vim = VimMode:new()

    -- Apps with native vim bindings; vim:enter() is a no-op while they are frontmost.
    vim:disableForApp("Alacritty")
    vim:disableForApp("Obsidian")
    vim:disableForApp("Firefox Developer Edition")

    -- Karabiner sends escape+f17 on a lone caps_lock tap. Bind f17 ourselves (not vim:bindHotKeys) so it is
    -- always consumed and never leaks into disabled apps; enter normal mode only when a text field has focus
    -- so escape elsewhere stays a plain escape. Deferred so the app handles the escape first (dismissing a
    -- search box must not leave normal mode on the view behind it).
    hs.hotkey.bind({}, "f17", function()
        hs.timer.doAfter(0.02, function()
            if focusedTextField() then
                vim:enter()
            end
        end)
    end)

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
