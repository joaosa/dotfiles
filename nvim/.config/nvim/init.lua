-- Plugins
vim.g.mapleader = ","
vim.g.maplocalleader = "\\"

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

-- Setup lazy.nvim
require("lazy").setup({
  -- my work
  {
    dir = "~/ghq/github.com/joaosa/second-brain-tools/nvim",
    name = "second-brain",
    cond = function()
      return vim.uv.fs_stat(vim.fn.expand("~/ghq/github.com/joaosa/second-brain-tools/nvim")) ~= nil
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
    config = function()
      vim.cmd.colorscheme("gruvbox")
    end,
  },
  "nvim-tree/nvim-web-devicons",
  { "nmac427/guess-indent.nvim", event = "BufRead", opts = {} },
  { "lewis6991/gitsigns.nvim", event = "BufRead", opts = {} },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "SmiteshP/nvim-navic" },
    config = function()
      local navic = require("nvim-navic")
      require("lualine").setup({
        options = { theme = "gruvbox" },
        winbar = {
          lualine_c = {
            { navic.get_location, cond = navic.is_available },
          },
        },
      })
    end,
  },
  { "edkolev/tmuxline.vim", cmd = { "Tmuxline", "TmuxlineSnapshot" } },
  {
    "folke/snacks.nvim",
    priority = 1000,
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
  {
    "numToStr/Navigator.nvim",
    event = "VeryLazy",
    config = function()
      require("Navigator").setup()
    end,
  },
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
      keymaps = {
        ["q"] = "actions.close",
        ["<esc>"] = "actions.close",
        ["g."] = "actions.toggle_hidden",
      },
    },
  },
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    event = "BufRead",
    config = function()
      require("ufo").setup({
        provider_selector = function()
          return { "treesitter", "indent" }
        end,
      })
    end,
  },

  -- language syntax
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    dependencies = {
      "nvim-treesitter/nvim-treesitter-textobjects",
      "nvim-treesitter/nvim-treesitter-context",
    },
    config = function()
      -- Textobject definitions: single source of truth for select, move, swap, and peek keymaps
      -- sel: a/i select key, mode: selection mode, mov: ]/[ move key
      -- mov_suf: "inner" overrides default "outer" for move/swap queries
      -- swap: { next_key, prev_key }, peek: peek definition key
      local ts_objects = {
        { name = "function",    sel = "f", mode = "V", mov = "f",                    swap = { "f", "F" }, peek = "f" },
        { name = "class",       sel = "c", mode = "V", mov = "k",                                         peek = "c" },
        { name = "parameter",   sel = "a", mode = "v", mov = "a", mov_suf = "inner", swap = { "n", "p" } },
        { name = "conditional", sel = "i", mode = "V", mov = "i" },
        { name = "loop",        sel = "l", mode = "V", mov = "l" },
        { name = "comment",     sel = "/" },
        { name = "block",       sel = "b", mode = "V" },
        { name = "statement",   sel = "s",             mov = "z" },
        { name = "assignment",  sel = "=" },
        { name = "call",        sel = "F" },
      }

      local select_keymaps, select_modes = {}, {}
      local move = {
        enable = true, set_jumps = true,
        goto_next_start = {}, goto_next_end = {},
        goto_previous_start = {}, goto_previous_end = {},
      }
      local swap_next, swap_prev = {}, {}
      local peek_defs = {}

      for _, obj in ipairs(ts_objects) do
        local outer = "@" .. obj.name .. ".outer"
        local inner = "@" .. obj.name .. ".inner"
        local query = obj.mov_suf == "inner" and inner or outer

        select_keymaps["a" .. obj.sel] = outer
        select_keymaps["i" .. obj.sel] = inner
        if obj.mode then select_modes[outer] = obj.mode end

        if obj.mov then
          move.goto_next_start["]" .. obj.mov] = { query = query, desc = "Next " .. obj.name }
          move.goto_next_end["]" .. obj.mov:upper()] = { query = query, desc = "Next " .. obj.name .. " end" }
          move.goto_previous_start["[" .. obj.mov] = { query = query, desc = "Previous " .. obj.name }
          move.goto_previous_end["[" .. obj.mov:upper()] = { query = query, desc = "Previous " .. obj.name .. " end" }
        end

        if obj.swap then
          swap_next["<leader>s" .. obj.swap[1]] = { query = query, desc = "Swap next " .. obj.name }
          swap_prev["<leader>s" .. obj.swap[2]] = { query = query, desc = "Swap previous " .. obj.name }
        end

        if obj.peek then
          peek_defs["<leader>p" .. obj.peek] = { query = outer, desc = "Peek " .. obj.name .. " definition" }
        end
      end

      require("nvim-treesitter.configs").setup({
        highlight = {
          enable = true,
          -- handle links for Obsidian
          additional_vim_regex_highlighting = { "markdown" },
        },

        ensure_installed = {
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
        },

        auto_install = true,

        incremental_selection = {
          enable = true,
          keymaps = {
            init_selection = "<CR>",
            node_incremental = "<CR>",
            scope_incremental = false,
            node_decremental = "<BS>",
          },
        },

        textobjects = {
          select = {
            enable = true,
            lookahead = true,
            keymaps = select_keymaps,
            selection_modes = select_modes,
          },
          move = move,
          swap = {
            enable = true,
            swap_next = swap_next,
            swap_previous = swap_prev,
          },
          lsp_interop = {
            enable = true,
            border = "none",
            floating_preview_opts = {},
            peek_definition_code = peek_defs,
          },
        },
      })

      vim.treesitter.language.register("diff", "git")
      require("treesitter-context").setup()
    end,
  },

  -- lsp
  "williamboman/mason.nvim",
  "williamboman/mason-lspconfig.nvim",
  "WhoIsSethDaniel/mason-tool-installer.nvim",
  "neovim/nvim-lspconfig",
  "stevearc/conform.nvim",
  "mfussenegger/nvim-lint",
  { "Wansmer/treesj", cmd = "TSJToggle", opts = {} },
  {
    "mrcjkb/rustaceanvim",
    version = "^5",
    lazy = false,
    init = function()
      vim.g.rustaceanvim = function()
        return {
          server = {
            on_attach = function(client, bufnr)
              if client.server_capabilities.documentSymbolProvider then
                require("nvim-navic").attach(client, bufnr)
              end
              if client.server_capabilities.inlayHintProvider then
                vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
              end
            end,
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
        default = { "lsp", "path", "snippets", "buffer" },
        per_filetype = {
          gitcommit = { "git", "lsp", "path", "snippets", "buffer" },
        },
        providers = {
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
  "folke/which-key.nvim",
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
      telescope.setup({
        defaults = {
          mappings = {
            i = {
              ["<c-t>"] = require("trouble.sources.telescope").open,
              ["<esc>"] = actions.close,
            },
            n = {
              ["<c-t>"] = require("trouble.sources.telescope").open,
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
  { "folke/todo-comments.nvim", event = "BufRead", opts = {} },
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {
      keys = {
        ["q"] = "close",
        ["<esc>"] = "close",
      },
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
        status = {
          ["q"] = "Close",
          ["<esc>"] = "Close",
        },
      },
    },
  },
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    opts = {
      enhanced_diff_hl = true,
      use_icons = true,
      keymaps = {
        view = {
          ["q"] = "<Cmd>DiffviewClose<CR>",
          ["<esc>"] = "<Cmd>DiffviewClose<CR>",
        },
        file_panel = {
          ["q"] = "<Cmd>DiffviewClose<CR>",
          ["<esc>"] = "<Cmd>DiffviewClose<CR>",
        },
        file_history_panel = {
          ["q"] = "<Cmd>DiffviewClose<CR>",
          ["<esc>"] = "<Cmd>DiffviewClose<CR>",
        },
      },
    },
  },
  {
    "akinsho/git-conflict.nvim",
    event = "BufRead",
    opts = {
      default_mappings = true,
      disable_diagnostics = false,
      list_opener = "copen",
    },
  },
  {
    "sudo-tee/opencode.nvim",
    cmd = "Opencode",
    config = function()
      require("opencode").setup({
        keymap_prefix = "<localleader>",
      })
    end,
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

-- Options
-- yank and paste with the system clipboard
vim.opt.clipboard = "unnamedplus"
-- do not confuse crontab. see :help crontab
vim.opt.backupcopy = "yes"
-- do not store swap files on the current dir (remove .)
vim.opt.directory:remove(".")

-- Display settings
-- show trailing whitespace
vim.opt.list = true
vim.opt.listchars = { tab = "▸ ", trail = "▫" }
-- show line numbers
vim.opt.number = true
-- stable sign column
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.breakindent = true
vim.opt.confirm = true
vim.opt.updatetime = 250
vim.opt.inccommand = "split"

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
vim.api.nvim_create_autocmd("User", {
  pattern = "TelescopePreviewerLoaded",
  command = "setlocal wrap",
})

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
vim.opt.foldenable = true

-- Autocommands
vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function()
    if #require("conform").list_formatters() > 0 then
      return
    end
    local view = vim.fn.winsaveview()
    vim.cmd.keeppatterns([[%s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- Enable spell checking for prose filetypes
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "markdown", "text", "gitcommit", "tex" },
  callback = function()
    vim.opt_local.spell = true
  end,
})

-- Markdown-specific keymaps
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.keymap.set("n", "<localleader>lt", function()
      local line = vim.api.nvim_get_current_line()
      if line:match("%- %[ %]") then
        vim.api.nvim_set_current_line((line:gsub("%- %[ %]", "- [x]", 1)))
      elseif line:match("%- %[x%]") then
        vim.api.nvim_set_current_line((line:gsub("%- %[x%]", "- [ ]", 1)))
      end
    end, { buffer = true, desc = "toggle checkbox" })
  end,
})

-- Python-specific keymaps
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    vim.keymap.set("n", "<localleader>pv", function()
      vim.cmd("!python3 -c 'import sys; print(sys.executable)'")
    end, { buffer = true, desc = "Show Python path" })
    vim.keymap.set("n", "<localleader>pi", function()
      vim.lsp.buf.code_action({ context = { only = { "source.organizeImports" } } })
    end, { buffer = true, desc = "Organize imports" })
  end,
})

-- Go-specific keymaps
vim.api.nvim_create_autocmd("FileType", {
  pattern = "go",
  callback = function()
    vim.keymap.set("n", "<localleader>gt", "<cmd>!go test %<cr>", { buffer = true, desc = "Run tests in current file" })
    vim.keymap.set("n", "<localleader>gT", "<cmd>!go test ./...<cr>", { buffer = true, desc = "Run all tests" })
    vim.keymap.set("n", "<localleader>gr", "<cmd>!go run %<cr>", { buffer = true, desc = "Run current file" })
    vim.keymap.set("n", "<localleader>gb", "<cmd>!go build<cr>", { buffer = true, desc = "Build package" })
  end,
})

-- Easy close for special buffers
vim.api.nvim_create_autocmd("FileType", {
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
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true, desc = "Close buffer" })
    vim.keymap.set("n", "<esc>", "<cmd>close<cr>", { buffer = event.buf, silent = true, desc = "Close buffer" })
  end,
})

-- Easy close for LSP floating windows
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    local win = vim.api.nvim_get_current_win()
    local config = vim.api.nvim_win_get_config(win)
    if config.relative ~= "" then
      vim.keymap.set("n", "<esc>", "<cmd>close<cr>", { buffer = 0, silent = true, desc = "Close floating window" })
      vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = 0, silent = true, desc = "Close floating window" })
    end
  end,
})

