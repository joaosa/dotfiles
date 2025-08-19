-- Plugin configuration
vim.g.mapleader = ','

-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out,                            "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Setup lazy.nvim
require("lazy").setup({
  -- aesthetics
  "ellisonleao/gruvbox.nvim",
  "nvim-tree/nvim-web-devicons",
  "lukas-reineke/indent-blankline.nvim",
  "nmac427/guess-indent.nvim",
  "lewis6991/gitsigns.nvim",
  "nvim-lualine/lualine.nvim",
  "edkolev/tmuxline.vim",
  "folke/zen-mode.nvim",
  "goolord/alpha-nvim",

  -- behaviour
  "takac/vim-hardtime",
  "tpope/vim-obsession",
  "tpope/vim-surround",
  "tpope/vim-unimpaired",
  "tpope/vim-speeddating",
  "tpope/vim-repeat",
  "numToStr/Navigator.nvim",
  "szw/vim-g",
  "windwp/nvim-autopairs",

  -- language syntax
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
  },
  "nvim-treesitter/nvim-treesitter-textobjects",
  "nvim-treesitter/nvim-treesitter-context",
  "numToStr/Comment.nvim",

  -- lsp
  "williamboman/mason.nvim",
  "williamboman/mason-lspconfig.nvim",
  "neovim/nvim-lspconfig",
  "nvimtools/none-ls.nvim",
  "lukas-reineke/lsp-format.nvim",
  "Wansmer/treesj",

  -- autocomplete
  "hrsh7th/cmp-nvim-lsp",
  "hrsh7th/nvim-cmp",
  "hrsh7th/cmp-nvim-lsp-signature-help",
  "petertriho/cmp-git",

  -- snippets
  "L3MON4D3/LuaSnip",
  "saadparwaiz1/cmp_luasnip",
  "rafamadriz/friendly-snippets",

  -- discoverability
  "nvim-lua/plenary.nvim",
  "folke/which-key.nvim",
  "unblevable/quick-scope",
  "nvim-telescope/telescope.nvim",
  {
    'nvim-telescope/telescope-fzf-native.nvim',
    build = 'make'
  },
  "camgraff/telescope-tmux.nvim",
  "folke/todo-comments.nvim",
  "folke/trouble.nvim",
  "SmiteshP/nvim-navic",

  -- external tools
  "lervag/vimtex",
  "MeanderingProgrammer/render-markdown.nvim",
  "pwntester/octo.nvim",
  "kdheepak/lazygit.nvim",
  "tpope/vim-dadbod",
  "greggh/claude-code.nvim",
  {
    "olimorris/codecompanion.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
      "hrsh7th/nvim-cmp",
      "nvim-telescope/telescope.nvim",
      {
        "stevearc/dressing.nvim",
        opts = {
          input = {
            prefer_width = 0.3,
            max_width = 0.7,
          },
        },
      },
    },
    config = function()
      require("codecompanion").setup({
        strategies = {
          chat = {
            adapter = "ollama_coder",
            roles = {
              llm = "CodeCompanion",
              user = "You",
            },
          },
          inline = {
            adapter = "ollama_coder",
          },
          agent = {
            adapter = "ollama_coder",
          },
        },
        adapters = {
          claude = function()
            return require("codecompanion.adapters").extend("anthropic", {
              name = "claude",
              env = {
                api_key = "AVANTE_ANTHROPIC_API_KEY",
              },
              schema = {
                model = {
                  default = "claude-sonnet-4-20250514",
                },
              },
            })
          end,
          opus = function()
            return require("codecompanion.adapters").extend("anthropic", {
              name = "opus",
              env = {
                api_key = "AVANTE_ANTHROPIC_API_KEY",
              },
              schema = {
                model = {
                  default = "claude-opus-4-20250514",
                },
              },
            })
          end,
          kimi = function()
            return require("codecompanion.adapters").extend("openai", {
              name = "kimi",
              url = "https://api.moonshot.ai/v1",
              env = {
                api_key = "AVANTE_MOONSHOT_API_KEY",
              },
              schema = {
                model = {
                  default = "kimi-k2-0711-preview",
                },
              },
            })
          end,
          ollama_coder = function()
            return require("codecompanion.adapters").extend("ollama", {
              name = "ollama_coder",
              schema = {
                model = {
                  default = "qwen2.5-coder:32b"
                },
              },
            })
          end,
        },
        display = {
          action_palette = {
            width = 95,
            height = 10,
          },
          chat = {
            window = {
              layout = "vertical",
              width = 0.30,
              height = 0.85,
              relative = "editor",
              border = "rounded",
            },
            show_settings = true,
            show_token_count = true,
          },
          inline = {
            diff = {
              enabled = true,
              close_chat_at = 240,
            },
          },
        },
        prompt_library = {
          ["Custom Commit Message"] = {
            strategy = "chat",
            description = "Generate a conventional commit message",
            opts = {
              mapping = "<LocalLeader>agc",
              modes = { "n" },
            },
            prompts = {
              {
                role = "system",
                content =
                "You are an expert at writing conventional commit messages. Write a clear, concise commit message following the conventional commits format based on the staged changes.",
              },
              {
                role = "user",
                content = function()
                  return "Here are the staged changes:\n\n```\n" ..
                      vim.fn.system("git diff --staged") .. "\n```\n\nPlease write a conventional commit message."
                end,
              },
            },
          },
          ["Explain Code"] = {
            strategy = "chat",
            description = "Explain the selected code",
            opts = {
              mapping = "<LocalLeader>aex",
              modes = { "v" },
            },
            prompts = {
              {
                role = "system",
                content =
                "You are an expert programmer. Explain the provided code in detail, including what it does, how it works, and any notable patterns or techniques used.",
              },
              {
                role = "user",
                content = function(context)
                  return "Explain this code:\n\n```" ..
                      context.filetype ..
                      "\n" ..
                      require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line) .. "\n```"
                end,
              },
            },
          },
          ["Generate Tests"] = {
            strategy = "inline",
            description = "Generate unit tests for the selected code",
            opts = {
              mapping = "<LocalLeader>agt",
              modes = { "v" },
            },
            prompts = {
              {
                role = "system",
                content =
                "You are a testing expert. Generate comprehensive unit tests for the provided code using the appropriate testing framework for the language. Include edge cases and error scenarios.",
              },
              {
                role = "user",
                content = function(context)
                  return "Generate unit tests for this code:\n\n```" ..
                      context.filetype ..
                      "\n" ..
                      require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line) .. "\n```"
                end,
              },
            },
          },
          ["Optimize Code"] = {
            strategy = "inline",
            description = "Optimize the selected code for performance",
            opts = {
              mapping = "<LocalLeader>aop",
              modes = { "v" },
            },
            prompts = {
              {
                role = "system",
                content =
                "You are a performance optimization expert. Analyze the provided code and suggest optimizations for better performance, readability, and maintainability. Preserve the original functionality.",
              },
              {
                role = "user",
                content = function(context)
                  return "Optimize this code:\n\n```" ..
                      context.filetype ..
                      "\n" ..
                      require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line) .. "\n```"
                end,
              },
            },
          },
          ["Add Documentation"] = {
            strategy = "inline",
            description = "Add documentation to the selected code",
            opts = {
              mapping = "<LocalLeader>adoc",
              modes = { "v" },
            },
            prompts = {
              {
                role = "system",
                content =
                "You are a documentation expert. Add comprehensive documentation to the provided code including docstrings, comments, and type hints where appropriate. Follow the language's documentation standards.",
              },
              {
                role = "user",
                content = function(context)
                  return "Add documentation to this code:\n\n```" ..
                      context.filetype ..
                      "\n" ..
                      require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line) .. "\n```"
                end,
              },
            },
          },
          ["Refactor Code"] = {
            strategy = "inline",
            description = "Refactor the selected code",
            opts = {
              mapping = "<LocalLeader>arf",
              modes = { "v" },
            },
            prompts = {
              {
                role = "system",
                content =
                "You are a refactoring expert. Refactor the provided code to improve readability, maintainability, and follow best practices. Preserve the original functionality and behavior.",
              },
              {
                role = "user",
                content = function(context)
                  return "Refactor this code:\n\n```" ..
                      context.filetype ..
                      "\n" ..
                      require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line) .. "\n```"
                end,
              },
            },
          },
          ["Review Code"] = {
            strategy = "chat",
            description = "Review the selected code for issues",
            opts = {
              mapping = "<LocalLeader>arv",
              modes = { "v" },
            },
            prompts = {
              {
                role = "system",
                content =
                "You are a senior code reviewer. Review the provided code for potential issues, security vulnerabilities, performance problems, and adherence to best practices. Provide constructive feedback and suggestions.",
              },
              {
                role = "user",
                content = function(context)
                  return "Please review this code:\n\n```" ..
                      context.filetype ..
                      "\n" ..
                      require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line) .. "\n```"
                end,
              },
            },
          },
          ["Debug Help"] = {
            strategy = "chat",
            description = "Help debug the selected code",
            opts = {
              mapping = "<LocalLeader>adb",
              modes = { "v" },
            },
            prompts = {
              {
                role = "system",
                content =
                "You are a debugging expert. Analyze the provided code for potential bugs, logical errors, and suggest debugging strategies. Provide specific suggestions for fixing issues.",
              },
              {
                role = "user",
                content = function(context)
                  return "Help me debug this code:\n\n```" ..
                      context.filetype ..
                      "\n" ..
                      require("codecompanion.helpers.actions").get_code(context.start_line, context.end_line) .. "\n```"
                end,
              },
            },
          },
        },
        opts = {
          log_level = "ERROR",
        },
      })
    end,
  },
})

