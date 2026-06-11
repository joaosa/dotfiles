-----------------------------------------------
-- Hammerspoon Configuration (Modular)
-- Main entry point - loads all modules
-----------------------------------------------

-- Performance settings
hs.window.animationDuration = 0
hs.window.setFrameCorrectness = true

-- Local CLI control via `hs` (used to verify config changes from the shell)
require("hs.ipc")

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
    "asr",
    "app-chooser",
    "caffeine",
    "shutdown",
    "vim",
    "element-hints",
}

for _, moduleName in ipairs(modules) do
    local module = require("modules." .. moduleName)
    if module.setup then
        module.setup()
    end
end
