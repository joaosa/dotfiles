scriptencoding utf8

" Plugins
let mapleader=','

let g:python2_host = $HOME . '/.pyenv/versions/neovim-python2/bin'
let g:python3_host = $HOME . '/.pyenv/versions/neovim-python3/bin'

" configure plug
call plug#begin('~/.config/nvim/plugged')
Plug 'gruvbox-community/gruvbox'
Plug 'Valloric/ListToggle'
Plug 'itchyny/lightline.vim'
Plug 'edkolev/tmuxline.vim'
Plug 'kassio/neoterm'
Plug 'tpope/vim-obsession'
Plug 'junegunn/goyo.vim'
Plug 'junegunn/limelight.vim'
Plug 'mhinz/vim-startify'
Plug 'szw/vim-g'
Plug 'christoomey/vim-tmux-navigator'
Plug 'airblade/vim-gitgutter'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'takac/vim-hardtime'
Plug 'jeffkreeftmeijer/vim-numbertoggle'
Plug 'jiangmiao/auto-pairs'
Plug 'wincent/ferret'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
" vim-snippets depends on ultisnips
Plug 'sirver/ultisnips' | Plug 'honza/vim-snippets'
Plug 'dense-analysis/ale'
Plug 'vim-scripts/SyntaxRange'
" lsp
Plug 'williamboman/mason.nvim'
Plug 'williamboman/mason-lspconfig.nvim'
Plug 'neovim/nvim-lspconfig'
" autocomplete
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/nvim-cmp'
" language syntax
Plug 'dbeniamine/cheat.sh-vim'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'ivy/vim-ginkgo'
Plug 'shime/vim-livedown', { 'do': 'npm install -g livedown' , 'for': ['markdown', 'apiblueprint'] }
Plug 'ludovicchabant/vim-gutentags', { 'do': 'brew install --HEAD universal-ctags/universal-ctags/universal-ctags' }
Plug 'majutsushi/tagbar'
Plug 'lvht/tagbar-markdown'
Plug 'bkad/CamelCaseMotion'
Plug 'unblevable/quick-scope'
Plug 'wellle/targets.vim'
Plug 'tpope/vim-commentary'
Plug 'lervag/vimtex'
Plug 'tpope/vim-dispatch'
Plug 'janko-m/vim-test'
Plug 'ciaranm/detectindent'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-rhubarb'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-speeddating'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-dadbod'
" has to be the last one
Plug 'ryanoasis/vim-devicons'
call plug#end()

" neovim python
let g:python_host_prog = g:python2_host . '/python'
let g:python3_host_prog = g:python3_host . '/python'

" setup netrw
" ref - https://shapeshed.com/vim-netrw/
let g:netrw_banner = 0
" let g:netrw_liststyle = 3
let g:netrw_winsize = 25
nnoremap <leader>d :Lexplore<CR>

" let's not conflict with ferret
let g:lt_location_list_toggle_map = '<leader>w'

" gutentags
let g:gutentags_file_list_command = 'rg --files'
" Fix it when using git
" ref - https://github.com/ludovicchabant/vim-gutentags/issues/178#issuecomment-547475742
let g:gutentags_exclude_filetypes = [
  \'go',
  \'ginkgo.go',
  \'gitcommit',
  \'gitconfig',
  \'gitrebase',
  \'gitsendemail',
  \'git',
  \'diff',
  \]
let g:gutentags_ctags_exclude = [
  \'.git',
\]

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
" color scheme
set termguicolors
let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
colorscheme gruvbox
" https://github.com/gruvbox-community/gruvbox/wiki/Configuration#ggruvbox_contrast_dark
let g:gruvbox_contrast_dark='hard'

" rainbow parenthesis
let g:rainbow_active=1
" do not refer to files from the vcs root
" this would make gutentags try to build a way too big file
" in certain multi-language projects
" it also helps with vim-test
let g:startify_change_to_vcs_root = 0
" do not change to file dir
let g:startify_change_to_dir = 0

" Indenting
set autoindent
" we're leaving tab expansion (expandtab), tab size for insert mode (softtabstop),
" how many columns text is indented with the reindent operation (shiftwidth)
" and how much space actual tabs occupy to detectindent.
augroup indentation
  autocmd BufReadPost * :DetectIndent
augroup end
let g:detectindent_preferred_expandtab = 1
let g:detectindent_preferred_indent = 2
" use vim indent guides
let g:indent_guides_enable_on_vim_startup=1

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

" fix transparency with Alacritty
" ref - https://github.com/alacritty/alacritty/issues/1082#issuecomment-366857468
" needs to be added after enabling syntax
hi Normal ctermbg=NONE guibg=NONE guifg=NONE ctermfg=NONE

set completeopt=menu,menuone,noselect

