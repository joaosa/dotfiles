" enable syntax highlighting
syntax enable

" Plugins
let mapleader=','

let g:python2_host = $HOME . '/.pyenv/versions/neovim-python2/bin'
let g:python3_host = $HOME . '/.pyenv/versions/neovim-python3/bin'

function! InstallDeopleteDeps(info)
  if a:info.status == 'installed' || a:info.force
    execute "!" . g:python3_host . "/pip install 'msgpack>=1.0.0'"
    :UpdateRemotePlugins
  endif
endfunction

function! InstallAleTools(info)
  if a:info.status == 'installed' || a:info.force
    !npm install -g eslint_d@7 babel-eslint
    !npx install-peerdeps -g eslint-config-airbnb@16.1.0
  endif
endfunction

" configure plug
call plug#begin('~/.config/nvim/plugged')
Plug 'morhetz/gruvbox'
Plug 'Valloric/ListToggle'
Plug 'itchyny/lightline.vim'
Plug 'edkolev/tmuxline.vim'
Plug 'junegunn/goyo.vim'
Plug 'mhinz/vim-startify'
Plug 'szw/vim-g'
Plug 'beloglazov/vim-online-thesaurus'
Plug 'christoomey/vim-tmux-navigator'
Plug 'airblade/vim-gitgutter'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'takac/vim-hardtime'
Plug 'jeffkreeftmeijer/vim-numbertoggle'
Plug 'luochen1990/rainbow', { 'for': ['clojure', 'lisp'] }
Plug 'jiangmiao/auto-pairs'
Plug 'wincent/ferret'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
" vim-snippets depends on ultisnips
Plug 'sirver/ultisnips' | Plug 'honza/vim-snippets'
Plug 'dense-analysis/ale', { 'do': function('InstallAleTools') }
Plug 'vim-scripts/SyntaxRange'
" auto-completion
Plug 'Shougo/deoplete.nvim', { 'do': function('InstallDeopleteDeps') }
Plug 'ternjs/tern_for_vim', { 'do': 'npm install' } | Plug 'carlitux/deoplete-ternjs', { 'do': 'npm install -g tern' }
Plug 'zchee/deoplete-jedi'
Plug 'hashivim/vim-terraform'
Plug 'juliosueiras/vim-terraform-completion'
Plug 'rodjek/vim-puppet', { 'do': 'gem install puppet-lint' }
" fix installing certifi with the python3 host
" Plug 'zchee/deoplete-docker'
Plug 'zchee/deoplete-go', { 'do': 'go get -u github.com/mdempsky/gocode && make'}
" language syntax
Plug 'dbeniamine/cheat.sh-vim'
Plug 'kylef/apiblueprint.vim'
Plug 'elixir-lang/vim-elixir'
Plug 'derekwyatt/vim-scala'
Plug 'fatih/vim-go', { 'do': ':GoUpdateBinaries' }
Plug 'rust-lang/rust.vim'
Plug 'kchmck/vim-coffee-script'
Plug 'leafgarland/typescript-vim'
Plug 'ivy/vim-ginkgo'
Plug 'shime/vim-livedown', { 'do': 'npm install -g livedown' , 'for': ['markdown', 'apiblueprint'] }
Plug 'ludovicchabant/vim-gutentags'
Plug 'ramitos/jsctags'
Plug 'majutsushi/tagbar'
Plug 'lvht/tagbar-markdown'
Plug 'bkad/CamelCaseMotion'
Plug 'wellle/targets.vim'
Plug 'tpope/vim-commentary'
Plug 'neilagabriel/vim-geeknote', { 'do': g:python2_host . '/pip install git+https://github.com/jeffkowalski/geeknote' }
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
let g:python_host_prog = $HOME . '/.pyenv/versions/neovim-python2/bin/python'
let g:python3_host_prog = g:python3_host . '/python'

" setup netrw
" ref - https://shapeshed.com/vim-netrw/
let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_winsize = 25
nnoremap <leader>d :Lexplore<CR>