-- Native line number toggling (replaces nvim-numbertoggle)
local numbertoggle_group = vim.api.nvim_create_augroup("NumberToggle", {})

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

-- tmuxline configuration
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
  left = "",
  left_alt = "",
  right = "",
  right_alt = "",
  space = " ",
}

vim.g.tmuxline_theme = {
  a = { "#282828", "#a89b89" },
  b = { "#847c72", "#534d4a" },
  c = { "#847c72", "#534d4a" },
  x = { "#847c72", "#534d4a" },
  y = { "#847c72", "#534d4a" },
  z = { "#282828", "#a89b89" },
  win = { "#847c72", "#534d4a" },
  cwin = { "#282828", "#a89b89" },
  bg = { "#534d4a", "#534d4a" },
}

-- Diagnostics
vim.diagnostic.config({
  virtual_lines = { current_line = true },
})

-- Keymaps
require("which-key").add({
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
    vim.lsp.buf.hover,
    desc = "LSP hover",
  },
  {
    "K",
    function() vim.cmd.RustLsp({ "hover", "actions" }) end,
    desc = "Rust hover actions",
    ft = "rust",
  },

  -- Leader mappings
  {
    "<leader>ca",
    vim.lsp.buf.code_action,
    desc = "code action",
  },
  {
    "<leader>ca",
    function() vim.cmd.RustLsp("codeAction") end,
    desc = "Rust code action",
    ft = "rust",
  },
  {
    "<leader>cd",
    vim.diagnostic.open_float,
    desc = "show cursor diagnostics",
  },
  {
    "<leader>ih",
    function()
      vim.lsp.inlay_hint.enable(
        not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }),
        { bufnr = 0 }
      )
    end,
    desc = "toggle inlay hints",
  },

  -- Telescope mappings
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
  { "<leader>t", group = "telescope" },
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
  { "<leader>c", group = "code" },
  {
    "<leader>:",
    "<cmd>Telescope command_history<cr>",
    desc = "command history",
  },
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
    "<leader>ss",
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
  {
    "<localleader>rr",
    function() vim.cmd.RustLsp("runnables") end,
    desc = "Rust runnables",
    ft = "rust",
  },
  {
    "<localleader>rt",
    function() vim.cmd.RustLsp("testables") end,
    desc = "Rust testables",
    ft = "rust",
  },
  {
    "<localleader>re",
    function() vim.cmd.RustLsp("expandMacro") end,
    desc = "Rust expand macro",
    ft = "rust",
  },
  {
    "<localleader>ro",
    function() vim.cmd.RustLsp("openDocs") end,
    desc = "Rust open docs",
    ft = "rust",
  },
  {
    "<localleader>rc",
    function() vim.cmd.RustLsp("openCargo") end,
    desc = "Rust open Cargo.toml",
    ft = "rust",
  },
  {
    "<localleader>rp",
    function() vim.cmd.RustLsp("parentModule") end,
    desc = "Rust parent module",
    ft = "rust",
  },
  {
    "<localleader>rx",
    function() vim.cmd.RustLsp({ "explainError", "current" }) end,
    desc = "Rust explain error",
    ft = "rust",
  },

  -- Local leader mappings
  {
    "<localleader>ll",
    "<cmd>RenderMarkdown toggle<cr>",
    desc = "toggle markdown rendering",
    ft = "markdown",
  },

  -- Opencode mappings
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

  -- Diagnostic navigation
  {
    "]e",
    function()
      vim.diagnostic.jump({ count = 1 })
    end,
    desc = "Next diagnostic",
  },
  {
    "[e",
    function()
      vim.diagnostic.jump({ count = -1 })
    end,
    desc = "Previous diagnostic",
  },
  {
    "]E",
    function()
      vim.diagnostic.jump({ count = 1, severity = vim.diagnostic.severity.ERROR })
    end,
    desc = "Next error",
  },
  {
    "[E",
    function()
      vim.diagnostic.jump({ count = -1, severity = vim.diagnostic.severity.ERROR })
    end,
    desc = "Previous error",
  },

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

  -- Navigation mappings (tmux/vim pane navigation)
  {
    "<c-h>",
    "<cmd>NavigatorLeft<cr>",
    desc = "Navigate left",
    mode = { "n", "t" },
  },
  {
    "<c-l>",
    "<cmd>NavigatorRight<cr>",
    desc = "Navigate right",
    mode = { "n", "t" },
  },
  {
    "<c-k>",
    "<cmd>NavigatorUp<cr>",
    desc = "Navigate up",
    mode = { "n", "t" },
  },
  {
    "<c-j>",
    "<cmd>NavigatorDown<cr>",
    desc = "Navigate down",
    mode = { "n", "t" },
  },
  {
    "<c-p>",
    "<cmd>NavigatorPrevious<cr>",
    desc = "Navigate previous",
    mode = { "n", "t" },
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

  -- Fold mappings (nvim-ufo)
  {
    "zR",
    function()
      require("ufo").openAllFolds()
    end,
    desc = "open all folds",
  },
  {
    "zM",
    function()
      require("ufo").closeAllFolds()
    end,
    desc = "close all folds",
  },
  {
    "zr",
    function()
      require("ufo").openFoldsExceptKinds()
    end,
    desc = "open folds by level",
  },
  {
    "zm",
    function()
      require("ufo").closeFoldsWith()
    end,
    desc = "close folds by level",
  },

  -- <esc><esc> mappings
  { "<esc><esc>", "<cmd>noh<cr>", desc = "clear the highlight from the last search" },
  { "<esc><esc>", [[<C-\><C-n>]], desc = "Exit terminal insert mode", mode = "t" },

  -- file explorer
  { "<leader>e", "<cmd>Oil<cr>", desc = "file explorer" },
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*.tftpl",
  command = "set filetype=yaml",
})

