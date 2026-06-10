-- Leaders
vim.g.mapleader = ","
vim.g.maplocalleader = "\\"

-- Options
-- yank and paste with the system clipboard
vim.opt.clipboard = "unnamedplus"
-- do not confuse crontab. see :help crontab
vim.opt.backupcopy = "yes"

-- Display settings
-- show trailing whitespace
vim.opt.list = true
vim.opt.listchars = { tab = "▸ ", trail = "▫" }
-- show line numbers
vim.opt.number = true
vim.opt.relativenumber = true
-- stable sign column
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.breakindent = true
vim.opt.confirm = true
vim.opt.updatetime = 250
vim.opt.inccommand = "split"
vim.opt.smoothscroll = true

-- Indenting
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.tabstop = 2

-- Undo configuration
-- keep undo history across sessions by storing it in a file
local undo_dir_path = vim.fn.stdpath("state") .. "/undo"
vim.fn.mkdir(undo_dir_path, "p")
vim.opt.undodir = undo_dir_path
vim.opt.undofile = true

-- Spelling (prose filetypes only)
vim.opt.spelllang = "en_us"
vim.opt.spellsuggest = "best,9"

-- Search settings
-- case-insensitive search
vim.opt.ignorecase = true
-- case-sensitive search if any caps
vim.opt.smartcase = true
-- show context above/below cursorline
vim.opt.scrolloff = 5

-- Folding (nvim-ufo)
vim.opt.foldcolumn = "1"
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99

-- Constants
local FT_ANSIBLE = "yaml.ansible"
local COLORSCHEME = "gruvbox"
local CLOSE_KEYS = { "q", "<esc>" }

-- Helpers