-- General settings
-- yank and paste with the system clipboard
vim.opt.clipboard = 'unnamedplus'
-- do not confuse crontab. see :help crontab
vim.opt.backupcopy = 'yes'
-- do not store swap files on the current dir (remove .)
vim.opt.directory:remove('.')

-- Netrw settings
-- ref - https://shapeshed.com/vim-netrw/
vim.g.netrw_banner = 0
vim.g.netrw_winsize = 25

-- Display settings
-- show trailing whitespace
vim.opt.list = true
vim.opt.listchars = { tab = '▸ ', trail = '▫' }
-- do not redraw while running macros
vim.opt.lazyredraw = true
-- show line numbers
vim.opt.number = true
-- show where you are
vim.opt.ruler = true
-- show typed commands
vim.opt.showcmd = true

-- Indenting
vim.opt.tabstop = 2

-- Undo configuration
-- keep undo history across sessions by storing it in a file
-- ref - https://stackoverflow.com/questions/5700389/using-vims-persistent-undo
local config_dir = vim.fn.expand('~/.config/nvim')
if vim.fn.has('persistent_undo') == 1 then
  local undo_dir_path = config_dir .. '/undo'

  -- create dirs
  vim.fn.system('mkdir -p ' .. config_dir)
  vim.fn.system('mkdir -p ' .. undo_dir_path)

  -- maintain undo history between sessions
  vim.opt.undodir = undo_dir_path
  vim.opt.undofile = true
