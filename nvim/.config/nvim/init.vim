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
Plug 'kassio/neoterm'
Plug 'szw/vim-g'
Plug 'jeffkreeftmeijer/vim-numbertoggle'
Plug 'windwp/nvim-autopairs'
" language syntax
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-treesitter/nvim-treesitter-textobjects'
Plug 'numToStr/Comment.nvim'
" lsp
Plug 'williamboman/mason.nvim'
Plug 'williamboman/mason-lspconfig.nvim'
Plug 'neovim/nvim-lspconfig'
Plug 'jose-elias-alvarez/null-ls.nvim'
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
Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'cmake -S. -Bbuild -DCMAKE_BUILD_TYPE=Release && cmake --build build --config Release && cmake --install build --prefix build' }
Plug 'camgraff/telescope-tmux.nvim'
Plug 'folke/todo-comments.nvim'
Plug 'folke/trouble.nvim'
Plug 'simrat39/symbols-outline.nvim'
Plug 'gorbit99/codewindow.nvim'
" external tools
Plug 'shime/vim-livedown', { 'do': 'npm install -g livedown' , 'for': ['markdown', 'apiblueprint'] }
Plug 'lervag/vimtex'
Plug 'janko-m/vim-test'
Plug 'pwntester/octo.nvim'
Plug 'f-person/git-blame.nvim'
Plug 'kdheepak/lazygit.nvim'
Plug 'tpope/vim-dadbod'
call plug#end()

" setup netrw
" ref - https://shapeshed.com/vim-netrw/
let g:netrw_banner = 0
" let g:netrw_liststyle = 3
let g:netrw_winsize = 25
nnoremap <leader>d :Lexplore<CR>

" yank and paste with the system clipboard
set clipboard=unnamedplus
" do not confuse crontab. see :help crontab
set backupcopy=yes
" do not store swap files on the current dir (remove .)
set directory-=.

" Session
nnoremap <leader>ss :Obsession<CR>

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
augroup spelling
  autocmd BufRead,BufNewFile *.md set filetype=markdown
  autocmd BufRead,BufNewFile *.md set spell
  autocmd FileType vim set spell
  autocmd BufRead,BufNewFile *.tex set spell
  autocmd BufRead,BufNewFile PULLREQ_EDITMSG,COMMIT_EDITMSG, set spell
