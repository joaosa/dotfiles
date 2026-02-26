-----------------------------------------------
-- Caffeine (Prevent Sleep Toggle)
-----------------------------------------------

local keys = require("config.keybindings")
local config = require("config.constants")
local hyper = keys.hyper
local TIMING = config.TIMING

local menubar = nil
local caffeineActive = false

local function updateMenubar()
    if menubar then
        menubar:setTitle(caffeineActive and "☕" or "")
    end
end

local function toggle()
    caffeineActive = not caffeineActive
    hs.caffeinate.set("displayIdle", caffeineActive)
    hs.caffeinate.set("systemIdle", caffeineActive)
    updateMenubar()
    hs.alert.show(caffeineActive and "Caffeine ON" or "Caffeine OFF", {}, TIMING.ALERT_SHORT)
end

local function setup()
    menubar = hs.menubar.new()
    updateMenubar()
    hs.hotkey.bind(hyper, "k", toggle)
end

return { setup = setup }
