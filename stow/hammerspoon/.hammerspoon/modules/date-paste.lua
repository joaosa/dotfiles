-----------------------------------------------
-- Date Insertion
-----------------------------------------------

local keys = require("config.keybindings")
local paste = require("lib.paste")
local hotkey = require("lib.hotkey")
local altCmd = keys.altCmd
local pasteString = paste.pasteString

local function setup()
    hotkey.bindHotkeys(altCmd, {
        ["]"] = function() pasteString(os.date("%Y-%m-%d")) end,  -- Today
        ["["] = function() pasteString(os.date("%Y-%m-%d", os.time() - 86400)) end,  -- Yesterday
    })
end

return {
    setup = setup,
}