end

-- Spelling
vim.opt.spell = true

vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }
vim.opt.winbar = '%f'

-- Search settings
vim.api.nvim_create_autocmd("User", {
  pattern = "TelescopePreviewerLoaded",
  command = "setlocal wrap"
})

-- search for stuff on the internet
vim.g.vim_g_command = 'Go'
vim.g.vim_g_f_command = 'Gf'
vim.g.vim_g_query_url = 'https://duckduckgo.com/?q='

-- case-insensitive search
vim.opt.ignorecase = true
-- case-sensitive search if any caps
vim.opt.smartcase = true
-- show context above/below cursorline
vim.opt.scrolloff = 5

-- Automatic whitespace cleanup
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    local save_cursor = vim.fn.getpos(".")
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.setpos(".", save_cursor)
  end,
})

-- Native line number toggling (replaces nvim-numbertoggle)
local numbertoggle_group = vim.api.nvim_create_augroup("NumberToggle", {})

vim.api.nvim_create_autocmd(
  { "BufEnter", "FocusGained", "InsertLeave", "CmdlineLeave", "WinEnter" },
  {
    pattern = "*",
    group = numbertoggle_group,
    callback = function()
      if vim.o.nu and vim.api.nvim_get_mode().mode ~= "i" then
        vim.opt.relativenumber = true
      end
    end,
  }
)

vim.api.nvim_create_autocmd(
  { "BufLeave", "FocusLost", "InsertEnter", "CmdlineEnter", "WinLeave" },
  {
    pattern = "*",
    group = numbertoggle_group,
    callback = function()
      if vim.o.nu then
        vim.opt.relativenumber = false
      end
    end,
  }
)

