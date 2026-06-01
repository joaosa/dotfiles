local M = {}

function M.check()
  vim.health.start("config")
  local tools = vim.g._health_tools or {}
  for category, names in pairs(tools) do
    for _, name in ipairs(names) do
      if vim.fn.executable(name) == 1 then
        vim.health.ok(category .. ": " .. name)
      else
        vim.health.warn(category .. ": " .. name .. " not found")
      end
    end
  end
end

return M
