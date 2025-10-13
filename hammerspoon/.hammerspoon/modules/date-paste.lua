-----------------------------------------------
-- Date Insertion
-----------------------------------------------

local keys = require("config.keybindings")
local clipboard = require("lib.clipboard")
local altCmd = keys.altCmd
local withClipboard = clipboard.withClipboard

-- Module-specific alert
local ALERTS = {
    NOTHING_TO_PASTE = "Nothing to paste",
}

local function pasteString(string)
    if not string or string == "" then
        hs.alert.show(ALERTS.NOTHING_TO_PASTE)
        return
    end

    withClipboard(function()
        hs.pasteboard.setContents(string)
        hs.eventtap.keyStrokes(string)
    end)
end

local function setup()
    -- altCmd+]: Paste today's date
    hs.hotkey.bind(altCmd, "]", function()
        pasteString(os.date("%Y-%m-%d"))
    end)

    -- altCmd+[: Paste yesterday's date
    hs.hotkey.bind(altCmd, "[", function()
        pasteString(os.date("%Y-%m-%d", os.time() - 86400))
    end)
end

return {
    setup = setup,
}
