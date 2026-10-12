-----------------------------------------------
-- Accessibility helpers shared by vim and nav
-----------------------------------------------

-- Roles VimMode.spoon's own axUtils.isTextField treats as editable text.
local textRoles = { AXTextField = true, AXTextArea = true, AXComboBox = true }

local function focusedTextField()
    local element = hs.axuielement.systemWideElement():attributeValue("AXFocusedUIElement")
    return element and textRoles[element:attributeValue("AXRole")]
end

return { focusedTextField = focusedTextField }
