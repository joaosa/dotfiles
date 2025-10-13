-----------------------------------------------
-- Hotkey Binding Utilities
-----------------------------------------------

-- Bind multiple hotkeys from a key->function map
local function bindHotkeys(mods, keyMap)
    for key, fn in pairs(keyMap) do
        hs.hotkey.bind(mods, key, fn)
    end
end

return {
    bindHotkeys = bindHotkeys,
}
