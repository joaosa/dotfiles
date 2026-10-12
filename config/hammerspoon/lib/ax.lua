-----------------------------------------------
-- Accessibility helpers shared by vim and nav
-----------------------------------------------

-- Roles VimMode.spoon's own axUtils.isTextField treats as editable text.
local textRoles = { AXTextField = true, AXTextArea = true, AXComboBox = true }

local function focusedTextField()
    local element = hs.axuielement.systemWideElement():attributeValue("AXFocusedUIElement")
    return element and textRoles[element:attributeValue("AXRole")]
end

-- Electron apps expose no accessibility tree until a client sets AXManualAccessibility, and the tree
-- takes seconds to come up, so it is set on launch/activation rather than when focusedTextField asks.
-- The set fails while an app is still launching and on native apps; only a success is memoised per
-- pid, so the next activation retries.
local woken = {}
local function wake(app)
    local pid = app and app:pid()
    if not pid or woken[pid] then
        return
    end
    local ok, res = pcall(
        function() return hs.axuielement.applicationElement(app):setAttributeValue("AXManualAccessibility", true) end
    )
    woken[pid] = ok and res ~= nil or nil
end

return { focusedTextField = focusedTextField, wake = wake }
