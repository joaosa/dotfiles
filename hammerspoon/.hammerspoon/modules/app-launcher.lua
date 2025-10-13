-----------------------------------------------
-- Application Launcher
-----------------------------------------------

local keys = require("config.keybindings")
local utils = require("lib.utils")
local altCmd = keys.altCmd
local launchOrFocusApp = utils.launchOrFocusApp

-- Application bindings
local appBindings = {
    e = "Obsidian",
    w = "Firefox Developer Edition",
    i = "Slack",
    o = "Spotify",
    u = "Mail",
    n = "Notion"
}

local function setup()
    for key, appName in pairs(appBindings) do
        hs.hotkey.bind(altCmd, key, function()
            launchOrFocusApp(appName)
        end)
    end
end

return {
    setup = setup,
}