-- Navigation settings
-- enable hard mode on all buffers
vim.g.hardtime_default_on = 1

-- tmuxline configuration
vim.g.tmuxline_preset = {
  a = '#(whoami)',
  b = '#(gitmux "#{pane_current_path}")',
  win = { '#I', '#W' },
  cwin = { '#I', '#W' },
  y = {
    '%Y-%m-%d',
    '%R',
    '#{?pane_synchronized,#[bold],#[dim]}SYNC',
    '#{online_status}',
  },
  z = {
    '#(rainbarf --tmux --battery --remaining --width 20)'
  },
  options = { ['status-justify'] = 'left' },
}

vim.g.tmuxline_separators = {
  left = '',
  left_alt = '',
  right = '',
  right_alt = '',
  space = ' ',
}

vim.g.tmuxline_theme = {
  a = { '#282828', '#a89b89' },
  b = { '#847c72', '#534d4a' },
  c = { '#847c72', '#534d4a' },
  x = { '#847c72', '#534d4a' },
  y = { '#847c72', '#534d4a' },
  z = { '#282828', '#a89b89' },
  win = { '#847c72', '#534d4a' },
  cwin = { '#282828', '#a89b89' },
  bg = { '#534d4a', '#534d4a' },
}

-- Setup colorscheme and plugins
vim.cmd("colorscheme gruvbox")
require('guess-indent').setup {}
require 'alpha'.setup(require 'alpha.themes.startify'.config)

local navic = require("nvim-navic")
require('lualine').setup {
  options = { theme = 'gruvbox' },
  winbar = {
    lualine_c = {
      { navic.get_location, cond = navic.is_available },
    },
  },
}

require('Navigator').setup()


