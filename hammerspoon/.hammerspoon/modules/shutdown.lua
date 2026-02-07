-----------------------------------------------
-- Sleep Focus Shutdown
-----------------------------------------------

local keys = require("config.keybindings")
local hyper = keys.hyper

local POLL_INTERVAL = 60
local SLEEP_DELAY = 3

local sleepTimer = nil

local function isSleepFocusActive()
    local home = os.getenv("HOME")
    if not home then return false end

    local dbPath = home .. "/Library/DoNotDisturb/DB/Assertions.json"
    local file = io.open(dbPath, "r")
    if not file then return false end
    local output = file:read("*a")
    file:close()

    if not output or output == "" then return false end

    local ok, data = pcall(hs.json.decode, output)
    if not ok or not data or not data.data or not data.data[1] then return false end

    local records = data.data[1].storeAssertionRecords
    if not records then return false end

    for _, record in ipairs(records) do
        if record and record.assertionDetails then
            local modeId = record.assertionDetails.assertionDetailsModeIdentifier
            if modeId == "com.apple.sleep.sleep-mode" then
                return true
            end
        end
    end

    return false
end

local function triggerSleep()
    hs.alert.show("💤 Good night!")
    hs.caffeinate.systemSleep()
end

local function cancelSleep()
    if sleepTimer then
        sleepTimer:stop()
        sleepTimer = nil
        hs.alert.show("🛑 Sleep cancelled")
    end
end

local function checkSleepFocus()
    if isSleepFocusActive() and not sleepTimer then
        sleepTimer = hs.timer.doAfter(SLEEP_DELAY, triggerSleep)
    elseif not isSleepFocusActive() and sleepTimer then
        cancelSleep()
    end
end

local function setup()
    hs.timer.new(POLL_INTERVAL, checkSleepFocus):start()
    checkSleepFocus()
    hs.hotkey.bind(hyper, "p", cancelSleep)
end

return {
    setup = setup,
}