" let's not conflict with ferret
let g:lt_location_list_toggle_map = '<leader>w'

" Fix gutentags when committing
" https://github.com/ludovicchabant/vim-gutentags/issues/168
autocmd BufRead,BufNewFile PULLREQ_EDITMSG let g:gutentags_enabled=0
let g:gutentags_exclude_filetypes = ['gitcommit', 'gitrebase', 'diff']

" yank and paste with the system clipboard
set clipboard=unnamed
" do not confuse crontab. see :help crontab
set backupcopy=yes
" do not store swap files on the current dir (remove .)
set directory-=.

" Display
" show trailing whitespace
set list
set listchars=tab:▸\ ,trail:▫
" show line numbers
set number
" show where you are
set ruler
" show typed commands
set showcmd
" color theme
set termguicolors
let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
let &t_8b = "\<Esc>[48;2;%lu;%lu;%lum"
colorscheme gruvbox
" have transparent background (if needed)
" highlight Normal ctermbg=none
" rainbow parenthesis
let g:rainbow_active=1
" refer to files from the vcs root
let g:startify_change_to_vcs_root=1

" Indenting
set autoindent
" we're leaving tab expansion (expandtab), tab size for insert mode (softtabstop),
" how many columns text is indented with the reindent operation (shiftwidth)
" and how much space actual tabs occupy to detectindent.
autocmd BufReadPost * :DetectIndent
let g:detectindent_preferred_expandtab = 1
let g:detectindent_preferred_indent = 2
" clear trailing whitespace
nnoremap <leader><space> :%s/\s\+$//<CR>
" use vim indent guides
let g:indent_guides_enable_on_vim_startup=1
" indent SQL
set formatprg=~/Repos/pgFormatter/pg_format\ -s\ 2\ -p\ '(\\$\|{\|})'\ -

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
" check spelling on markdown
autocmd BufRead,BufNewFile *.md set filetype=markdown
autocmd BufRead,BufNewFile *.md set spell
autocmd FileType vim set spell
" check spelling on LaTex
autocmd BufRead,BufNewFile *.tex set spell
" check spelling on git commits
autocmd BufRead,BufNewFile PULLREQ_EDITMSG,COMMIT_EDITMSG, set spell
" http://vi.stackexchange.com/questions/68/autocorrect-spelling-mistakes
" go back to last misspelled word and pick first suggestion
" this corresponds to <A-l>
nnoremap ¬ <C-g>u<Esc>[s1z=`]a<C-g>u
" select last misspelled word (typing will edit)
" this corresponds to <A-k>
nnoremap ˚ <Esc>[sve<C-g>

" Syntax
" deoplete
let g:deoplete#enable_at_startup = 1
let g:deoplete#sources = {}
let g:deoplete#keyword_patterns = {}
let g:deoplete#omni#input_patterns = {}

let g:deoplete#sources['javascript'] = ['file', 'ultisnips', 'ternjs']
" tern_for_vim.
let g:tern#command = ["tern"]
let g:tern#arguments = ["--persistent"]
" terraform
call deoplete#custom#option('omni_patterns', {
\ 'complete_method': 'omnifunc',
\})
let g:terraform_fmt_on_save=1
call deoplete#initialize()

" snippets
autocmd FileType javascript UltiSnipsAddFiletypes javascript-jasmine-arrow

" checking
let g:ale_javascript_eslint_use_global = 1
let g:ale_javascript_eslint_executable = 'eslint_d'
let g:ale_linters = {
      \'javascript': ['eslint'],
      \'typescript': ['tslint', 'tsserver'],
      \'go': ['gometalinter'],
      \'puppet': ['puppetlint'],
      \}
let g:ale_go_gometalinter_options = '
      \ --aggregate
      \ --fast
      \ --sort=line
      \ --tests
      \ '
let g:ale_fix_on_save = 1
let g:ale_fixers = {
  \'javascript': ['eslint'],
  \'go': ['gofmt', 'goimports'],
  \'puppet': ['puppetlint'],
\}

" set the status line
" component_visible_condition - so that fugitive's arrow doesn't appear all the time
let g:lightline = {
  \'colorscheme': 'gruvbox',
  \'active': {
  \'left': [
    \['mode', 'paste'],
    \['fugitive', 'readonly', 'filename', 'modified'],
  \]
  \},
  \'component_function': {
    \'filename': 'LightlineFilename',
    \'fugitive': 'MyFugitive',
    \'filetype': 'MyFiletype',
    \'fileformat': 'MyFileformat',
  \},
  \'separator': { 'left': '', 'right': '' },
  \'subseparator': { 'left': '', 'right': '' },
\}

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

" ref - https://github.com/itchyny/lightline.vim/issues/293#issuecomment-373710096
function! LightlineFilename()
  let root = fnamemodify(get(b:, 'git_dir'), ':h')
  let path = expand('%:p')
  if path[:len(root)-1] ==# root
    return path[len(root)+1:]
  endif
  return expand('%')
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
    \'#[bold]#(rainbarf --tmux --battery --remaining --width 20)'
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
let g:tmuxline_theme = 'lightline'

" reload nvimrc
noremap <silent> <leader>V :source ~/.config/nvim/init.vim<CR>:filetype detect<CR>:exe ":echo 'vimrc reloaded'"<CR>

" vim test
" ref - https://github.com/janko/vim-test#strategies
let test#strategy = 'neovim'
nmap <silent> <localleader>t :TestNearest<CR>
nmap <silent> <localleader>T :TestFile<CR>
nmap <silent> <localleader>a :TestSuite<CR>
nmap <silent> <localleader>l :TestLast<CR>
nmap <silent> <localleader>g :TestVisit<CR>

" use dispatch
nnoremap <leader>dc :Dispatch<Space>
nnoremap <leader>ds :Start<Space>
nnoremap <leader>dm :Make<Space>

" git fugitive (reusing the prezto aliases)
nnoremap <leader>gws :Gstatus<CR>
nnoremap <leader>gwd :Gdiff<CR>
nnoremap <leader>gco :Gread<CR>
nnoremap <leader>gia :Gwrite<CR>
nnoremap <leader>gcm :Gcommit<CR>
nnoremap <leader>gfm :exec ':Gpull origin ' . fugitive#head() . ' --rebase --autostash'<CR>
nnoremap <leader>gp :exec ':Gpush origin ' . fugitive#head() . ' -u'<CR>
nnoremap <leader>gb :Gblame<CR>
nnoremap <leader>gl :Glog<CR>
nnoremap <leader>gs :Git Stash<CR>
nnoremap <leader>gsp :Git Stash pop<CR>
nnoremap <leader>gsd :Git Stash drop<CR>

" preview markdown with livedown
autocmd BufRead,BufNewFile *.md nnoremap <localleader>ll :LivedownToggle<CR>

" geeknote
" https://github.com/neilagabriel/vim-geeknote#geeknote-autocommands
autocmd FileType geeknote setlocal nonumber
" http://stackoverflow.com/questions/5017009/confusion-about-vim-folding-how-to-disable
autocmd FileType geeknote setlocal nofoldenable
let g:GeeknoteFormat="plain"
nnoremap <leader>ed :Geeknote<CR>
nnoremap <leader>ew :GeeknoteSaveAsNote<CR>
nnoremap <leader>en :GeeknoteCreateNote<Space>
nnoremap <leader>e/ :GeeknoteSearch<Space>
nnoremap <leader>es :GeeknoteSync<CR>
let g:GeeknoteNotebooks =
      \    [
      \        '25162dcc-daf1-40b0-9255-8f8342db5e2b'
      \    ]

" Search
" search for stuff on the internet
let g:vim_g_command="Go"
" stuff + filetype
let g:vim_g_f_command="Gf"
let g:vim_g_query_url="https://duckduckgo.com/?q="
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
