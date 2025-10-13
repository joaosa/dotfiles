-----------------------------------------------
-- Scheduled Shutdown
-----------------------------------------------

local keys = require("config.keybindings")
local hyper = keys.hyper

-- Module-specific constants
local SHUTDOWN_TIMING = {
    DELAY = 2,
}

local ALERTS = {
    SHUTDOWN_CANCELLED = "🛑 Shutdown cancelled",
    GOOD_NIGHT = "💤 Good night!",
}

-- Get Sleep Focus bedtime from macOS
local function getSleepFocusBedtime()
    local cmd = [[python3 -c "
import json, datetime, os
with open(os.path.expanduser('~/Library/DoNotDisturb/DB/Assertions.json')) as f:
    data = json.load(f)
for r in data['data'][0].get('storeAssertionRecords', []):
    d = r.get('assertionDetails', {})
    if d.get('assertionDetailsModeIdentifier') == 'com.apple.sleep.sleep-mode':
        ts = r.get('assertionStartDateTimestamp', 0)
        t = datetime.datetime(2001,1,1,tzinfo=datetime.timezone.utc) + datetime.timedelta(seconds=ts)
        local_t = t.astimezone()
        print(local_t.hour, local_t.minute)
        break
" 2>/dev/null]]

    local output = hs.execute(cmd)
    if output then
        local hour, minute = output:match("(%d+)%s+(%d+)")
        if hour and minute then
            return tonumber(hour), tonumber(minute)
        end
    end
    return nil, nil
end

local shutdownTimer = nil

local function cancelShutdown()
    if shutdownTimer then
        shutdownTimer:stop()
        shutdownTimer = nil
        hs.alert.show(ALERTS.SHUTDOWN_CANCELLED)
    end
end

local function setup()
    -- Get bedtime from Sleep Focus
    local hour, minute = getSleepFocusBedtime()
    local shutdownConfig = {
        enabled = hour ~= nil,
        hour = hour,
        minute = minute,
    }

    -- Schedule shutdown if bedtime is configured
    if shutdownConfig.enabled then
        shutdownTimer = hs.timer.doAt(
            string.format("%02d:%02d", shutdownConfig.hour, shutdownConfig.minute),
            function()
                hs.alert.show(ALERTS.GOOD_NIGHT)
                hs.timer.doAfter(SHUTDOWN_TIMING.DELAY, hs.caffeinate.systemSleep)
            end
        )
    end

    -- hyper+p: Cancel scheduled shutdown
    hs.hotkey.bind(hyper, "p", cancelShutdown)
end

return {
    setup = setup,
}
