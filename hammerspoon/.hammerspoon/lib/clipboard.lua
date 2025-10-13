-----------------------------------------------
-- Clipboard Utilities
-----------------------------------------------

local config = require("config.constants")
local TIMING = config.TIMING

-- Execute function with clipboard preservation
local function withClipboard(fn)
    local current = hs.pasteboard.getContents()
    fn()
    if current then
        hs.timer.doAfter(TIMING.CLIPBOARD_RESTORE_DELAY, function()
            hs.pasteboard.setContents(current)
        end)
    end
end

return {
    withClipboard = withClipboard,
}
