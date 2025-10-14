-----------------------------------------------
-- Application Launcher
-----------------------------------------------

local keys = require("config.keybindings")
local utils = require("lib.utils")
local hotkey = require("lib.hotkey")
local altCmd = keys.altCmd
local launchOrFocusApp = utils.launchOrFocusApp

local function setup()
    hotkey.bindHotkeys(altCmd, {
        e = function() launchOrFocusApp("Obsidian") end,
        w = function() launchOrFocusApp("Firefox Developer Edition") end,
        i = function() launchOrFocusApp("Discord") end,
        o = function() launchOrFocusApp("Spotify") end,
        u = function() launchOrFocusApp("Mail") end,
        n = function() launchOrFocusApp("Notion") end,
    })
end

return {
    setup = setup,
}
