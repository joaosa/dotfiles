-----------------------------------------------
-- Date Insertion
-----------------------------------------------

local keys = require("config.keybindings")
local hotkey = require("lib.hotkey")
local utils = require("lib.utils")
local altCmd = keys.altCmd
local pasteString = utils.pasteString

local function setup()
    hotkey.bindHotkeys(altCmd, {
        ["]"] = function() pasteString(os.date("%Y-%m-%d")) end,  -- Today
        ["["] = function() pasteString(os.date("%Y-%m-%d", os.time() - 86400)) end,  -- Yesterday
    })
end

return {
    setup = setup,
}
