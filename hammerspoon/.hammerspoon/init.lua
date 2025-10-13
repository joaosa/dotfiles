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

-- Load all modules
-- Note: Order matters - some modules depend on others
local moduleList = {
    "reload",           -- Config reload watcher (shows "Config Loaded" alert)
    "console",          -- Hammerspoon console hotkey
    "window-management",-- Window resizing, focus, hints, display movement
    "app-launcher",     -- App launching hotkeys
    "terminal",         -- Alacritty terminal management + auto-resize
    "date-paste",       -- Date insertion hotkeys
    "utilities",        -- WiFi, lock, sleep
    "whisper",          -- Speech-to-text
    "shutdown",         -- Scheduled shutdown
}

for _, moduleName in ipairs(moduleList) do
    local module = require("modules." .. moduleName)
    if module.setup then
        module.setup()
    end
end