require("which-key").add({
  -- LSP mappings
  { "gh",               "<cmd>Trouble lsp_references<cr>",                                                             desc = "LSP references" },
  { "gr",               vim.lsp.buf.rename,                                                                            desc = "LSP rename" },
  { "gd",               vim.lsp.buf.definition,                                                                        desc = "LSP definition" },
  { "K",                vim.lsp.buf.hover,                                                                             desc = "LSP hover" },

  -- Leader mappings
  { "<leader>ca",       vim.lsp.buf.code_action,                                                                       desc = "code action" },
  { "<leader>ld",       vim.diagnostic.open_float,                                                                     desc = "show line diagnostics" },
  { "<leader>cd",       vim.diagnostic.open_float,                                                                     desc = "show cursor diagnostics" },
  { "<leader>o",        "<cmd>LSoutlineToggle<cr>",                                                                    desc = "outline" },

  -- Telescope mappings
  { "<leader>a",        ":Telescope live_grep<cr>",                                                                    desc = "search word" },
  { "<leader>tt",       ":Telescope git_files<cr>",                                                                    desc = "search versioned files" },
  { "<leader>t",        ":Telescope find_files<cr>",                                                                   desc = "search files" },
  { "<leader>s",        ":Telescope grep_string<cr>",                                                                  desc = "search cursor" },
  { "<leader>c",        ":Telescope command_history<cr>",                                                              desc = "command history" },
  { "<leader>q",        ":Telescope quickfix<cr>",                                                                     desc = "telescope quickfix" },
  { "<leader>w",        ":Telescope loclist<cr>",                                                                      desc = "telescope loclist" },
  { "<leader>tms",      ":Telescope tmux sessions<cr>",                                                                desc = "tmux sessions" },
  { "<leader>tmw",      ":Telescope tmux windows<cr>",                                                                 desc = "tmux windows" },
  { "<leader>ts",       ":Telescope treesitter<cr>",                                                                   desc = "treesitter" },
  { "<leader>ss",       ":Telescope spell_suggest<cr>",                                                                desc = "spelling" },
  { "<leader>m",        ":Telescope man_pages<cr>",                                                                    desc = "manpages" },
  { "<leader>p",        ":Telescope resume<cr>",                                                                       desc = "telescope resume" },

  -- Git mappings
  { "<leader>g",        ":LazyGit<cr>",                                                                                desc = "LazyGit" },
  { "<leader>gws",      ":Telescope git_status<cr>",                                                                   desc = "git status" },
  { "<leader>gwd",      ":Gitsigns diffthis<cr>",                                                                      desc = "git diff" },
  { "<leader>gco",      ":Gitsigns reset_buffer<cr>",                                                                  desc = "git checkout" },
  { "<leader>gcop",     "<cmd>Gitsigns reset_hunk<cr>",                                                                desc = "git checkout -p" },
  { "<leader>gia",      ":Gitsigns stage_buffer<cr>",                                                                  desc = "git add" },
  { "<leader>giap",     "<cmd>Gitsigns stage_hunk<cr>",                                                                desc = "git add -p" },
  { "<leader>gir",      ":Gitsigns reset_buffer_index<cr>",                                                            desc = "git reset" },
  { "<leader>gb",       ":Gitsigns toggle_current_line_blame<cr>",                                                     desc = "git blame" },
  { "<leader>gl",       ":LazyGitFilter<cr>",                                                                          desc = "git logs" },
  { "<leader>gp",       ":Octo pr create<cr>",                                                                         desc = "git pr" },

  -- Trouble mappings
  { "<leader>xx",       "<cmd>TroubleToggle<cr>",                                                                      desc = "trouble" },
  { "<leader>xw",       "<cmd>TroubleToggle workspace_diagnostics<cr>",                                                desc = "workspace diagnostics" },
  { "<leader>xd",       "<cmd>TroubleToggle document_diagnostics<cr>",                                                 desc = "document diagnostics" },
  { "<leader>xq",       "<cmd>TroubleToggle quickfix<cr>",                                                             desc = "trouble quickfix" },
  { "<leader>xl",       "<cmd>TroubleToggle loclist<cr>",                                                              desc = "trouble loclist" },
  { "<leader>xR",       "<cmd>TroubleToggle lsp_references<cr>",                                                       desc = "trouble lsp refs" },
  { "<leader>xt",       "<cmd>TodoTrouble<cr>",                                                                        desc = "todos" },

  -- Treesitter text object swap mappings
  { "<leader>s",        group = "swap" },
  { "<leader>sn",       desc = "swap next parameter" },
  { "<leader>sp",       desc = "swap previous parameter" },
  { "<leader>sf",       desc = "swap next function" },
  { "<leader>sF",       desc = "swap previous function" },

  -- Treesitter peek definition mappings
  { "<leader>p",        group = "peek definition" },
  { "<leader>pf",       desc = "peek function definition" },
  { "<leader>pc",       desc = "peek class definition" },

  -- Local leader mappings
  { "<localleader>ll",  "<cmd>RenderMarkdown toggle<cr>",                                                              desc = "toggle markdown rendering" },
  { "<localleader>cc",  "<cmd>ClaudeCode<cr>",                                                                         desc = "toggle claude code" },

  -- Python-specific mappings
  { "<localleader>pv",  function() vim.cmd("!python3 -c 'import sys; print(sys.executable)'") end,                     desc = "Show Python path" },
  { "<localleader>pi",  function() vim.lsp.buf.code_action({ context = { only = { "source.organizeImports" } } }) end, desc = "Organize imports" },

  -- CodeCompanion mappings
  { "<localleader>aa",  "<cmd>CodeCompanionChat<cr>",                                                                  desc = "codecompanion chat",        mode = { "n", "v" } },
  { "<localleader>ae",  "<cmd>CodeCompanion<cr>",                                                                      desc = "codecompanion inline edit", mode = { "n", "v" } },
  { "<localleader>ar",  "<cmd>CodeCompanionActions<cr>",                                                               desc = "codecompanion actions",     mode = { "n", "v" } },
  { "<localleader>ac",  "<cmd>CodeCompanionChat Toggle<cr>",                                                           desc = "codecompanion toggle" },
  { "<localleader>ad",  "<cmd>CodeCompanionChat Add<cr>",                                                              desc = "codecompanion add to chat", mode = { "n", "v" } },

  -- Quick model selection (without switching default)
  { "<localleader>am",  group = "codecompanion models" },
  { "<localleader>amc", function() vim.cmd("CodeCompanionChat claude") end,                                            desc = "chat with claude sonnet 4" },
  { "<localleader>amo", function() vim.cmd("CodeCompanionChat opus") end,                                              desc = "chat with claude opus 4" },
  { "<localleader>amk", function() vim.cmd("CodeCompanionChat kimi") end,                                              desc = "chat with kimi k2" },
  { "<localleader>aml", function() vim.cmd("CodeCompanionChat ollama_coder") end,                                      desc = "chat with local ollama" },

  -- Inline editing with specific models
  { "<localleader>aic", function() vim.cmd("CodeCompanion claude") end,                                                desc = "inline edit with claude",   mode = { "n", "v" } },
  { "<localleader>aio", function() vim.cmd("CodeCompanion opus") end,                                                  desc = "inline edit with opus",     mode = { "n", "v" } },
  { "<localleader>aik", function() vim.cmd("CodeCompanion kimi") end,                                                  desc = "inline edit with kimi",     mode = { "n", "v" } },
  { "<localleader>ail", function() vim.cmd("CodeCompanion ollama_coder") end,                                          desc = "inline edit with ollama",   mode = { "n", "v" } },

  -- Buffer management
  { "<localleader>ab",  group = "codecompanion buffers" },
  { "<localleader>abs", "<cmd>CodeCompanionChat Save<cr>",                                                             desc = "save current chat" },
  { "<localleader>abl", "<cmd>CodeCompanionChat Load<cr>",                                                             desc = "load saved chat" },
  { "<localleader>abd", "<cmd>CodeCompanionChat Delete<cr>",                                                           desc = "delete current chat" },

  -- Navigation mappings
  { "]t",               function() require("todo-comments").jump_next() end,                                           desc = "Next todo comment" },
  { "[t",               function() require("todo-comments").jump_prev() end,                                           desc = "Previous todo comment" },

  -- Treesitter navigation (with descriptive labels)
  { "]f",               desc = "Next function start" },
  { "[f",               desc = "Previous function start" },
  { "]F",               desc = "Next function end" },
  { "[F",               desc = "Previous function end" },
  { "]a",               desc = "Next parameter" },
  { "[a",               desc = "Previous parameter" },
  { "]i",               desc = "Next conditional" },
  { "[i",               desc = "Previous conditional" },
  { "]l",               desc = "Next loop" },
  { "[l",               desc = "Previous loop" },
  { "]s",               desc = "Next statement" },
  { "[s",               desc = "Previous statement" },

  {
    "]c",
    function()
      if vim.wo.diff then
        return ']c'
      end
      vim.schedule(function()
        require('gitsigns').next_hunk()
      end)
      return '<Ignore>'
    end,
    desc = "Next git hunk",
    expr = true
  },
  {
    "[c",
    function()
      if vim.wo.diff then
        return '[c'
      end
      vim.schedule(function()
        require('gitsigns').prev_hunk()
      end)
      return '<Ignore>'
    end,
    desc = "Previous git hunk",
    expr = true
  },

  -- Diagnostic navigation
  { "]e", vim.diagnostic.goto_next, desc = "Next diagnostic" },
  { "[e", vim.diagnostic.goto_prev, desc = "Previous diagnostic" },
  {
    "]E",
    function()
      vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR })
    end,
    desc = "Next error"
  },
  {
    "[E",
    function()
      vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR })
    end,
    desc = "Previous error"
  },

  -- Navigation mappings (tmux/vim pane navigation)
  { "<c-h>",     "<cmd>NavigatorLeft<cr>",                                                                        desc = "Navigate left",            mode = { "n", "t" } },
  { "<c-l>",     "<cmd>NavigatorRight<cr>",                                                                       desc = "Navigate right",           mode = { "n", "t" } },
  { "<c-k>",     "<cmd>NavigatorUp<cr>",                                                                          desc = "Navigate up",              mode = { "n", "t" } },
  { "<c-j>",     "<cmd>NavigatorDown<cr>",                                                                        desc = "Navigate down",            mode = { "n", "t" } },
  { "<c-p>",     "<cmd>NavigatorPrevious<cr>",                                                                    desc = "Navigate previous",        mode = { "n", "t" } },

  -- Terminal mappings
  { "<A-d>",     ":terminal lazygit<cr>",                                                                         desc = "Open lazygit in terminal", mode = "n" },

  -- Vim legacy mappings
  { "<leader>V", ":source ~/.config/nvim/init.lua<cr>:filetype detect<cr>:exe \":echo 'init.lua reloaded'\"<cr>", desc = "reload init.lua" },
  { "<up>",      "<nop>",                                                                                         desc = "disabled",                 mode = { "n", "i" } },
  { "<down>",    "<nop>",                                                                                         desc = "disabled",                 mode = { "n", "i" } },
  { "<left>",    "<nop>",                                                                                         desc = "disabled",                 mode = { "n", "i" } },
  { "<right>",   "<nop>",                                                                                         desc = "disabled",                 mode = { "n", "i" } },

  -- LuaSnip mappings
  {
    "<Tab>",
    function()
      local luasnip = require('luasnip')
      if luasnip.expand_or_jumpable() then
        return '<Plug>luasnip-expand-or-jump'
      else
        return '<Tab>'
      end
    end,
    desc = "Expand or jump snippet",
    mode = "i",
    expr = true
  },
  { "<S-Tab>",    function() require('luasnip').jump(-1) end, desc = "Jump to previous snippet",                mode = { "i", "s" } },
  { "<Tab>",      function() require('luasnip').jump(1) end,  desc = "Jump to next snippet",                    mode = "s" },

  -- Utility mappings
  { "<esc><esc>", ":noh<cr><esc>",                            desc = "clear the highlight from the last search" },

  -- netrw mapping
  { "<leader>d",  ":Lexplore<cr>",                            desc = "file explorer" },
})