augroup end
" http://vi.stackexchange.com/questions/68/autocorrect-spelling-mistakes
" go back to last misspelled word and pick first suggestion
" this corresponds to <A-l>
nnoremap ¬ <C-g>u<Esc>[s1z=`]a<C-g>u
" select last misspelled word (typing will edit)
" this corresponds to <A-k>
nnoremap ˚ <Esc>[sve<C-g>

set completeopt=menu,menuone,noselect

lua <<EOF
  vim.cmd("colorscheme gruvbox")
  require('guess-indent').setup {}
  require'alpha'.setup(require'alpha.themes.startify'.config)

  require('lualine').setup()

  local keymap = vim.keymap.set
  require('Navigator').setup()
  keymap({'n', 't'}, '<c-h>', '<CMD>NavigatorLeft<CR>')
  keymap({'n', 't'}, '<c-l>', '<CMD>NavigatorRight<CR>')
  keymap({'n', 't'}, '<c-k>', '<CMD>NavigatorUp<CR>')
  keymap({'n', 't'}, '<c-j>', '<CMD>NavigatorDown<CR>')
  keymap({'n', 't'}, '<c-p>', '<CMD>NavigatorPrevious<CR>')

  require('lspsaga').init_lsp_saga()
  -- Lsp finder find the symbol definition implement reference
  -- if there is no implement it will hide
  -- when you use action in finder like open vsplit then you can
  -- use <C-t> to jump back
  keymap("n", "gh", "<cmd>Lspsaga lsp_finder<CR>", { silent = true })

  -- Code action
  keymap({"n","v"}, "<leader>ca", "<cmd>Lspsaga code_action<CR>", { silent = true })

  -- Rename
  keymap("n", "gr", "<cmd>Lspsaga rename<CR>", { silent = true })

  -- Peek Definition
  -- you can edit the definition file in this flaotwindow
  -- also support open/vsplit/etc operation check definition_action_keys
  -- support tagstack C-t jump back
  keymap("n", "gd", "<cmd>Lspsaga peek_definition<CR>", { silent = true })

  -- Show line diagnostics
  keymap("n", "<leader>cd", "<cmd>Lspsaga show_line_diagnostics<CR>", { silent = true })

  -- Show cursor diagnostics
  keymap("n", "<leader>cd", "<cmd>Lspsaga show_cursor_diagnostics<CR>", { silent = true })

  -- Diagnostic jump can use `<c-o>` to jump back
  keymap("n", "[e", "<cmd>Lspsaga diagnostic_jump_prev<CR>", { silent = true })
  keymap("n", "]e", "<cmd>Lspsaga diagnostic_jump_next<CR>", { silent = true })

  -- Only jump to error
  keymap("n", "[E", function()
    require("lspsaga.diagnostic").goto_prev({ severity = vim.diagnostic.severity.ERROR })
  end, { silent = true })
  keymap("n", "]E", function()
    require("lspsaga.diagnostic").goto_next({ severity = vim.diagnostic.severity.ERROR })
  end, { silent = true })

  -- Outline
  keymap("n","<leader>o", "<cmd>LSoutlineToggle<CR>",{ silent = true })

  -- Hover Doc
  keymap("n", "K", "<cmd>Lspsaga hover_doc<CR>", { silent = true })

  -- Float terminal
  keymap("n", "<A-d>", "<cmd>Lspsaga open_floaterm<CR>", { silent = true })
  -- if you want to pass some cli command into a terminal you can do it like this
  -- open lazygit in lspsaga float terminal
  keymap("n", "<A-d>", "<cmd>Lspsaga open_floaterm lazygit<CR>", { silent = true })
  -- close floaterm
  keymap("t", "<A-d>", [[<C-\><C-n><cmd>Lspsaga close_floaterm<CR>]], { silent = true })

  require("which-key").setup {}

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
      additional_vim_regex_highlighting = false,
    },

    ensure_installed = {
      "rust",
      "go",
      "lua",
      "python",
      "javascript",
      "typescript",
      "hcl",
      "yaml",
      "json",
      "markdown",
    },

    sync_install = false,
    -- Automatically install missing parsers when entering buffer
    -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
    auto_install = true,
  }

  local ft_to_parser = require"nvim-treesitter.parsers".filetype_to_parsername
  ft_to_parser.terraform = "hcl"
  ft_to_parser["terraform-vars"] = "hcl"
  ft_to_parser.ansible = "yaml"
  ft_to_parser.diff = "git"

  require('treesj').setup {}

  lsp_servers = {
    sumneko_lua = {
      Lua = {
        diagnostics = {
          globals = {'hs'},
        },
      },
    },
    -- FIXME go back to golangcli-lint
    -- command = { "golangci-lint", "run", "--out-format", "json", "--allow-parallel-runners", "--exclude-use-default=false", "-e", "(comment on exported (method|function|type|const)|should have( a package)? comment|comment should be of the form)" },
    gopls = {},
    rust_analyzer = {},
    terraformls = {},
    pyright = {},
    tsserver = {},
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
  })

  local null_ls = require("null-ls")
  null_ls.setup({
    -- so we can format on save
    on_attach = function(client, bufnr)
      if client.supports_method("textDocument/formatting") then
        vim.api.nvim_clear_autocmds({ group = augroup, buffer = bufnr })
        vim.api.nvim_create_autocmd("BufWritePre", {
          group = augroup,
          buffer = bufnr,
          callback = function()
            vim.lsp.buf.format()
          end,
        })
      end
    end,
    sources = {
      null_ls.builtins.formatting.pg_format,
      null_ls.builtins.formatting.goimports,
      null_ls.builtins.formatting.black,
      null_ls.builtins.diagnostics.eslint,
      null_ls.builtins.completion.spell,
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
      ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
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
      on_attach = function(client)
        require("lsp-format").on_attach(client)
      end,
      capabilities = require('cmp_nvim_lsp').default_capabilities(),
    }
  end

  require('gitsigns').setup()
  require("symbols-outline").setup()
  require("nvim-autopairs").setup {}
  require('Comment').setup()

  require("todo-comments").setup {}
  vim.keymap.set("n", "]t", function()
    require("todo-comments").jump_next()
  end, { desc = "Next todo comment" })
  vim.keymap.set("n", "[t", function()
    require("todo-comments").jump_prev()
  end, { desc = "Previous todo comment" })

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
noremap <silent> <leader>V :source ~/.config/nvim/init.vim<CR>:filetype detect<CR>:exe ":echo 'vimrc reloaded'"<CR>

" vim test
" ref - https://github.com/janko/vim-test#strategies
" ref - https://bernheisel.com/blog/vim-workflow/
let test#strategy = 'neoterm'
let g:neoterm_shell = '$SHELL -l' " use the login shell
let g:neoterm_default_mod = 'vert'
let g:neoterm_autoscroll = 1
let g:neoterm_size = 80
let g:neoterm_fixedsize = 1
let g:neoterm_keep_term_open = 0
nnoremap <silent> <localleader>t :TestNearest<CR>
nnoremap <silent> <localleader>T :TestFile<CR>
nnoremap <silent> <localleader>a :TestSuite<CR>
nnoremap <silent> <localleader>l :TestLast<CR>
nnoremap <silent> <localleader>g :TestVisit<CR>

" use neoterm
tnoremap <C-h> <C-\><C-n><C-w>h
tnoremap <C-j> <C-\><C-n><C-w>j
tnoremap <C-k> <C-\><C-n><C-w>k
tnoremap <C-l> <C-\><C-n><C-w>l

" git (reusing the prezto aliases)
nnoremap <leader>gws :Telescope git_status<CR>
nnoremap <leader>gwd :LazyGit<CR>
nnoremap <leader>gb :GitBlameToggle<CR>
nnoremap <leader>gl :LazyGitFilter<CR>
" open PRs
nnoremap <localleader>gp :Octo pr create<CR>

" preview markdown with livedown
augroup livedown
  autocmd BufRead,BufNewFile *.md nnoremap <localleader>ll :LivedownToggle<CR>
augroup end

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
nnoremap <leader>a :Telescope live_grep<CR>
nnoremap <leader>t :Telescope git_files<CR>
nnoremap <leader>s :Telescope grep_string<CR>
nnoremap <leader>c :Telescope command_history<CR>
nnoremap <leader>q :Telescope quickfix<CR>
nnoremap <leader>w :Telescope loclist<CR>
nnoremap <leader>tms :Telescope tmux sessions<CR>
nnoremap <leader>tmw :Telescope tmux windows<CR>
nnoremap <leader>ts :Telescope treesitter<CR>
nnoremap <leader>p :Telescope resume<CR>
" outline
nnoremap <silent> <localleader>o :SymbolsOutline<CR>

" trouble
nnoremap <leader>xx <cmd>TroubleToggle<cr>
nnoremap <leader>xw <cmd>TroubleToggle workspace_diagnostics<cr>
nnoremap <leader>xd <cmd>TroubleToggle document_diagnostics<cr>
nnoremap <leader>xq <cmd>TroubleToggle quickfix<cr>
nnoremap <leader>xl <cmd>TroubleToggle loclist<cr>
nnoremap gR <cmd>TroubleToggle lsp_references<cr>
nnoremap <leader>xt <cmd>TodoTrouble<cr>
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
" clear the highlight from the last search
nnoremap <Esc><Esc> :noh<CR><Esc>
