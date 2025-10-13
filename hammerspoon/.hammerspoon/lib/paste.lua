-----------------------------------------------
-- Paste Utilities
-----------------------------------------------

local clipboard = require("lib.clipboard")
local withClipboard = clipboard.withClipboard

-- Paste string by temporarily replacing clipboard
local function pasteString(string)
    if not string or string == "" then
        return false
    end

    withClipboard(function()
        hs.pasteboard.setContents(string)
        hs.eventtap.keyStrokes(string)
    end)

    return true
end

return {
    pasteString = pasteString,
}
