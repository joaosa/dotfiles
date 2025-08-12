scriptencoding utf8

" Plugins
let mapleader=','

" configure plug
call plug#begin('~/.config/nvim/plugged')
" aesthetics
Plug 'ellisonleao/gruvbox.nvim'
Plug 'nvim-tree/nvim-web-devicons'
Plug 'lukas-reineke/indent-blankline.nvim'
Plug 'nmac427/guess-indent.nvim'
Plug 'lewis6991/gitsigns.nvim'
Plug 'nvim-lualine/lualine.nvim'
Plug 'edkolev/tmuxline.vim'
Plug 'folke/zen-mode.nvim'
Plug 'goolord/alpha-nvim'
" behaviour
Plug 'takac/vim-hardtime'
Plug 'declancm/cinnamon.nvim'
Plug 'tpope/vim-obsession'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-speeddating'
Plug 'tpope/vim-repeat'
Plug 'numToStr/Navigator.nvim'
Plug 'szw/vim-g'
Plug 'windwp/nvim-autopairs'
Plug 'sitiom/nvim-numbertoggle'
" language syntax
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-treesitter/nvim-treesitter-textobjects'
Plug 'numToStr/Comment.nvim'
" lsp
Plug 'williamboman/mason.nvim'
Plug 'williamboman/mason-lspconfig.nvim'
Plug 'neovim/nvim-lspconfig'
Plug 'nvimtools//none-ls.nvim'
Plug 'lukas-reineke/lsp-format.nvim'
Plug 'Wansmer/treesj'
" autocomplete
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp-signature-help'
Plug 'petertriho/cmp-git'
" snippets
Plug 'L3MON4D3/LuaSnip'
Plug 'saadparwaiz1/cmp_luasnip'
Plug 'rafamadriz/friendly-snippets'
" discoverability
Plug 'nvim-lua/plenary.nvim'
Plug 'folke/which-key.nvim'
Plug 'unblevable/quick-scope'
Plug 'glepnir/lspsaga.nvim', { 'branch': 'main' }
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release' }
Plug 'camgraff/telescope-tmux.nvim'
Plug 'folke/todo-comments.nvim'
Plug 'folke/trouble.nvim'
Plug 'SmiteshP/nvim-navic'
Plug 'gorbit99/codewindow.nvim'
" external tools
Plug 'lervag/vimtex'
Plug 'ellisonleao/glow.nvim'
Plug 'pwntester/octo.nvim'
Plug 'kdheepak/lazygit.nvim'
Plug 'tpope/vim-dadbod'
call plug#end()

" setup netrw
" ref - https://shapeshed.com/vim-netrw/
let g:netrw_banner = 0
" let g:netrw_liststyle = 3
let g:netrw_winsize = 25
nnoremap <leader>d :Lexplore<cr>

" yank and paste with the system clipboard
set clipboard=unnamedplus
" do not confuse crontab. see :help crontab
set backupcopy=yes
" do not store swap files on the current dir (remove .)
set directory-=.

" Display
" show trailing whitespace
set list
set listchars=tab:▸\ ,trail:▫
" do not redraw while running macros
set lazyredraw
" show line numbers
set number
" show where you are
set ruler
" show typed commands
set showcmd

" Indenting
set tabstop=2

" Navigation
" enable hard mode on all buffers
let g:hardtime_default_on = 1
" disable arrow keys in normal and insert mode
nnoremap <up> <nop>
nnoremap <down> <nop>
nnoremap <left> <nop>
nnoremap <right> <nop>
inoremap <up> <nop>
inoremap <down> <nop>
inoremap <left> <nop>
inoremap <right> <nop>

" Undo
" keep undo history across sessions by storing it in a file
" ref - https://stackoverflow.com/questions/5700389/using-vims-persistent-undo
let configDir = '~/.config/nvim'
if has('persistent_undo')
  let undoDirPath = expand(configDir . '/undo')

  " create dirs
  call system('mkdir ' . configDir)
  call system('mkdir ' . undoDirPath)

  " maintain undo history between sessions
  let &undodir = undoDirPath
  set undofile
endif