--- Invert a tool→filetypes map into a filetype→tools map.
local function invert_tool_fts(tool_fts)
  local by_ft = {}
  for tool, fts in pairs(tool_fts) do
    for _, ft in ipairs(fts) do
      by_ft[ft] = by_ft[ft] or {}
      by_ft[ft][#by_ft[ft] + 1] = tool
    end
  end
  return by_ft
end

--- Build a table mapping each CLOSE_KEYS entry to a given action.
local function close_keymaps(action)
  local t = {}
  for _, key in ipairs(CLOSE_KEYS) do
    t[key] = action
  end
  return t
end

-- Filetype detection. Keys are Lua patterns matched against the full path;
-- the positive priority makes them win over plain extension lookup (which
-- would otherwise resolve *.yml to yaml first). $ anchors don't work here.
local ansible_patterns = {}
for _, pat in ipairs({
  ".*/playbooks/.*%.ya?ml",
  ".*playbook.*%.ya?ml",
  ".*/roles/.*/tasks/.*%.ya?ml",
  ".*/roles/.*/handlers/.*%.ya?ml",
  ".*/site%.ya?ml",
  ".*/group_vars/.*",
  ".*/host_vars/.*",
  ".*/inventory",
  ".*/ansible%.cfg",
}) do
  ansible_patterns[pat] = { FT_ANSIBLE, { priority = 10 } }
end

vim.filetype.add({
  extension = { tftpl = "yaml" },
  pattern = ansible_patterns,
})

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- LSP servers (defined before lazy.setup so plugin config functions can reference it)
local lsp_servers = {
  lua_ls = {
    mason_name = "lua-language-server",
    settings = {
      Lua = {
        diagnostics = {
          globals = {
            "hs",
            "spoon",
          },
        },
      },
    },
  },
  gopls = {
    settings = {
      gopls = {
        analyses = {
          unusedparams = true,
          shadow = true,
        },
        staticcheck = true,
        gofumpt = true,
      },
    },
  },
  terraformls = {
    mason_name = "terraform-ls",
  },
  pyright = {
    settings = {
      python = {
        analysis = {
          typeCheckingMode = "strict",
          autoSearchPaths = true,
          useLibraryCodeForTypes = true,
          autoImportCompletions = true,
          diagnosticMode = "workspace",
        },
      },
    },
  },
  ruff = {},
  ts_ls = {
    mason_name = "typescript-language-server",
  },
  yamlls = {
    mason_name = "yaml-language-server",
  },
  vimls = {
    mason_name = "vim-language-server",
  },
  ansiblels = {
    mason_name = "ansible-language-server",
  },
  bashls = {
    mason_name = "bash-language-server",
  },
  sqlls = {},
  -- Installed via Nix (nix/packages.nix), not mason; bin names the executable
  -- for :checkhealth.
  nil_ls = {
    mason_name = false,
    bin = "nil",
  },
}

-- Formatter config (defined before lazy.setup so plugin config functions can reference it)
local formatter_fts = {
  prettierd = {
    "javascript",
    "typescript",
    "javascriptreact",
    "typescriptreact",
    "css",
    "json",
    "html",
    "markdown",
    "yaml",
  },
  stylua = { "lua" },
  goimports = { "go" },
  nixfmt = { "nix" },
  sqlfluff = { "sql" },
  ruff_format = { "python" },
  shfmt = { "sh", "bash" },
}

local formatters_by_ft = invert_tool_fts(formatter_fts)

-- Linter config (defined before lazy.setup so plugin config functions can reference it)
local linter_fts = {
  sqlfluff = { "sql" },
  yamllint = { "yaml" },
  ruff = { "python" },
  shellcheck = { "sh", "bash" },
  ["ansible-lint"] = { FT_ANSIBLE },
}

local linters_by_ft = invert_tool_fts(linter_fts)

-- Shared LSP mason names (used by health + mason-tool-installer).
-- mason_name = false marks Nix-installed servers: skipped for mason, still
-- health-checked via their bin name.
local lsp_mason_names = {}
local health_lsps = {}
for name, opts in pairs(lsp_servers) do
  if opts.mason_name ~= false then
    lsp_mason_names[#lsp_mason_names + 1] = opts.mason_name or name
  end
  health_lsps[#health_lsps + 1] = opts.bin or opts.mason_name or name
end

-- Expose tool lists for :checkhealth config
local health_formatters = {}
for name in pairs(formatter_fts) do
  health_formatters[#health_formatters + 1] = name == "ruff_format" and "ruff" or name
end
local health_linters = vim.tbl_keys(linter_fts)
vim.g._health_tools = { lsp = health_lsps, formatters = health_formatters, linters = health_linters }

local second_brain_nvim_dir = "~/ghq/github.com/joaosa/second-brain-tools/extensions/nvim"
require("lazy").setup({
  -- my work
  {
    dir = second_brain_nvim_dir,
    name = "second-brain",
    cond = function()
      return vim.uv.fs_stat(vim.fn.expand(second_brain_nvim_dir)) ~= nil
    end,
    build = "cargo build -p second-brain-nvim",
    init = function()
      vim.g.second_brain_vault_path = vim.fn.expand("~/second-brain")
    end,
    config = function()
      require("second_brain")
    end,
  },

  -- aesthetics
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000,
    opts = {},
    init = function()
      vim.cmd.colorscheme(COLORSCHEME)
    end,
  },
  { "nmac427/guess-indent.nvim", event = "BufRead", opts = {} },
  { "lewis6991/gitsigns.nvim", event = "BufRead", opts = {} },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "SmiteshP/nvim-navic", "nvim-tree/nvim-web-devicons" },
    opts = function()
      local navic = require("nvim-navic")
      return {
        options = { theme = COLORSCHEME },
        winbar = {
          lualine_c = {
            { navic.get_location, cond = navic.is_available },
          },
        },
      }
    end,
  },
  {
    "edkolev/tmuxline.vim",
    cmd = { "Tmuxline", "TmuxlineSnapshot" },
    init = function()
      vim.g.tmuxline_preset = {
        a = "#(whoami)",
        b = '#(gitmux "#{pane_current_path}")',
        win = { "#I", "#W" },
        cwin = { "#I", "#W" },
        y = {
          "%Y-%m-%d",
          "%R",
          "#{?pane_synchronized,#[bold],#[dim]}SYNC",
          "#{online_status}",
        },
        options = { ["status-justify"] = "left" },
      }

      vim.g.tmuxline_separators = {
        left = "",
        left_alt = "",
        right = "",
        right_alt = "",
        space = " ",
      }

      local accent = { "#282828", "#a89b89" }
      local muted = { "#847c72", "#534d4a" }
      vim.g.tmuxline_theme = {
        a = accent,
        b = muted,
        c = muted,
        x = muted,
        y = muted,
        z = accent,
        win = muted,
        cwin = accent,
        bg = { "#534d4a", "#534d4a" },
      }
    end,
  },
  {
    "folke/snacks.nvim",
    lazy = false,
    opts = {
      dashboard = { enabled = true },
      indent = { enabled = true },
      notifier = { enabled = true },
      quickfile = { enabled = true },
      words = { enabled = true },
      zen = { enabled = true },
      bigfile = { enabled = true },
    },
  },

  -- behaviour
  { "m4xshen/hardtime.nvim", event = "VeryLazy", opts = {} },
  { "folke/persistence.nvim", event = "BufReadPre", opts = {} },
  { "kylechui/nvim-surround", event = "VeryLazy", opts = {} },
  { "tpope/vim-speeddating", event = "BufRead" },
  { "numToStr/Navigator.nvim", event = "VeryLazy", opts = {} },
  { "windwp/nvim-autopairs", event = "InsertEnter", opts = {} },
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      jump = { autojump = true },
      modes = { char = { enabled = false } },
    },
  },
  {
    "stevearc/oil.nvim",
    lazy = false,
    opts = {
      default_file_explorer = true,
      columns = { "icon" },
      view_options = {
        show_hidden = false,
      },
      keymaps = vim.tbl_extend("force", close_keymaps("actions.close"), {
        ["g."] = "actions.toggle_hidden",
      }),
    },
  },
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    event = "BufRead",
    opts = {
      provider_selector = function()
        return { "treesitter", "indent" }
      end,
    },
  },

  -- language syntax
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      { "nvim-treesitter/nvim-treesitter-textobjects", branch = "main" },
    },
    config = function()
      local ts = require("nvim-treesitter")
      ts.setup({})

      local ensure_installed = {
        "nix",
        "rust",
        "go",
        "lua",
        "python",
        "javascript",
        "typescript",
        "sql",
        "hcl",
        "terraform",
        "yaml",
        "json",
        "toml",
        "markdown",
        "markdown_inline",
        "diff",
        "bash",
        "make",
        "dockerfile",
        "gitcommit",
        "git_rebase",
        "vim",
        "vimdoc",
      }

      -- Set of installed parsers, scanned once (get_installed hits the filesystem).
      -- Install any missing parsers (replaces master's ensure_installed + auto_install).
      local installed = {}
      for _, parser in ipairs(ts.get_installed("parsers")) do
        installed[parser] = true
      end
      local missing = vim.tbl_filter(function(parser)
        return not installed[parser]
      end, ensure_installed)
      if #missing > 0 then
        ts.install(missing)
        for _, parser in ipairs(missing) do
          installed[parser] = true
        end
      end

      vim.treesitter.language.register("diff", "git")

      -- On main, highlighting/indent are enabled per-buffer. Folding is left to nvim-ufo
      -- (its treesitter provider), so we deliberately do not set foldexpr here.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("UserTreesitter", { clear = true }),
        callback = function(ev)
          local lang = vim.treesitter.language.get_lang(vim.bo[ev.buf].filetype)
          if not lang or not installed[lang] then
            return
          end
          pcall(vim.treesitter.start, ev.buf, lang)
          vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })

      -- Textobject definitions: single source of truth for select, move, swap, and peek keymaps.
      -- sel: a/i select key, mode: selection mode, mov: ]/[ move key
      -- mov_suf: "inner" overrides default "outer" for move/swap queries
      -- swap: { next_key, prev_key }, peek: peek definition key
      local ts_objects = {
        { name = "function", sel = "f", mode = "V", mov = "f", swap = { "f", "F" }, peek = "f" },
        { name = "class", sel = "c", mode = "V", mov = "k", peek = "c" },
        { name = "parameter", sel = "a", mode = "v", mov = "a", mov_suf = "inner", swap = { "n", "p" } },
        { name = "conditional", sel = "i", mode = "V", mov = "i" },
        { name = "loop", sel = "l", mode = "V", mov = "l" },
        { name = "comment", sel = "/" },
        { name = "block", sel = "b", mode = "V" },
        { name = "statement", sel = "s", mov = "z" },
        { name = "assignment", sel = "=" },
        { name = "call", sel = "F" },
      }

      -- Per-query selection modes (keyed by query string), passed into textobjects setup.
      local selection_modes = {}
      for _, obj in ipairs(ts_objects) do
        if obj.mode then
          selection_modes["@" .. obj.name .. ".outer"] = obj.mode
        end
      end

      require("nvim-treesitter-textobjects").setup({
        select = {
          lookahead = true,
          selection_modes = selection_modes,
        },
      })

      local sel = require("nvim-treesitter-textobjects.select")
      local move = require("nvim-treesitter-textobjects.move")
      local swap = require("nvim-treesitter-textobjects.swap")
      local rep = require("nvim-treesitter-textobjects.repeatable_move")

      --- Peek a textobject's definition in a floating window (replaces master's lsp_interop).
      local function peek(query)
        local range = require("nvim-treesitter-textobjects.shared").textobject_at_point(query, "textobjects", 0)
        if not range then
          vim.notify("No " .. query .. " under cursor", vim.log.levels.INFO)
          return
        end
        local lines = vim.api.nvim_buf_get_text(0, range[1], range[2], range[4], range[5], {})
        vim.lsp.util.open_floating_preview(lines, vim.bo.filetype, { border = "rounded" })
      end

      local map = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { desc = desc, silent = true })
      end

      for _, obj in ipairs(ts_objects) do
        local outer = "@" .. obj.name .. ".outer"
        local inner = "@" .. obj.name .. ".inner"
        local query = obj.mov_suf == "inner" and inner or outer

        -- select (operator-pending + visual)
        map({ "x", "o" }, "a" .. obj.sel, function()
          sel.select_textobject(outer)
        end, "Select outer " .. obj.name)
        map({ "x", "o" }, "i" .. obj.sel, function()
          sel.select_textobject(inner)
        end, "Select inner " .. obj.name)

        -- move (goto_* are internally repeatable via ; and ,)
        if obj.mov then
          map({ "n", "x", "o" }, "]" .. obj.mov, function()
            move.goto_next_start(query)
          end, "Next " .. obj.name)
          map({ "n", "x", "o" }, "]" .. obj.mov:upper(), function()
            move.goto_next_end(query)
          end, "Next " .. obj.name .. " end")
          map({ "n", "x", "o" }, "[" .. obj.mov, function()
            move.goto_previous_start(query)
          end, "Previous " .. obj.name)
          map({ "n", "x", "o" }, "[" .. obj.mov:upper(), function()
            move.goto_previous_end(query)
          end, "Previous " .. obj.name .. " end")
        end

        -- swap
        if obj.swap then
          map("n", "<leader>s" .. obj.swap[1], function()
            swap.swap_next(query)
          end, "Swap next " .. obj.name)
          map("n", "<leader>s" .. obj.swap[2], function()
            swap.swap_previous(query)
          end, "Swap previous " .. obj.name)
        end

        -- peek
        if obj.peek then
          map("n", "<leader>p" .. obj.peek, function()
            peek(outer)
          end, "Peek " .. obj.name .. " definition")
        end
      end

      -- Repeat the last move with ; and , (like builtin f/t).
      map({ "n", "x", "o" }, ";", rep.repeat_last_move_next, "Repeat last move forward")
      map({ "n", "x", "o" }, ",", rep.repeat_last_move_previous, "Repeat last move backward")

      -- Incremental selection (removed on main; reimplemented with native treesitter).
      -- <CR> selects the node under cursor, then grows to the parent on repeat; <BS> shrinks.
      local incr_stack = {}

      local function set_visual(range)
        vim.cmd("normal! \27") -- leave any current visual mode
        vim.api.nvim_win_set_cursor(0, { range[1] + 1, range[2] })
        vim.cmd("normal! v")
        vim.api.nvim_win_set_cursor(0, { range[3] + 1, math.max(range[4] - 1, 0) })
      end

      local function incr_grow()
        local node = vim.treesitter.get_node()
        if not node then
          return
        end
        local mode = vim.api.nvim_get_mode().mode
        if mode == "v" or mode == "V" or mode == "\22" then
          -- grow: find the smallest ancestor whose range is strictly larger
          local cur = incr_stack[#incr_stack] or node
          local csr, csc, cer, cec = cur:range()
          local parent = cur:parent()
          while parent do
            local psr, psc, per, pec = parent:range()
            if psr ~= csr or psc ~= csc or per ~= cer or pec ~= cec then
              break
            end
            parent = parent:parent()
          end
          if not parent then
            return
          end
          node = parent
        else
          incr_stack = {}
        end
        local sr, sc, er, ec = node:range()
        incr_stack[#incr_stack + 1] = node
        set_visual({ sr, sc, er, ec })
      end

      local function incr_shrink()
        if #incr_stack <= 1 then
          return
        end
        incr_stack[#incr_stack] = nil
        local sr, sc, er, ec = incr_stack[#incr_stack]:range()
        set_visual({ sr, sc, er, ec })
      end

      map("n", "<CR>", incr_grow, "Init/grow selection")
      map("x", "<CR>", incr_grow, "Grow selection")
      map("x", "<BS>", incr_shrink, "Shrink selection")
    end,
  },
  { "nvim-treesitter/nvim-treesitter-context", event = "BufRead", opts = {} },
  { "Wansmer/treesj", cmd = "TSJToggle", opts = {} },

  -- lsp
  -- Data-only on 0.11+: supplies each server's base config (cmd, filetypes,
  -- root markers) through its lsp/ runtime directory for vim.lsp.enable.
  { "neovim/nvim-lspconfig", lazy = false },
  {
    "mason-org/mason.nvim",
    lazy = false,
    opts = {},
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    lazy = false,
    dependencies = { "mason-org/mason.nvim" },
    config = function()
      local ensure_installed = vim.list_extend({}, lsp_mason_names)
      -- Derive formatter tools from formatter_fts (skip ruff_format — already
      -- installed as ruff LSP — and nixfmt, which comes from Nix)
      local formatter_skip = { ruff_format = true, nixfmt = true }
      for formatter in pairs(formatter_fts) do
        if not formatter_skip[formatter] then
          ensure_installed[#ensure_installed + 1] = formatter
        end
      end
      -- Derive linter tools from linter_fts (skip tools already installed as formatters or LSP servers)
      local linter_skip = { ruff = true, sqlfluff = true }
      for linter in pairs(linter_fts) do
        if not linter_skip[linter] then
          ensure_installed[#ensure_installed + 1] = linter
        end
      end
      require("mason-tool-installer").setup({
        ensure_installed = ensure_installed,
      })
    end,
  },
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    config = function()
      require("conform").setup({
        formatters_by_ft = vim.tbl_extend("force", formatters_by_ft, {
          ["_"] = { "trim_whitespace" },
        }),
        default_format_opts = {
          lsp_format = "fallback",
        },
        format_on_save = {
          timeout_ms = 2000,
        },
        formatters = {
          sqlfluff = {
            prepend_args = { "--dialect", "postgres" },
          },
        },
      })
    end,
  },
  {
    "mfussenegger/nvim-lint",
    event = "BufWritePost",
    config = function()
      require("lint").linters_by_ft = linters_by_ft

      local lint_group = vim.api.nvim_create_augroup("UserLint", { clear = true })

      vim.api.nvim_create_autocmd("BufWritePost", {
        group = lint_group,
        callback = function()
          require("lint").try_lint()
        end,
      })

      -- Auto-fix Ansible files after save (async)
      vim.api.nvim_create_autocmd("BufWritePost", {
        group = lint_group,
        pattern = { "*.yml", "*.yaml" },
        callback = function()
          if vim.bo.filetype == FT_ANSIBLE then
            local bufnr = vim.api.nvim_get_current_buf()
            local filepath = vim.fn.expand("%:p")
            vim.fn.jobstart({ "ansible-lint", "--fix", filepath }, {
              on_exit = function(_, code)
                if code ~= 0 then
                  return
                end
                vim.schedule(function()
                  if vim.api.nvim_buf_is_valid(bufnr) and not vim.bo[bufnr].modified then
                    vim.api.nvim_buf_call(bufnr, function()
                      vim.cmd.checktime()
                      require("lint").try_lint()
                    end)
                  end
                end)
              end,
            })
          end
        end,
      })
    end,
  },
  {
    "mrcjkb/rustaceanvim",
    version = "^6",
    ft = "rust",
    init = function()
      vim.g.rustaceanvim = function()
        return {
          server = {
            capabilities = require("blink.cmp").get_lsp_capabilities(),
            default_settings = {
              ["rust-analyzer"] = {
                check = {
                  command = "clippy",
                  extraArgs = { "--all-features", "--", "-D", "warnings" },
                },
              },
            },
          },
        }
      end
    end,
  },
  {
    "saecki/crates.nvim",
    event = "BufRead Cargo.toml",
    opts = {
      lsp = {
        enabled = true,
        actions = true,
        completion = true,
        hover = true,
      },
    },
  },

  -- lua development
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "~/.hammerspoon/Spoons/EmmyLua.spoon/annotations", words = { "hs%.", "spoon%." } },
      },
    },
  },

  -- autocomplete
  {
    "saghen/blink.cmp",
    version = "1.*",
    dependencies = {
      "rafamadriz/friendly-snippets",
      "Kaiser-Yang/blink-cmp-git",
    },
    opts = {
      keymap = { preset = "default" },
      appearance = { nerd_font_variant = "mono" },
      completion = {
        documentation = {
          auto_show = true,
          auto_show_delay_ms = 200,
        },
      },
      sources = {
        default = { "lazydev", "lsp", "path", "snippets", "buffer" },
        per_filetype = {
          gitcommit = { "git", "lsp", "path", "snippets", "buffer" },
        },
        providers = {
          lazydev = {
            name = "LazyDev",
            module = "lazydev.integrations.blink",
            score_offset = 100,
          },
          git = {
            module = "blink-cmp-git",
            name = "Git",
          },
        },
      },
      signature = { enabled = true },
    },
  },

  -- discoverability
  { "folke/which-key.nvim", event = "VeryLazy" },
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = {
      { "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
      "camgraff/telescope-tmux.nvim",
      "nvim-telescope/telescope-ui-select.nvim",
    },
    config = function()
      local telescope = require("telescope")
      local actions = require("telescope.actions")
      local trouble_telescope = require("trouble.sources.telescope").open
      telescope.setup({
        defaults = {
          mappings = {
            i = {
              ["<c-t>"] = trouble_telescope,
              ["<esc>"] = actions.close,
            },
            n = {
              ["<c-t>"] = trouble_telescope,
              ["q"] = actions.close,
            },
          },
        },
      })
      telescope.load_extension("fzf")
      telescope.load_extension("tmux")
      telescope.load_extension("ui-select")
    end,
  },
  {
    "aznhe21/actions-preview.nvim",
    opts = {
      telescope = {
        sorting_strategy = "ascending",
        layout_strategy = "vertical",
        layout_config = {
          prompt_position = "top",
          mirror = true,
        },
      },
    },
  },
  {
    "kosayoda/nvim-lightbulb",
    event = "LspAttach",
    opts = {
      priority = 20,
      autocmd = { enabled = true },
      sign = { enabled = true, text = "💡" },
    },
  },
  { "folke/todo-comments.nvim", event = "BufRead", opts = {} },
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {
      keys = close_keymaps("close"),
    },
  },

  -- external tools
  { "lervag/vimtex", ft = "tex" },
  { "pwntester/octo.nvim", cmd = "Octo", opts = {} },
  { "tpope/vim-dadbod", cmd = "DB" },
  {
    "NeogitOrg/neogit",
    cmd = "Neogit",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "sindrets/diffview.nvim",
      "nvim-telescope/telescope.nvim",
    },
    opts = {
      integrations = {
        diffview = true,
        telescope = true,
      },
      mappings = {
        status = close_keymaps("Close"),
      },
    },
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    opts = function()
      local dv_close = close_keymaps("<Cmd>DiffviewClose<CR>")
      return {
        enhanced_diff_hl = true,
        use_icons = true,
        keymaps = {
          view = dv_close,
          file_panel = dv_close,
          file_history_panel = dv_close,
        },
      }
    end,
  },
  {
    "akinsho/git-conflict.nvim",
    event = "BufRead",
    opts = { default_mappings = false },
    config = function(_, opts)
      require("git-conflict").setup(opts)
      vim.api.nvim_create_autocmd("User", {
        pattern = "GitConflictDetected",
        callback = function(ev)
          local buf = ev.buf
          local map = function(lhs, cmd, desc)
            vim.keymap.set("n", lhs, "<cmd>" .. cmd .. "<cr>", { buffer = buf, desc = desc })
          end
          map("co", "GitConflictChooseOurs", "Choose ours")
          map("ct", "GitConflictChooseTheirs", "Choose theirs")
          map("cb", "GitConflictChooseBoth", "Choose both")
          map("c0", "GitConflictChooseNone", "Choose none")
          map("]x", "GitConflictNextConflict", "Next conflict")
          map("[x", "GitConflictPrevConflict", "Prev conflict")
        end,
      })
    end,
  },
  {
    "sudo-tee/opencode.nvim",
    cmd = "Opencode",
    opts = {
      keymap_prefix = "<localleader>",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "MeanderingProgrammer/render-markdown.nvim",
        opts = {
          anti_conceal = { enabled = false },
          file_types = { "markdown", "opencode_output" },
        },
        ft = { "markdown", "opencode_output" },
      },
    },
  },
})