-- Ansible filetype detection
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = {
    "*/playbooks/*.yml",
    "*/playbooks/*.yaml",
    "*playbook*.yml",
    "*playbook*.yaml",
    "*/roles/*/tasks/*.yml",
    "*/roles/*/tasks/*.yaml",
    "*/roles/*/handlers/*.yml",
    "*/roles/*/handlers/*.yaml",
    "*/group_vars/*",
    "*/host_vars/*",
    "*/inventory",
    "*/ansible.cfg",
    "site.yml",
    "site.yaml",
  },
  callback = function()
    vim.bo.filetype = "yaml.ansible"
  end,
})

-- LSP / Formatters / Linters
local lsp_servers = {
  lua_ls = {
    Lua = {
      diagnostics = {
        globals = {
          "hs",
          "spoon",
          "vim",
        },
      },
      workspace = {
        library = {
          vim.fn.expand("~/.hammerspoon/Spoons/EmmyLua.spoon/annotations"),
        },
      },
    },
  },
  gopls = {
    gopls = {
      analyses = {
        unusedparams = true,
        shadow = true,
      },
      staticcheck = true,
      gofumpt = true,
    },
  },
  terraformls = {},
  pyright = {
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
  ruff = {},
  ts_ls = {},
  yamlls = {},
  vimls = {},
  ansiblels = {},
  bashls = {},
  sqlls = {},
}

require("mason").setup()

-- Setup capabilities for all servers
local capabilities = require("blink.cmp").get_lsp_capabilities()

-- Common on_attach function
local function on_attach(client, bufnr)
  if client.server_capabilities.documentSymbolProvider then
    require("nvim-navic").attach(client, bufnr)
  end
  if client.server_capabilities.inlayHintProvider then
    vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
  end
end

require("mason-lspconfig").setup({
  ensure_installed = vim.tbl_keys(lsp_servers),
})

-- Configure all LSP servers with Neovim 0.11 API
for server_name, server_settings in pairs(lsp_servers) do
  local config = {
    capabilities = capabilities,
    on_attach = on_attach,
    settings = server_settings,
  }

  -- Disable hover for ruff to avoid conflicts with pyright
  if server_name == "ruff" then
    config.handlers = {
      ["textDocument/hover"] = function() end,
    }
  end

  vim.lsp.config[server_name] = config
end

-- Enable all configured LSP servers
vim.lsp.enable(vim.tbl_keys(lsp_servers))

require("mason-tool-installer").setup({
  ensure_installed = {
    "stylua",
    "goimports",
    "prettierd",
    "sqlfluff",
    "yamllint",
    "ansible-lint",
    "ruff", -- Python linting and formatting
    "shfmt",
    "shellcheck",
  },
})

require("conform").setup({
  formatters_by_ft = {
    lua = { "stylua" },
    go = { "goimports" },
    javascript = { "prettierd" },
    typescript = { "prettierd" },
    javascriptreact = { "prettierd" },
    typescriptreact = { "prettierd" },
    css = { "prettierd" },
    json = { "prettierd" },
    html = { "prettierd" },
    markdown = { "prettierd" },
    yaml = { "prettierd" },
    sql = { "sqlfluff" },
    python = { "ruff_format" },
    sh = { "shfmt" },
    bash = { "shfmt" },
  },
  default_format_opts = {
    lsp_format = "fallback",
  },
  format_on_save = {
    timeout_ms = 1000,
  },
  formatters = {
    sqlfluff = {
      prepend_args = { "--dialect", "postgres" },
    },
  },
})

require("lint").linters_by_ft = {
  sql = { "sqlfluff" },
  yaml = { "yamllint" },
  python = { "ruff" },
  sh = { "shellcheck" },
  bash = { "shellcheck" },
}

vim.api.nvim_create_autocmd({ "BufWritePost" }, {
  callback = function()
    if require("lint").linters_by_ft[vim.bo.filetype] then
      require("lint").try_lint()
    end
  end,
})

-- Auto-fix Ansible files after save (async)
vim.api.nvim_create_autocmd("BufWritePost", {
  pattern = { "*.yml", "*.yaml" },
  callback = function()
    if vim.bo.filetype == "yaml.ansible" then
      local bufnr = vim.api.nvim_get_current_buf()
      local filepath = vim.fn.expand("%:p")
      vim.fn.jobstart({ "ansible-lint", "--fix", filepath }, {
        on_exit = function()
          -- Reload buffer after async lint completes, then refresh diagnostics
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(bufnr) and not vim.bo[bufnr].modified then
              vim.api.nvim_buf_call(bufnr, function()
                vim.cmd("checktime")
                require("lint").try_lint()
              end)
            end
          end)
        end,
      })
    end
  end,
})