local trouble = require("trouble")
trouble.setup {}

local telescope = require('telescope')
telescope.setup {
  defaults = {
    mappings = {
      i = { ["<c-t>"] = trouble.open_with_trouble },
      n = { ["<c-t>"] = trouble.open_with_trouble },
    },
  },
}
telescope.load_extension('fzf')

require 'nvim-treesitter.configs'.setup {
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
    "yaml",
    "json",
    "markdown",
    "markdown_inline",
  },

  sync_install = true,
  -- Automatically install missing parsers when entering buffer
  -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
  auto_install = true,

  textobjects = {
    select = {
      enable = true,
      lookahead = true,
      keymaps = {
        -- Function/method text objects
        ["af"] = "@function.outer",
        ["if"] = "@function.inner",
        ["am"] = "@function.outer",
        ["im"] = "@function.inner",

        -- Class text objects
        ["ac"] = "@class.outer",
        ["ic"] = "@class.inner",

        -- Parameter/argument text objects
        ["aa"] = "@parameter.outer",
        ["ia"] = "@parameter.inner",

        -- Conditional text objects
        ["ai"] = "@conditional.outer",
        ["ii"] = "@conditional.inner",

        -- Loop text objects
        ["al"] = "@loop.outer",
        ["il"] = "@loop.inner",

        -- Comment text objects
        ["a/"] = "@comment.outer",
        ["i/"] = "@comment.inner",

        -- Block text objects
        ["ab"] = "@block.outer",
        ["ib"] = "@block.inner",

        -- Statement text objects
        ["as"] = "@statement.outer",
        ["is"] = "@statement.inner",

        -- Assignment text objects
        ["a="] = "@assignment.outer",
        ["i="] = "@assignment.inner",

        -- Call text objects
        ["aF"] = "@call.outer",
        ["iF"] = "@call.inner",
      },
      selection_modes = {
        ['@parameter.outer'] = 'v',
        ['@function.outer'] = 'V',
        ['@class.outer'] = 'V',
        ['@conditional.outer'] = 'V',
        ['@loop.outer'] = 'V',
        ['@block.outer'] = 'V',
      },
    },

    move = {
      enable = true,
      set_jumps = true,
      goto_next_start = {
        ["]f"] = "@function.outer",
        ["]c"] = "@class.outer",
        ["]a"] = "@parameter.inner",
        ["]i"] = "@conditional.outer",
        ["]l"] = "@loop.outer",
        ["]s"] = "@statement.outer",
      },
      goto_next_end = {
        ["]F"] = "@function.outer",
        ["]C"] = "@class.outer",
        ["]A"] = "@parameter.inner",
        ["]I"] = "@conditional.outer",
        ["]L"] = "@loop.outer",
        ["]S"] = "@statement.outer",
      },
      goto_previous_start = {
        ["[f"] = "@function.outer",
        ["[c"] = "@class.outer",
        ["[a"] = "@parameter.inner",
        ["[i"] = "@conditional.outer",
        ["[l"] = "@loop.outer",
        ["[s"] = "@statement.outer",
      },
      goto_previous_end = {
        ["[F"] = "@function.outer",
        ["[C"] = "@class.outer",
        ["[A"] = "@parameter.inner",
        ["[I"] = "@conditional.outer",
        ["[L"] = "@loop.outer",
        ["[S"] = "@statement.outer",
      },
    },

    swap = {
      enable = true,
      swap_next = {
        ["<leader>sn"] = "@parameter.inner",
        ["<leader>sf"] = "@function.outer",
      },
      swap_previous = {
        ["<leader>sp"] = "@parameter.inner",
        ["<leader>sF"] = "@function.outer",
      },
    },

    lsp_interop = {
      enable = true,
      border = 'none',
      floating_preview_opts = {},
      peek_definition_code = {
        ["<leader>pf"] = "@function.outer",
        ["<leader>pc"] = "@class.outer",
      },
    },
  },
}

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.tfvars", "*.tf" },
  command = "set filetype=hcl"
})

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = "*.tftpl",
  command = "set filetype=yaml"
})

