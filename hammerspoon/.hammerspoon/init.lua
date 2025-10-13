-----------------------------------------------
-- Hammerspoon Configuration (Modular)
-- Main entry point - loads all modules
-----------------------------------------------

-- Standard Hammerspoon package.path configuration
-- hs.configdir should resolve to the real path when init.lua is symlinked
local configDir = hs.configdir

-- Set package.path to include config directory subdirectories
package.path = configDir .. '/?.lua;' ..
               configDir .. '/?/init.lua;' ..
               package.path

-- Performance settings
hs.window.animationDuration = 0
hs.window.setFrameCorrectness = true

-- Load all modules (see modules/ directory for individual module descriptions)
-- Note: window-management must load before terminal (dependency on frames export)
local modules = {
    "reload",
    "console",
    "window-management",
    "terminal",
    "app-launcher",
    "date-paste",
    "utilities",
    "whisper",
    "shutdown",
}

for _, moduleName in ipairs(modules) do
    local module = require("modules." .. moduleName)
    if module.setup then
        module.setup()
    end
end