-- LSP configuration
-- vim.lsp.config() merges these into nvim-lspconfig's base configs; assigning
-- vim.lsp.config[name] would replace them wholesale (dropping cmd/filetypes).
vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
for server_name, opts in pairs(lsp_servers) do
  local lsp_opts = vim.tbl_extend("force", {}, opts)
  lsp_opts.mason_name = nil
  lsp_opts.bin = nil
  vim.lsp.config(server_name, lsp_opts)
end
vim.lsp.enable(vim.tbl_keys(lsp_servers))

-- Autocommands
-- NOTE: nvim-lint autocommands (UserLint group) are in the plugin's config function above.

-- Unified LSP attach handler (replaces per-server on_attach)
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client then
      return
    end

    -- Disable hover for ruff (pyright handles it)
    if client.name == "ruff" then
      client.server_capabilities.hoverProvider = false
    end

    if client.server_capabilities.documentSymbolProvider then
      require("nvim-navic").attach(client, event.buf)
    end
    if client.server_capabilities.inlayHintProvider then
      vim.lsp.inlay_hint.enable(true, { bufnr = event.buf })
    end
  end,
})

-- Enable spell checking for prose filetypes
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("UserSpell", { clear = true }),
  pattern = { "markdown", "text", "gitcommit", "tex" },
  callback = function()
    vim.opt_local.spell = true
  end,
})