vim.treesitter.language.register('diff', 'git')

require('treesj').setup {}

require('treesitter-context').setup({
  enable = true,
  max_lines = 0,
  min_window_height = 0,
  line_numbers = true,
  multiline_threshold = 20,
  trim_scope = 'outer',
  mode = 'cursor',
  separator = nil,
  zindex = 20,
  on_attach = nil,
})

local lsp_servers = {
  lua_ls = {
    Lua = {
      diagnostics = {
        globals = {
          'hs',
          'vim',
        },
      },
    },
  },
  -- FIXME go back to golangcli-lint
  golangci_lint_ls = {
    command = { "golangci-lint-langserver", "run", "--out-format", "json", "--allow-parallel-runners", "--exclude-use-default=false", "-e", "(comment on exported (method|function|type|const)|should have( a package)? comment|comment should be of the form)" },
  },
  rust_analyzer = {},
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
  marksman = {},
}

require "mason".setup()
require("mason-lspconfig").setup({
  ensure_installed = vim.tbl_keys(lsp_servers),
  automatic_installation = true,
  automatic_enable = false,
})

local sqlfluff = {
  args = { "fix", "--disable-progress-bar", "-f", "-n", "-" },
  extra_args = { "--dialect", "postgres" },
}

local null_ls = require("null-ls")
local augroup = vim.api.nvim_create_augroup("LspFormatting", {})

