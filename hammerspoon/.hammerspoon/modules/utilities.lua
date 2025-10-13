-----------------------------------------------
-- Additional Utilities (WiFi, Lock, Sleep)
-----------------------------------------------

local keys = require("config.keybindings")
local config = require("config.constants")
local hotkey = require("lib.hotkey")
local hyper = keys.hyper
local TIMING = config.TIMING

local function setup()
    hotkey.bindHotkeys(hyper, {
        w = function() -- Show WiFi network
            local wifi = hs.wifi.currentNetwork()
            hs.alert.show(wifi and ("WiFi: " .. wifi) or "No WiFi connected", {},
                wifi and TIMING.ALERT_LONG or TIMING.ALERT_MEDIUM)
        end,
        l = hs.caffeinate.lockScreen,  -- Lock screen
        s = hs.caffeinate.systemSleep,  -- Sleep
    })
end

return {
    setup = setup,
}
