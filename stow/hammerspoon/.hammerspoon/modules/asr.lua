-----------------------------------------------
-- Speech to Text with Qwen3-ASR
-----------------------------------------------

local keys = require("config.keybindings")
local utils = require("lib.utils")
local windowLib = require("lib.window")
local paste = require("lib.paste")

local altCmd = keys.altCmd
local trim = utils.trim
local findBinary = utils.findBinary
local missingDeps = utils.missingDeps
local withWindowRestore = windowLib.withWindowRestore
local pasteString = paste.pasteString

-- Logger for debugging
local log = hs.logger.new('asr', 'info')

local asr = {
    recording = nil,
    task = nil,
    tempFile = nil,
    modelDir = os.getenv("HOME") .. "/.local/share/qwen3-asr/Qwen3-ASR-0.6B", -- keep in sync with ASR_MODEL_DIR in versions.env
    binary = nil,
    sox = nil,
}

local function startRecording()
    if not asr.binary or not asr.sox then
        hs.alert.show("❌ ASR not installed")
        return
    end

    asr.tempFile = os.tmpname() .. ".wav"
    hs.alert.show("🎤 Recording...")

    asr.recording = hs.task.new(asr.sox, function(code)
        -- sox exits with 0 on success, 2 on SIGINT (normal stop)
        if code ~= 0 and code ~= 2 then
            hs.alert.show("❌ Recording failed")
        end
    end, {"-d", "-r", "16000", "-c", "1", "-b", "16", "-e", "signed-integer", asr.tempFile}):start()
end

local function stopRecordingAndTranscribe()
    asr.recording:terminate()
    asr.recording = nil
    hs.alert.show("🎤 Transcribing...")

    local win = hs.window.focusedWindow()
    local app = hs.application.frontmostApplication()

    -- Timeout after 30s
    local timeout = hs.timer.doAfter(30, function()
        if asr.task then
            asr.task:terminate()
            asr.task = nil
            pcall(os.remove, asr.tempFile)
            hs.alert.show("❌ Timeout")
        end
    end)

    -- Transcribe
    asr.task = hs.task.new(asr.binary, function(code, stdout)
        timeout:stop()
        asr.task = nil
        pcall(os.remove, asr.tempFile)

        if code == 0 then
            local text = trim(stdout)
            if text ~= "" then
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
    end, { "-d", asr.modelDir, "-i", asr.tempFile, "--silent" }):start()
end

local function setup()
    -- Find and cache binaries on load
    asr.binary = findBinary("qwen-asr",
        { os.getenv("HOME") .. "/.cargo/bin/qwen-asr" }
    )

    asr.sox = findBinary("sox",
        { "/opt/homebrew/bin/sox", "/usr/local/bin/sox" }
    )

    -- Validate dependencies
    local missing = missingDeps({
        ["qwen-asr"] = asr.binary,
        ["sox"] = asr.sox,
        ["model"] = hs.fs.attributes(asr.modelDir)
    })
    if missing then
        log.e("ASR setup failed - missing: " .. missing)
        return
    end

    -- altCmd+d: Toggle recording/transcribe
    hs.hotkey.bind(altCmd, "d", function()
        if asr.recording then
            stopRecordingAndTranscribe()
        else
            startRecording()
        end
    end)
end

return {
    setup = setup,
}