" Spelling
set spell

set completeopt=menu,menuone,noselect
set winbar=%f

lua <<EOF
  vim.cmd("colorscheme gruvbox")
  require('guess-indent').setup {}
  require'alpha'.setup(require'alpha.themes.startify'.config)

  local navic = require("nvim-navic")
  require('lualine').setup {
    options = { theme = 'gruvbox' },
    winbar = {
      lualine_c = {
        { navic.get_location, cond = navic.is_available },
      },
    },
  }

  local keymap = vim.keymap.set
  require('Navigator').setup()
  keymap({'n', 't'}, '<c-h>', '<cmd>NavigatorLeft<cr>')
  keymap({'n', 't'}, '<c-l>', '<cmd>NavigatorRight<cr>')
  keymap({'n', 't'}, '<c-k>', '<cmd>NavigatorUp<cr>')
  keymap({'n', 't'}, '<c-j>', '<cmd>NavigatorDown<cr>')
  keymap({'n', 't'}, '<c-p>', '<cmd>NavigatorPrevious<cr>')

  require('lspsaga').setup {
    lightbulb = { enable = false },
  }

  -- TODO replace lazygit.nvim with this
  -- Float terminal
  keymap("n", "<A-d>", "<cmd>Lspsaga open_floaterm<cr>", { silent = true })
  -- if you want to pass some cli command into a terminal you can do it like this
  -- open lazygit in lspsaga float terminal
  keymap("n", "<A-d>", "<cmd>Lspsaga open_floaterm lazygit<cr>", { silent = true })
  -- close floaterm
  keymap("t", "<A-d>", [[<C-\><C-n><cmd>Lspsaga close_floaterm<cr>]], { silent = true })

  local gs = require('gitsigns')
  -- ref - from https://github.com/folke/which-key.nvim#%EF%B8%8F-mappings
  require("which-key").register {
    -- Lsp finder find the symbol definition implement reference
    -- if there is no implement it will hide
    -- when you use action in finder like open vsplit then you can
    -- use <C-t> to jump back
    gh = { "<cmd>Lspsaga lsp_finder<cr>", "Lspsaga finder" },
    gr = { "<cmd>Lspsaga rename<cr>", "Lspsaga rename" },
    -- Peek Definition
    -- you can edit the definition file in this floatwindow
    -- also support open/vsplit/etc operation check definition_action_keys
    -- support tagstack C-t jump back
    gd = { "<cmd>Lspsaga peek_definition<cr>", "Lspsaga peek definition" },
    K = { "<cmd>Lspsaga hover_doc<cr>", "Lspsaga hover doc" },
    ["<leader>"] = {
      ca = { "<cmd>Lspsaga code_action<cr>", "code action" },
      ld = { "<cmd>Lspsaga show_line_diagnostics<cr>", "show line diagnostics" },
      cd = { "<cmd>Lspsaga show_cursor_diagnostics<cr>", "show cursor diagnostics" },
      o = { "<cmd>LSoutlineToggle<cr>", "outline" },
      a = { ":Telescope live_grep<cr>", "search word" },
      tt = { ":Telescope git_files<cr>", "search versioned files" },
      t = { ":Telescope find_files<cr>", "search files" },
      s = { ":Telescope grep_string<cr>", "search cursor" },
      c = { ":Telescope command_history<cr>", "command history" },
      q = { ":Telescope quickfix<cr>", "telescope quickfix" },
      w = { ":Telescope loclist<cr>", "telescope loclist" },
      tms = { ":Telescope tmux sessions<cr>", "tmux sessions" },
      tmw = { ":Telescope tmux windows<cr>", "tmux windos" },
      ts = { ":Telescope treesitter<cr>", "treesitter" },
      ss = { ":Telescope spell_suggest<cr>", "spelling" },
      m = { ":Telescope man_pages<cr>", "manpages" },
      p = { ":Telescope resume<cr>", "telescope resume" },
      -- git (reusing the prezto aliases)
      g = { ":LazyGit<cr>", "LazyGit" },
      gws = { ":Telescope git_status<cr>", "git status" },
      gwd = { ":Gitsigns diffthis<cr>", "git diff" },
      gco = { ":Gitsigns reset_buffer<cr>", "git checkout" },
      gcop = { "<cmd>Gitsigns reset_hunk<cr>", "git checkout -p" },
      gia = { ":Gitsigns stage_buffer<cr>", "git add" },
      giap = { "<cmd>Gitsigns stage_hunk<cr>", "git add -p" },
      gir = { ":Gitsigns reset_buffer_index<cr>", "git reset" },
      gb = { ":Gitsigns toggle_current_line_blame<cr>", "git blame" },
      gl = { ":LazyGitFilter<cr>", "git logs"},
      gp = { ":Octo pr create<cr>", "git pr"},
      -- trouble
      xx = { "<cmd>TroubleToggle<cr>", "trouble" },
      xw = { "<cmd>TroubleToggle workspace_diagnostics<cr>", "workspace diagnostics" },
      xd = { "<cmd>TroubleToggle document_diagnostics<cr>", "workspace diagnostics" },
      xq = { "<cmd>TroubleToggle quickfix<cr>", "trouble quickfix" },
      xl = { "<cmd>TroubleToggle loclist<cr", "trouble loclist" },
      xR = { "<cmd>TroubleToggle lsp_references<cr>", "trouble lsp refs" },
      xt = { "<cmd>TodoTrouble<cr>", "todos" },
    },
    ["<localleader>"] = {
      ll = { ":Glow<cr>", "preview markdown" },
    },
    ["]t"] = { function() require("todo-comments").jump_next() end, "Next todo comment" },
    ["[t"] = { function() require("todo-comments").jump_prev() end, "Previous todo comment" },
    ["]c"] = { function() if vim.wo.diff then return ']c' end vim.schedule(function() gs.next_hunk() end) return '<Ignore>' end, "Next git hunk" },
    ["[c"] = { function() if vim.wo.diff then return '[c' end vim.schedule(function() gs.prev_hunk() end) return '<Ignore>' end, "Previous git hunk" },
    -- Diagnostic jump can use `<c-o>` to jump back
    ["]e"] = { "<cmd>Lspsaga diagnostic_jump_next<cr>", "Next diagnostic" },
    ["[e"] = { "<cmd>Lspsaga diagnostic_jump_prev<cr>", "Previous diagnostic" },
    -- Only jump to error
    ["]E"] = { function() require("lspsaga.diagnostic").goto_next({ severity = vim.diagnostic.severity.ERROR }) end, "Next error" },
    ["[E"] = { function() require("lspsaga.diagnostic").goto_prev({ severity = vim.diagnostic.severity.ERROR }) end, "Previous error" },
    ["<esc><esc>"] = { ":noh<cr><esc>", "clear the highlight from the last search" },
  }

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

  require'nvim-treesitter.configs'.setup {
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

    sync_install = false,
    -- Automatically install missing parsers when entering buffer
    -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
    auto_install = true,
  }

  vim.cmd("autocmd BufRead,BufNewFile *.tfvars,*.tf set filetype=hcl")
  vim.cmd("autocmd BufRead,BufNewFile *.tftpl, set filetype=yaml")
  vim.treesitter.language.register('diff', 'git')

  require('treesj').setup {}

  lsp_servers = {
    lua_ls = {
      Lua = {
        diagnostics = {
          globals = {'hs','vim'},
        },
      },
    },
    -- FIXME go back to golangcli-lint
    golangci_lint_ls = {
      command = { "golangci-lint-langserver", "run", "--out-format", "json", "--allow-parallel-runners", "--exclude-use-default=false", "-e", "(comment on exported (method|function|type|const)|should have( a package)? comment|comment should be of the form)" },
    },
    rust_analyzer = {},
    terraformls = {},
    pyright = {},
    ts_ls = {},
    yamlls = {},
    vimls = {},
    ansiblels = {},
    bashls = {},
    sqlls = {},
    marksman = {},
  }

  require"mason".setup()
  require("mason-lspconfig").setup({
    ensure_installed = lsp_servers,
    automatic_installation = true,
  })

  local sqlfluff = {
    args = { "fix", "--disable-progress-bar", "-f", "-n", "-" },
    extra_args = { "--dialect", "postgres" },
  }
  local null_ls = require("null-ls")
  null_ls.setup({
    on_attach = function(client, bufnr)
      -- so we can format on save
      if client.supports_method("textDocument/formatting") then
        vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
        vim.api.nvim_create_autocmd("BufWritePre", {
          group = augroup,
          buffer = bufnr,
          callback = function()
          -- need this timeout for sqlfluff to work
            vim.lsp.buf.format({ timeout_ms = 20000 })
          end,
        })
      end
    end,
    sources = {
      null_ls.builtins.code_actions.gitsigns,
      null_ls.builtins.formatting.sqlfluff.with(sqlfluff),
      null_ls.builtins.diagnostics.sqlfluff.with(sqlfluff),
      null_ls.builtins.formatting.goimports,
      null_ls.builtins.formatting.black,
      null_ls.builtins.diagnostics.eslint,
      null_ls.builtins.code_actions.eslint,
      null_ls.builtins.completion.spell,
      null_ls.builtins.formatting.prettierd,
    },
  })

  require("luasnip.loaders.from_vscode").lazy_load()
  require("luasnip.loaders.from_snipmate").lazy_load({ path = { "./snippets" } })

  local cmp = require'cmp'
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
      ['<cr>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
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
  require"octo".setup()

  local codewindow = require('codewindow')
  codewindow.setup()
  codewindow.apply_default_keybinds()
EOF

" tmuxline
let g:tmuxline_preset = {
  \'a'    : '#(whoami)',
  \'b'    : '#(gitmux "#{pane_current_path}")',
  \'win'  : ['#I', '#W'],
  \'cwin' : ['#I', '#W'],
  \'y'    : [
    \'%Y-%m-%d',
    \'%R',
    \'#{?pane_synchronized,#[bold],#[dim]}SYNC',
    \'#{online_status}',
  \],
  \'z'    : [
    \'#(rainbarf --tmux --battery --remaining --width 20)'
  \],
  \'options' : {'status-justify': 'left'},
\}
let g:tmuxline_separators = {
  \ 'left' : '',
  \ 'left_alt': '',
  \ 'right' : '',
  \ 'right_alt' : '',
  \ 'space' : ' ',
\}
let g:tmuxline_theme = {
  \'a'   : ['#282828','#a89b89'],
  \'b'   : ['#847c72','#534d4a'],
  \'c'   : ['#847c72','#534d4a'],
  \'x'   : ['#847c72','#534d4a'],
  \'y'   : ['#847c72','#534d4a'],
  \'z'   : ['#282828','#a89b89'],
  \'win' : ['#847c72','#534d4a'],
  \'cwin': ['#282828','#a89b89'],
  \'bg'  : ['#534d4a','#534d4a'],
\}

" reload nvimrc
noremap <silent> <leader>V :source ~/.config/nvim/init.vim<cr>:filetype detect<cr>:exe ":echo 'vimrc reloaded'"<cr>

" autocomplete
" press <Tab> to expand or jump in a snippet. These can also be mapped separately
" via <Plug>luasnip-expand-snippet and <Plug>luasnip-jump-next.
imap <silent><expr> <Tab> luasnip#expand_or_jumpable() ? '<Plug>luasnip-expand-or-jump' : '<Tab>'
" -1 for jumping backwards.
inoremap <silent> <S-Tab> <cmd>lua require'luasnip'.jump(-1)<Cr>
snoremap <silent> <Tab> <cmd>lua require('luasnip').jump(1)<Cr>
snoremap <silent> <S-Tab> <cmd>lua require('luasnip').jump(-1)<Cr>

" Search
autocmd User TelescopePreviewerLoaded setlocal wrap

" search for stuff on the internet
let g:vim_g_command='Go'
" stuff + filetype
let g:vim_g_f_command='Gf'
let g:vim_g_query_url='https://duckduckgo.com/?q='
" case-insensitive search
set ignorecase
" case-sensitive search if any caps
set smartcase
" show context above/below cursorline
set scrolloff=5
