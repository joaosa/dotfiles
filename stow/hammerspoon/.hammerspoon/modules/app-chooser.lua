-----------------------------------------------
-- Fuzzy App Chooser
-----------------------------------------------

local keys = require("config.keybindings")
local hyper = keys.hyper

local chooser = nil

local function getRunningApps()
    local choices = {}
    for _, app in ipairs(hs.application.runningApplications()) do
        if app:mainWindow() and app:title() ~= "" then
            table.insert(choices, {
                text = app:title(),
                subText = app:bundleID() or "",
                bundleID = app:bundleID(),
            })
        end
    end
    table.sort(choices, function(a, b) return a.text < b.text end)
    return choices
end

local function setup()
    chooser = hs.chooser.new(function(choice)
        if choice then
            local app = hs.application.get(choice.bundleID)
            if app then app:activate() end
        end
    end)

    hs.hotkey.bind(hyper, "b", function()
        chooser:choices(getRunningApps)
        chooser:show()
    end)
end

return { setup = setup }