-- Easy close for special buffers
local close_group = vim.api.nvim_create_augroup("UserClose", { clear = true })

local function set_close_keymaps(buf, desc)
  vim.bo[buf].buflisted = false
  for _, key in ipairs(CLOSE_KEYS) do
    vim.keymap.set("n", key, "<cmd>close<cr>", { buffer = buf, silent = true, desc = desc })
  end
end

vim.api.nvim_create_autocmd("FileType", {
  group = close_group,
  pattern = {
    "help",
    "man",
    "qf",
    "lspinfo",
    "checkhealth",
    "startuptime",
    "tsplayground",
    "PlenaryTestPopup",
    "opencode",
  },
  callback = function(event)
    set_close_keymaps(event.buf, "Close buffer")
  end,
})

-- Easy close for LSP floating windows
vim.api.nvim_create_autocmd("BufEnter", {
  group = close_group,
  callback = function()
    local win = vim.api.nvim_get_current_win()
    local config = vim.api.nvim_win_get_config(win)
    if config.relative ~= "" then
      set_close_keymaps(0, "Close floating window")
    end
  end,
})

-- Native line number toggling (replaces nvim-numbertoggle)
local numbertoggle_group = vim.api.nvim_create_augroup("UserNumberToggle", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "InsertLeave", "CmdlineLeave", "WinEnter" }, {
  group = numbertoggle_group,
  callback = function()
    if vim.o.nu and vim.api.nvim_get_mode().mode ~= "i" then
      vim.opt.relativenumber = true
    end
  end,
})