lua <<EOF
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
    },

    sync_install = false,
    -- Automatically install missing parsers when entering buffer
    -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
    auto_install = true,
  }

  local ft_to_parser = require"nvim-treesitter.parsers".filetype_to_parsername
  ft_to_parser.terrafrom = "hcl"
  ft_to_parser["terraform-vars"] = "hcl"

  require("mason").setup()
  require("mason-lspconfig").setup({
    ensure_installed = {
      "sumneko_lua",
      "gopls",
      "rust_analyzer",
      "terraformls",
      "pyright",
      "tsserver",
      "yamlls",
      "vimls",
      "ansiblels",
      "bashls",
      "sqlls",
    }
  })

  local cmp = require'cmp'

  cmp.setup({
    snippet = {
      -- REQUIRED - you must specify a snippet engine
      expand = function(args)
        vim.fn["UltiSnips#Anon"](args.body) -- For `ultisnips` users.
      end,
    },
    window = {
      -- completion = cmp.config.window.bordered(),
      -- documentation = cmp.config.window.bordered(),
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
      { name = 'ultisnips' }, -- For ultisnips users.
      }, {
        { name = 'buffer' },
      })
  })

  local capabilities = require('cmp_nvim_lsp').default_capabilities()
  require("lspconfig").rust_analyzer.setup {
    capabilities = capabilities
  }
  require("lspconfig").gopls.setup {
    capabilities = capabilities
  }
  require("lspconfig").sumneko_lua.setup {
    diagnostics = { globals = { "hs" } },
    capabilities = capabilities
  }
  require("lspconfig").terraformls.setup {
    capabilities = capabilities
  }
  require("lspconfig").pyright.setup {
    capabilities = capabilities
  }
  require("lspconfig").tsserver.setup {
    capabilities = capabilities
  }
  require("lspconfig").yamlls.setup {
    capabilities = capabilities
  }
  require("lspconfig").vimls.setup {
    capabilities = capabilities
  }
  require("lspconfig").ansiblels.setup {
    capabilities = capabilities
  }
  require("lspconfig").bashls.setup {
    capabilities = capabilities
  }
  require("lspconfig").sqlls.setup {
    capabilities = capabilities
  }
EOF

" snippets
augroup snippets
  autocmd FileType javascript UltiSnipsAddFiletypes javascript-jasmine-arrow
augroup end

" linting
let g:ale_fix_on_save = 1
let g:ale_fixers = {
  \'*': ['remove_trailing_lines', 'trim_whitespace'],
  \'sql': ['pgformatter'],
  \'javascript': ['eslint'],
  \'typescript': ['tslint'],
  \'go': ['gofmt', 'goimports'],
  \'rust': ['rustfmt'],
  \'puppet': ['puppetlint'],
\}

" set the status line
" component_visible_condition - so that fugitive's arrow doesn't appear all the time
let g:lightline = {
  \'colorscheme': 'gruvbox',
  \'active': {
    \'left': [
      \['mode', 'paste'],
      \['fugitive', 'readonly', 'filename', 'modified', 'session'],
    \],
  \},
  \'component_function': {
    \'session': 'ObsessionStatus',
    \'filename': 'LightlineFilename',
    \'fugitive': 'MyFugitive',
    \'filetype': 'MyFiletype',
    \'fileformat': 'MyFileformat',
  \},
  \'separator': { 'left': '', 'right': '' },
  \'subseparator': { 'left': '', 'right': '' },
\}

" ref - https://github.com/itchyny/lightline.vim/issues/293#issuecomment-373710096
function! LightlineFilename()
  let root = fnamemodify(get(b:, 'git_dir'), ':h')
  let path = expand('%:p')
  if path[:len(root)-1] ==# root
    return path[len(root)+1:]
  endif
  return expand('%')
endfunction

function! MyFugitive()
  if exists('*fugitive#head')
    let _ = fugitive#head()
    return strlen(_) ? ' '. _ : ''
  endif
  return ''
endfunction

function! MyFiletype()
  return winwidth(0) > 70 ? (strlen(&filetype) ? &filetype . ' ' . WebDevIconsGetFileTypeSymbol() : 'no ft') : ''
endfunction

function! MyFileformat()
  return winwidth(0) > 70 ? (&fileformat . ' ' . WebDevIconsGetFileFormatSymbol()) : ''
endfunction

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

" use dispatch
nnoremap <leader>dc :Dispatch<Space>
nnoremap <leader>ds :Start<Space>
nnoremap <leader>dm :Make<Space>

" use neoterm
tnoremap <C-h> <C-\><C-n><C-w>h
tnoremap <C-j> <C-\><C-n><C-w>j
tnoremap <C-k> <C-\><C-n><C-w>k
tnoremap <C-l> <C-\><C-n><C-w>l

" git fugitive (reusing the prezto aliases)
nnoremap <leader>gws :Git<CR>
nnoremap <leader>gwd :Git diff<CR>
nnoremap <leader>gco :Git checkout %<CR>
nnoremap <leader>gia :Git add %<CR>
nnoremap <leader>gcm :Git commit<CR>
nnoremap <leader>gfm :exec ':Git pull origin ' . fugitive#head() . ' --rebase --autostash'<CR>
nnoremap <leader>gp :exec ':Git push origin ' . fugitive#head() . ' -u'<CR>
nnoremap <leader>gb :Git blame<CR>
nnoremap <leader>gl :Gclog<CR>
nnoremap <leader>gs :Git stash<CR>
nnoremap <leader>gsp :Git stash pop<CR>
nnoremap <leader>gsd :Git stash drop<CR>
" open PRs inside vim using neoterm
function! OpenPR(base, reviewers)
  let l:reviewers = []
  for r in split(a:reviewers)
    call add(l:reviewers, '-r ' . r)
  endfor

  " can't use -d as not all repos support this
  execute ':T hub pull-request -fp -b ' . a:base . ' ' . join(l:reviewers, ' ')
endfunction
nnoremap <localleader>gp :call OpenPR(input('branch: '), input('reviewers: '))<CR>

" preview markdown with livedown
augroup livedown
  autocmd BufRead,BufNewFile *.md nnoremap <localleader>ll :LivedownToggle<CR>
augroup end

" Search
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
" use fzf
nnoremap <leader>t :FZF<CR>
set grepprg=rg\ --vimgrep