null_ls.setup({
  on_attach = function(client, bufnr)
    if client.supports_method("textDocument/formatting") then
      vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
      vim.api.nvim_create_autocmd("BufWritePre", {
        group = augroup,
        buffer = bufnr,
        callback = function()
          vim.lsp.buf.format({
            timeout_ms = 20000,
            filter = function(cli)
              return cli.name == "null-ls"
            end,
            bufnr = bufnr,
          })
        end,
      })
    end
  end,
  sources = {
    null_ls.builtins.code_actions.gitsigns,
    null_ls.builtins.formatting.sqlfluff.with(sqlfluff),
    null_ls.builtins.diagnostics.sqlfluff.with(sqlfluff),
    null_ls.builtins.formatting.goimports,
    null_ls.builtins.completion.spell,
    null_ls.builtins.formatting.prettierd,
  },
})

require("luasnip.loaders.from_vscode").lazy_load()
require("luasnip.loaders.from_snipmate").lazy_load({ path = { "./snippets" } })

local cmp = require 'cmp'
cmp.setup({
  snippet = {
    expand = function(args)
      require('luasnip').lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-b>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.abort(),
    -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
    ['<cr>'] = cmp.mapping.confirm({ select = true }),
  }),
  sources = cmp.config.sources({
    { name = 'nvim_lsp' },
    { name = 'nvim_lsp_signature_help' },
    { name = 'luasnip' },
    { name = 'git' },
  }, {
    { name = 'buffer' },
  })
})

for server, settings in pairs(lsp_servers) do
  require("lspconfig")[server].setup {
    settings = settings,
    on_attach = function(client, bufnr)
      if client.server_capabilities.documentSymbolProvider then
        navic.attach(client, bufnr)
      end

      require("lsp-format").on_attach(client)
    end,
    capabilities = require('cmp_nvim_lsp').default_capabilities(),
  }
end

require('gitsigns').setup()
require("nvim-autopairs").setup {}
require('Comment').setup()
require("todo-comments").setup {}
require("cmp_git").setup()
require "octo".setup()
require('claude-code').setup()
