-----------------------------------------------
-- Speech to Text with Whisper
-----------------------------------------------

local keys = require("config.keybindings")
local config = require("config.constants")
local utils = require("lib.utils")
local windowLib = require("lib.window")
local paste = require("lib.paste")

local altCmd = keys.altCmd
local TIMING = config.TIMING
local trim = utils.trim
local findBinary = utils.findBinary
local missingDeps = utils.missingDeps
local withWindowRestore = windowLib.withWindowRestore
local pasteString = paste.pasteString

-- Logger for debugging
local log = hs.logger.new('whisper', 'info')

local whisper = {
    recording = nil,
    task = nil,
    tempFile = os.getenv("HOME") .. "/.hammerspoon_whisper.wav",
    model = os.getenv("HOME") .. "/.local/share/whisper/ggml-base.en.bin",
    binary = nil,
    sox = nil,
}

local function startRecording()
    if not whisper.binary or not whisper.sox then
        hs.alert.show("❌ Whisper not installed")
        return
    end

    pcall(os.remove, whisper.tempFile)
    hs.alert.show("🎤 Recording...")

    whisper.recording = hs.task.new(whisper.sox, function(code)
        -- sox exits with 0 on success, 2 on SIGINT (normal stop)
        if code ~= 0 and code ~= 2 then
            hs.alert.show("❌ Recording failed")
        end
    end, {"-d", "-r", "16000", "-c", "1", whisper.tempFile}):start()
end

local function stopRecordingAndTranscribe()
    whisper.recording:terminate()
    whisper.recording = nil
    hs.alert.show("🎤 Transcribing...")

    local win = hs.window.focusedWindow()
    local app = hs.application.frontmostApplication()

    -- Timeout after 30s
    local timeout = hs.timer.doAfter(30, function()
        if whisper.task then
            whisper.task:terminate()
            whisper.task = nil
            hs.alert.show("❌ Timeout")
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
                local preview = text:sub(1, 40)
                if text:len() > 40 then
                    preview = preview .. "..."
                end
                hs.alert.show("✓ " .. preview)
                withWindowRestore(app, win, function()
                    pasteString(text)
                end)
            else
                hs.alert.show("❌ No speech\nCheck mic permissions")
            end
        else
            hs.alert.show(string.format("❌ Failed (code %d)", code))
        end
    end, { "-m", whisper.model, "-f", whisper.tempFile, "--no-timestamps" }):start()
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
            stopRecordingAndTranscribe()
        else
            startRecording()
        end
    end)
end

return {
    setup = setup,
}
