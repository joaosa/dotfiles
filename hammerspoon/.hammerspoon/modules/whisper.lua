-----------------------------------------------
-- Speech to Text with Whisper
-----------------------------------------------

local keys = require("config.keybindings")
local config = require("config.constants")
local utils = require("lib.utils")
local windowLib = require("lib.window")
local datePaste = require("modules.date-paste")

local altCmd = keys.altCmd
local TIMING = config.TIMING
local trim = utils.trim
local findBinary = utils.findBinary
local missingDeps = utils.missingDeps
local withWindowRestore = windowLib.withWindowRestore

-- Module-specific constants
local WHISPER_PATHS = {
    TEMP_FILE = os.getenv("HOME") .. "/.hammerspoon_whisper.wav",
    MODEL = os.getenv("HOME") .. "/.local/share/whisper/ggml-base.en.bin",
}

local WHISPER_CONFIG = {
    PREVIEW_LENGTH = 40,
    SOX_SUCCESS_CODES = {[0] = true, [2] = true},
    SOX_ARGS = {"-d", "-r", "16000", "-c", "1"},
    TRANSCRIBE_ARGS_BASE = {"-m", "--no-timestamps"},
}

local WHISPER_TIMING = {
    TIMEOUT = 30,
}

local ALERTS = {
    WHISPER_TRANSCRIBING = "🎤 Transcribing...",
    WHISPER_RECORDING = "🎤 Recording...",
    WHISPER_TIMEOUT = "❌ Timeout",
    WHISPER_NOT_INSTALLED = "❌ Whisper not installed",
    WHISPER_NO_SPEECH = "❌ No speech\nCheck mic permissions",
    WHISPER_FAILED = "❌ Failed (code %d)",
    WHISPER_RECORDING_FAILED = "❌ Recording failed",
    WHISPER_SUCCESS_PREFIX = "✓ ",
}

-- Logger for debugging
local log = hs.logger.new('whisper', 'info')

local whisper = {
    recording = nil,
    task = nil,
    tempFile = WHISPER_PATHS.TEMP_FILE,
    model = WHISPER_PATHS.MODEL,
    binary = nil,
    sox = nil,
}

-- Note: pasteString is defined in date-paste module but we need it here
-- We'll extract it or redefine it locally
local function pasteString(string)
    if not string or string == "" then
        return
    end
    hs.pasteboard.setContents(string)
    hs.eventtap.keyStrokes(string)
end

local function setup()
    -- Find and cache binaries on load
    whisper.binary = findBinary("whisper-cli",
        { "/opt/homebrew/bin/whisper-cli", "/usr/local/bin/whisper-cli" },
        "find /opt/homebrew/Cellar/whisper-cpp -name whisper-cli -type f 2>/dev/null | head -1"
    )

    whisper.sox = findBinary("sox",
        { "/opt/homebrew/bin/sox", "/usr/local/bin/sox" }
    )

    -- Validate dependencies
    local missing = missingDeps({
        ["whisper-cli"] = whisper.binary,
        ["sox"] = whisper.sox,
        ["model"] = hs.fs.attributes(whisper.model)
    })
    if missing then
        log.e("Whisper setup failed - missing: " .. missing)
    end

    -- altCmd+d: Toggle recording/transcribe
    hs.hotkey.bind(altCmd, "d", function()
        if whisper.recording then
            -- Stop recording and transcribe
            whisper.recording:terminate()
            whisper.recording = nil
            hs.alert.show(ALERTS.WHISPER_TRANSCRIBING)

            local win = hs.window.focusedWindow()
            local app = hs.application.frontmostApplication()

            -- Timeout after 30s
            local timeout = hs.timer.doAfter(WHISPER_TIMING.TIMEOUT, function()
                if whisper.task then
                    whisper.task:terminate()
                    whisper.task = nil
                    hs.alert.show(ALERTS.WHISPER_TIMEOUT)
                end
            end)

            -- Transcribe
            whisper.task = hs.task.new(whisper.binary, function(code, stdout)
                timeout:stop()
                whisper.task = nil
                pcall(os.remove, whisper.tempFile)

                if code == 0 then
                    local text = trim(stdout)
                    if text ~= "" and not text:match("^%[") then
                        local preview = text:sub(1, WHISPER_CONFIG.PREVIEW_LENGTH)
                        if text:len() > WHISPER_CONFIG.PREVIEW_LENGTH then
                            preview = preview .. "..."
                        end
                        hs.alert.show(ALERTS.WHISPER_SUCCESS_PREFIX .. preview)
                        withWindowRestore(app, win, function()
                            pasteString(text)
                        end)
                    else
                        hs.alert.show(ALERTS.WHISPER_NO_SPEECH)
                    end
                else
                    hs.alert.show(string.format(ALERTS.WHISPER_FAILED, code))
                end
            end, { "-m", whisper.model, "-f", whisper.tempFile, "--no-timestamps" }):start()
        else
            -- Start recording
            if not whisper.binary or not whisper.sox then
                hs.alert.show(ALERTS.WHISPER_NOT_INSTALLED)
                return
            end

            pcall(os.remove, whisper.tempFile)
            hs.alert.show(ALERTS.WHISPER_RECORDING)

            local soxArgs = {table.unpack(WHISPER_CONFIG.SOX_ARGS)}
            table.insert(soxArgs, whisper.tempFile)
            whisper.recording = hs.task.new(whisper.sox, function(code)
                if not WHISPER_CONFIG.SOX_SUCCESS_CODES[code] then
                    hs.alert.show(ALERTS.WHISPER_RECORDING_FAILED)
                end
            end, soxArgs):start()
        end
    end)
end

return {
    setup = setup,
}
