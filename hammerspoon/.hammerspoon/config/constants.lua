-----------------------------------------------
-- Shared Constants
-- Only constants used by multiple modules
-----------------------------------------------

local TIMING = {
    -- Alert durations
    ALERT_SHORT = 1,
    ALERT_MEDIUM = 2,
    ALERT_LONG = 3,

    -- Common operation timings
    CLIPBOARD_RESTORE_DELAY = 0.3,
    WINDOW_FOCUS_DELAY = 0.15,
    PASTE_DELAY = 0.1,
    WINDOW_OPERATION_SLEEP = 50000, -- microseconds
}

return {
    TIMING = TIMING,
}