vim.api.nvim_create_autocmd({ "BufLeave", "FocusLost", "InsertEnter", "CmdlineEnter", "WinLeave" }, {
  group = numbertoggle_group,
  callback = function()
    if vim.o.nu then
      vim.opt.relativenumber = false
    end
  end,
})

-- Telescope previewer wrap
vim.api.nvim_create_autocmd("User", {
  group = vim.api.nvim_create_augroup("UserTelescope", { clear = true }),
  pattern = "TelescopePreviewerLoaded",
  callback = function()
    vim.wo.wrap = true
  end,
})

-- Diagnostics
vim.diagnostic.config({
  virtual_lines = { current_line = true },
  severity_sort = true,
})

-- Keymaps
local wk_keymaps = {
  -- LSP mappings
  {
    "gh",
    "<cmd>Trouble lsp_references toggle<cr>",
    desc = "LSP references",
  },
  {
    "gd",
    vim.lsp.buf.definition,
    desc = "LSP definition",
  },
  {
    "gD",
    vim.lsp.buf.declaration,
    desc = "LSP declaration",
  },
  {
    "gy",
    vim.lsp.buf.type_definition,
    desc = "LSP type definition",
  },
  {
    "gi",
    vim.lsp.buf.implementation,
    desc = "LSP implementation",
  },
  {
    "K",
    function()
      if vim.bo.filetype == "rust" and vim.fn.exists(":RustLsp") > 0 then
        vim.cmd.RustLsp({ "hover", "actions" })
      else
        vim.lsp.buf.hover()
      end
    end,
    desc = "LSP hover",
  },

  -- Code group
  { "<leader>c", group = "code" },
  {
    "<leader>ca",
    function()
      if vim.bo.filetype == "rust" and vim.fn.exists(":RustLsp") > 0 then
        vim.cmd.RustLsp("codeAction")
      else
        require("actions-preview").code_actions()
      end
    end,
    desc = "code action",
  },
  {
    "<leader>cd",
    vim.diagnostic.open_float,
    desc = "show cursor diagnostics",
  },
  {
    "<leader>ch",
    function()
      vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })
    end,
    desc = "toggle inlay hints",
  },
  {
    "<leader>cr",
    vim.lsp.buf.rename,
    desc = "rename symbol",
  },
  {
    "<leader>cf",
    function()
      require("conform").format({ lsp_format = "fallback" })
    end,
    desc = "format buffer",
  },

  -- Telescope group
  { "<leader>t", group = "telescope" },
  {
    "<leader>a",
    "<cmd>Telescope live_grep<cr>",
    desc = "search word",
  },
  {
    "<leader>tt",
    "<cmd>Telescope git_files<cr>",
    desc = "search versioned files",
  },
  {
    "<leader><space>",
    "<cmd>Telescope find_files<cr>",
    desc = "search files",
  },
  {
    "<leader>*",
    "<cmd>Telescope grep_string<cr>",
    desc = "search cursor",
  },
  {
    "<leader>:",
    "<cmd>Telescope command_history<cr>",
    desc = "command history",
  },
  {
    "<leader>tms",
    "<cmd>Telescope tmux sessions<cr>",
    desc = "tmux sessions",
  },
  {
    "<leader>tmw",
    "<cmd>Telescope tmux windows<cr>",
    desc = "tmux windows",
  },
  {
    "<leader>ts",
    "<cmd>Telescope treesitter<cr>",
    desc = "treesitter",
  },
  {
    "<leader>tz",
    "<cmd>Telescope spell_suggest<cr>",
    desc = "spelling",
  },
  {
    "<leader>m",
    "<cmd>Telescope man_pages<cr>",
    desc = "manpages",
  },
  {
    "<leader>r",
    "<cmd>Telescope resume<cr>",
    desc = "telescope resume",
  },

  -- Quickfix/session group
  { "<leader>q", group = "quickfix/session" },
  {
    "<leader>qf",
    "<cmd>Telescope quickfix<cr>",
    desc = "telescope quickfix",
  },
  {
    "<leader>w",
    "<cmd>Telescope loclist<cr>",
    desc = "telescope loclist",
  },

  -- Git mappings
  { "<leader>g", group = "git" },
  {
    "<leader>gg",
    "<cmd>Neogit<cr>",
    desc = "Neogit",
  },
  {
    "<leader>gws",
    "<cmd>Telescope git_status<cr>",
    desc = "git status",
  },
  {
    "<leader>gwd",
    "<cmd>DiffviewOpen<cr>",
    desc = "git diff",
  },
  {
    "<leader>gco",
    "<cmd>Gitsigns reset_buffer<cr>",
    desc = "git checkout",
  },
  {
    "<leader>gcop",
    "<cmd>Gitsigns reset_hunk<cr>",
    desc = "git checkout -p",
  },
  {
    "<leader>gia",
    "<cmd>Gitsigns stage_buffer<cr>",
    desc = "git add",
  },
  {
    "<leader>giap",
    "<cmd>Gitsigns stage_hunk<cr>",
    desc = "git add -p",
  },
  {
    "<leader>gir",
    "<cmd>Gitsigns reset_buffer_index<cr>",
    desc = "git reset",
  },
  {
    "<leader>gb",
    "<cmd>Gitsigns toggle_current_line_blame<cr>",
    desc = "git blame",
  },
  {
    "<leader>gl",
    "<cmd>DiffviewFileHistory %<cr>",
    desc = "git logs",
  },
  {
    "<leader>gL",
    "<cmd>DiffviewFileHistory<cr>",
    desc = "git logs (all)",
  },
  {
    "<leader>gp",
    "<cmd>Octo pr create<cr>",
    desc = "git pr",
  },
  {
    "<leader>gc",
    "<cmd>GitConflictListQf<cr>",
    desc = "git conflicts",
  },

  -- Trouble mappings
  { "<leader>x", group = "diagnostics" },
  {
    "<leader>xx",
    "<cmd>Trouble diagnostics toggle<cr>",
    desc = "diagnostics",
  },
  {
    "<leader>xd",
    "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
    desc = "buffer diagnostics",
  },
  {
    "<leader>xq",
    "<cmd>Trouble qflist toggle<cr>",
    desc = "quickfix",
  },
  {
    "<leader>xl",
    "<cmd>Trouble loclist toggle<cr>",
    desc = "loclist",
  },
  {
    "<leader>xt",
    "<cmd>Trouble todo toggle<cr>",
    desc = "todos",
  },

  -- Treesitter text object swap mappings
  { "<leader>s", group = "swap" },

  -- Treesitter peek definition mappings
  { "<leader>p", group = "peek" },

  -- Rust mappings
  { "<localleader>r", group = "rust", ft = "rust" },

  -- Go mappings
  { "<localleader>g", group = "go", ft = "go" },

  -- Python mappings
  { "<localleader>p", group = "python", ft = "python" },
  {
    "<localleader>pv",
    function()
      local result = vim.fn.system({ "python3", "-c", "import sys; print(sys.executable)" })
      if vim.v.shell_error ~= 0 then
        vim.notify("python3 not found", vim.log.levels.WARN)
        return
      end
      vim.notify(vim.trim(result), vim.log.levels.INFO)
    end,
    desc = "Show Python path",
    ft = "python",
  },
  {
    "<localleader>pi",
    function()
      vim.lsp.buf.code_action({ context = { only = { "source.organizeImports" } } })
    end,
    desc = "Organize imports",
    ft = "python",
  },

  -- Markdown mappings
  { "<localleader>l", group = "markdown", ft = "markdown" },
  {
    "<localleader>lt",
    function()
      local line = vim.api.nvim_get_current_line()
      if line:match("%- %[ %]") then
        vim.api.nvim_set_current_line((line:gsub("%- %[ %]", "- [x]", 1)))
      elseif line:match("%- %[x%]") then
        vim.api.nvim_set_current_line((line:gsub("%- %[x%]", "- [ ]", 1)))
      end
    end,
    desc = "toggle checkbox",
    ft = "markdown",
  },
  {
    "<localleader>ll",
    "<cmd>RenderMarkdown toggle<cr>",
    desc = "toggle markdown rendering",
    ft = "markdown",
  },

  -- Opencode mappings
  { "<localleader>o", group = "opencode" },
  {
    "<localleader>og",
    "<cmd>Opencode<cr>",
    desc = "opencode toggle",
    mode = { "n", "v" },
  },
  {
    "<localleader>oi",
    "<cmd>Opencode open input<cr>",
    desc = "opencode open input",
    mode = { "n", "v" },
  },
  {
    "<localleader>oo",
    "<cmd>Opencode open output<cr>",
    desc = "opencode open output",
    mode = { "n", "v" },
  },
  {
    "<localleader>ot",
    "<cmd>Opencode toggle focus<cr>",
    desc = "opencode toggle focus",
    mode = { "n", "v" },
  },
  {
    "<localleader>oq",
    "<cmd>Opencode close<cr>",
    desc = "opencode close",
    mode = { "n", "v" },
  },

  -- Navigation mappings
  {
    "]t",
    function()
      require("todo-comments").jump_next()
    end,
    desc = "Next todo comment",
  },
  {
    "[t",
    function()
      require("todo-comments").jump_prev()
    end,
    desc = "Previous todo comment",
  },

  {
    "]c",
    function()
      if vim.wo.diff then
        return "]c"
      end
      vim.schedule(function()
        require("gitsigns").next_hunk()
      end)
      return "<Ignore>"
    end,
    desc = "Next git hunk",
    expr = true,
  },
  {
    "[c",
    function()
      if vim.wo.diff then
        return "[c"
      end
      vim.schedule(function()
        require("gitsigns").prev_hunk()
      end)
      return "<Ignore>"
    end,
    desc = "Previous git hunk",
    expr = true,
  },

  -- Spelling navigation (using vim defaults)
  { "]s", desc = "Next misspelled word" },
  { "[s", desc = "Previous misspelled word" },

  -- Quick typo fixes
  {
    "<leader>f",
    "1z=",
    desc = "Fix typo with first suggestion",
  },
  {
    "<leader>F",
    "<cmd>normal! [s1z=<cr>",
    desc = "Fix previous typo with first suggestion",
  },

  -- Session mappings (persistence.nvim)
  {
    "<leader>qs",
    function()
      require("persistence").load()
    end,
    desc = "restore session",
  },
  {
    "<leader>ql",
    function()
      require("persistence").load({ last = true })
    end,
    desc = "restore last session",
  },
  {
    "<leader>qd",
    function()
      require("persistence").stop()
    end,
    desc = "stop session recording",
  },

  -- <esc><esc> mappings
  { "<esc><esc>", "<cmd>noh<cr>", desc = "clear the highlight from the last search" },
  { "<esc><esc>", [[<C-\><C-n>]], desc = "Exit terminal insert mode", mode = "t" },

  -- file explorer
  { "<leader>e", "<cmd>Oil<cr>", desc = "file explorer" },
}

