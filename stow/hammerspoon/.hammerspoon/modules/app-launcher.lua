-----------------------------------------------
-- Application Launcher
-----------------------------------------------

local keys = require("config.keybindings")
local hotkey = require("lib.hotkey")
local altCmd = keys.altCmd
local launch = hs.application.launchOrFocus

local function setup()
    hotkey.bindHotkeys(altCmd, {
        e = function() launch("Obsidian") end,
        w = function() launch("Firefox Developer Edition") end,
        i = function() launch("Slack") end,
        o = function() launch("Spotify") end,
        u = function() launch("Mail") end,
        n = function() launch("Notion") end,
    })
end

return {
    setup = setup,
}
