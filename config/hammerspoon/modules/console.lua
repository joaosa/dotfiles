-----------------------------------------------
-- Hammerspoon Console
-----------------------------------------------

local keys = require("config.keybindings")
local altCmd = keys.altCmd

local function setup()
    -- altCmd+x: Open the hammerspoon console
    hs.hotkey.bind(altCmd, "x", hs.openConsole)
end

return {
    setup = setup,
}
