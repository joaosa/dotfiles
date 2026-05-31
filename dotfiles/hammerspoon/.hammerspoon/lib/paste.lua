-----------------------------------------------
-- Paste Utilities
-----------------------------------------------

local function pasteString(str)
    if not str or str == "" then
        return false
    end

    hs.eventtap.keyStrokes(str)
    return true
end

return {
    pasteString = pasteString,
}
