-----------------------------------------------
-- General Utility Functions
-----------------------------------------------

-- Trim whitespace from string
local function trim(str)
    return str:gsub("^%s+", ""):gsub("%s+$", "")
end

-- Pluralize string based on count
local function pluralize(count, singular, plural)
    return count == 1 and singular or (plural or singular .. "s")
end

-- Find a binary in the nix profile dirs, module-specific extra paths, or via
-- a fallback command. Hammerspoon does not inherit the shell PATH, so the
-- profile bin dirs (where this repo installs tools) are searched first.
local function findBinary(name, paths, fallbackCmd)
    local searchPaths = {
        "/etc/profiles/per-user/" .. (os.getenv("USER") or "") .. "/bin/" .. name,
        os.getenv("HOME") .. "/.nix-profile/bin/" .. name,
    }
    for _, path in ipairs(paths or {}) do
        searchPaths[#searchPaths + 1] = path
    end

    for _, path in ipairs(searchPaths) do
        if hs.fs.attributes(path) then
            return path
        end
    end

    if fallbackCmd then
        local result = hs.execute(fallbackCmd)
        if result and result ~= "" then
            return result:gsub("\n", "")
        end
    end

    return nil
end

-- Build missing dependencies message
local function missingDeps(deps)
    local missing = {}
    for name, value in pairs(deps) do
        if not value then
            table.insert(missing, name)
        end
    end
    return #missing > 0 and table.concat(missing, " ") or nil
end

-- Create a debounced version of a function
local function debounce(fn, delay)
    local timer = nil
    return function()
        if timer then timer:stop() end
        timer = hs.timer.doAfter(delay, fn)
    end
end

return {
    trim = trim,
    pluralize = pluralize,
    findBinary = findBinary,
    missingDeps = missingDeps,
    debounce = debounce,
}
