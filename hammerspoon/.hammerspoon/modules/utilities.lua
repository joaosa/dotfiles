-----------------------------------------------
-- Additional Utilities (WiFi, Lock, Sleep)
-----------------------------------------------

local keys = require("config.keybindings")
local config = require("config.constants")
local hyper = keys.hyper
local TIMING = config.TIMING

-- Module-specific alert
local ALERTS = {
    NO_WIFI = "No WiFi connected",
}

local utilityBindings = {
    w = function() -- Show WiFi network
        local wifi = hs.wifi.currentNetwork()
        hs.alert.show(wifi and ("WiFi: " .. wifi) or ALERTS.NO_WIFI, {},
            wifi and TIMING.ALERT_LONG or TIMING.ALERT_MEDIUM)
    end,
    l = hs.caffeinate.lockScreen, -- Lock screen
    s = hs.caffeinate.systemSleep  -- Sleep
}

local function setup()
    for key, fn in pairs(utilityBindings) do
        hs.hotkey.bind(hyper, key, fn)
    end
end

return {
    setup = setup,
}
