-----------------------------------------------
-- Accessibility helpers shared by vim and nav
-----------------------------------------------

-- Roles VimMode.spoon's own axUtils.isTextField treats as editable text.
local textRoles = { AXTextField = true, AXTextArea = true, AXComboBox = true }

-- True when the focused element is a text field holding non-blank text: what a caps tap or a NAV key
-- would otherwise be editing. Whitespace-only counts as empty (an empty Electron composer reports a
-- lone newline). The character count is checked first so a large document is not copied over IPC.
local function editing()
    local element = hs.axuielement.systemWideElement():attributeValue("AXFocusedUIElement")
    if not element or not textRoles[element:attributeValue("AXRole")] then
        return false
    end
    local count = element:attributeValue("AXNumberOfCharacters")
    if count == 0 then
        return false
    elseif count and count > 16 then
        return true
    end
    local value = element:attributeValue("AXValue")
    return type(value) == "string" and value:find("%S") ~= nil
end

-- Electron apps expose no accessibility tree until a client sets AXManualAccessibility, and the tree
-- takes seconds to come up, so it is set on launch and activation rather than when editing() asks.
-- The set is idempotent and fails fast on native apps and on an app still launching (activation retries).
local function wake(app)
    if app then
        pcall(function() hs.axuielement.applicationElement(app):setAttributeValue("AXManualAccessibility", true) end)
    end
end

return { editing = editing, wake = wake }