-- Go keymaps (generated)
local go_keymaps = {
  {
    "t",
    function()
      return "test " .. vim.fn.expand("%")
    end,
    "Run tests in current file",
  },
  {
    "T",
    function()
      return "test ./..."
    end,
    "Run all tests",
  },
  {
    "r",
    function()
      return "run " .. vim.fn.expand("%")
    end,
    "Run current file",
  },
  {
    "b",
    function()
      return "build"
    end,
    "Build package",
  },
}
for _, m in ipairs(go_keymaps) do
  wk_keymaps[#wk_keymaps + 1] = {
    "<localleader>g" .. m[1],
    function()
      vim.cmd("split | term go " .. m[2]())
    end,
    desc = m[3],
    ft = "go",
  }
end

-- Rust keymaps (generated)
local rust_keymaps = {
  { "r", "runnables", "runnables" },
  { "t", "testables", "testables" },
  { "e", "expandMacro", "expand macro" },
  { "o", "openDocs", "open docs" },
  { "c", "openCargo", "open Cargo.toml" },
  { "p", "parentModule", "parent module" },
  { "x", { "explainError", "current" }, "explain error" },
}
for _, m in ipairs(rust_keymaps) do
  wk_keymaps[#wk_keymaps + 1] = {
    "<localleader>r" .. m[1],
    function()
      if vim.fn.exists(":RustLsp") > 0 then
        vim.cmd.RustLsp(m[2])
      end
    end,
    desc = "Rust " .. m[3],
    ft = "rust",
  }
