local M = {}

local tools = {
  lsp = {
    "lua-language-server",
    "gopls",
    "terraform-ls",
    "pyright",
    "ruff",
    "typescript-language-server",
    "yaml-language-server",
    "vim-language-server",
    "ansible-language-server",
    "bash-language-server",
    "sqls",
  },
  formatters = {
    "prettierd",
    "stylua",
    "goimports",
    "sqlfluff",
    "shfmt",
  },
  linters = {
    "yamllint",
    "shellcheck",
    "ansible-lint",
  },
}

function M.check()
  vim.health.start("config: external tools")

  for category, executables in pairs(tools) do
    for _, exe in ipairs(executables) do
      if vim.fn.executable(exe) == 1 then
        vim.health.ok(category .. ": " .. exe)
      else
        vim.health.warn(category .. ": " .. exe .. " not found")
      end
    end
  end
end

return M
