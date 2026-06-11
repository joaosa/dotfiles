-----------------------------------------------
-- System-wide Vim Mode (VimMode.spoon)
-----------------------------------------------

local log = hs.logger.new('vim', 'info')

local function setup()
    local ok, VimMode = pcall(hs.loadSpoon, "VimMode")
    if not ok then
        log.e("VimMode.spoon not installed - run make switch")
        return
    end

    local vim = VimMode:new()

    -- Apps with native vim bindings. Keep in sync with the caps_lock rule in
    -- config/karabiner/karabiner.json, which skips the f17 trigger for these
    -- (VimMode unbinds f17 in disabled apps, so it would leak into them as a
    -- raw keypress - e.g. a "~" escape sequence in terminals).
    vim:disableForApp("Alacritty")
    vim:disableForApp("Obsidian")
    vim:disableForApp("Firefox Developer Edition")

    -- Karabiner sends f17 alongside escape when caps_lock is tapped alone,
    -- so a caps tap enters normal mode (and still escapes in terminals).
    vim:bindHotKeys({ enter = { {}, "f17" } })
end

return { setup = setup }