end

-- Diagnostic navigation keymaps (generated)
local diag_keymaps = {
  { "]e", 1, nil, "Next diagnostic" },
  { "[e", -1, nil, "Previous diagnostic" },
  { "]E", 1, "ERROR", "Next error" },
  { "[E", -1, "ERROR", "Previous error" },
}
for _, m in ipairs(diag_keymaps) do
  local opts = { count = m[2] }
  if m[3] then
    opts.severity = vim.diagnostic.severity[m[3]]
  end
  wk_keymaps[#wk_keymaps + 1] = {
    m[1],
    function()
      vim.diagnostic.jump(opts)
    end,
    desc = m[4],
  }
end

-- Navigator keymaps (generated)
local nav_keymaps = {
  { "h", "Left", "left" },
  { "l", "Right", "right" },
  { "k", "Up", "up" },
  { "j", "Down", "down" },
  { "p", "Previous", "previous" },
}
for _, m in ipairs(nav_keymaps) do
  wk_keymaps[#wk_keymaps + 1] = {
    "<c-" .. m[1] .. ">",
    "<cmd>Navigator" .. m[2] .. "<cr>",
    desc = "Navigate " .. m[3],
    mode = { "n", "t" },
  }
end

-- Fold keymaps (generated)
local fold_keymaps = {
  { "zR", "openAllFolds", "open all folds" },
  { "zM", "closeAllFolds", "close all folds" },
  { "zr", "openFoldsExceptKinds", "open folds by level" },
  { "zm", "closeFoldsWith", "close folds by level" },
}
for _, m in ipairs(fold_keymaps) do
  wk_keymaps[#wk_keymaps + 1] = {
    m[1],
    function()
      require("ufo")[m[2]]()
    end,
    desc = m[3],
  }
end

require("which-key").add(wk_keymaps)
