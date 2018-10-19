" enable syntax highlighting
syntax enable

" Plugins
let mapleader=','

let g:python3_host = $HOME . '/.pyenv/versions/neovim-python3/bin'

" configure plug
call plug#begin('~/.config/nvim/plugged')
Plug 'altercation/vim-colors-solarized'
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
Plug 'luochen1990/rainbow', { 'for': ['clojure', 'lisp'] }
Plug 'jiangmiao/auto-pairs'
Plug 'wincent/ferret'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
" vim-snippets depends on ultisnips
Plug 'sirver/ultisnips' | Plug 'honza/vim-snippets'
Plug 'w0rp/ale', { 'do': 'npm install -g eslint_d babel-eslint && npx install-peerdeps -g eslint-config-airbnb@16.1.0' }
Plug 'vim-scripts/SyntaxRange'
" autocompletion
Plug 'Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'ternjs/tern_for_vim', { 'do': 'npm install' } | Plug 'carlitux/deoplete-ternjs', { 'do': 'npm install -g tern' }
Plug 'zchee/deoplete-jedi'
" fix installing certifi with the python3 host
Plug 'zchee/deoplete-docker', { 'do': g:python3_host . '/pip install certifi' }
" language syntax
Plug 'kylef/apiblueprint.vim'
Plug 'elixir-lang/vim-elixir'
Plug 'derekwyatt/vim-scala'
Plug 'rust-lang/rust.vim'
Plug 'kchmck/vim-coffee-script'
Plug 'leafgarland/typescript-vim'
Plug 'shime/vim-livedown', { 'do': 'npm install -g livedown' , 'for': ['markdown', 'apiblueprint'] }
Plug 'ludovicchabant/vim-gutentags'
Plug 'ramitos/jsctags'
Plug 'majutsushi/tagbar'
Plug 'lvht/tagbar-markdown'
Plug 'bkad/CamelCaseMotion'
Plug 'tpope/vim-commentary'
Plug 'neilagabriel/vim-geeknote'
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

" Fix gutentags when committing
" https://github.com/ludovicchabant/vim-gutentags/issues/168
autocmd BufRead,BufNewFile PULLREQ_EDITMSG let g:gutentags_enabled=0
autocmd FileType gitcommit,diff let g:gutentags_enabled=0

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
" enable vim hybrid mode
set relativenumber
" show where you are
set ruler
" show typed commands
set showcmd
" set colorscheme
set background=dark
colorscheme solarized
" have transparent background (if needed)
highlight Normal ctermbg=none
" rainbow paranthesis
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
" fix the colors on 256 colors terminals
let g:indent_guides_auto_colors=0
highlight IndentGuidesOdd ctermbg=234
highlight IndentGuidesEven ctermbg=235
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
" Use deoplete.
let g:deoplete#enable_at_startup = 1
let g:deoplete#sources = {}
let g:deoplete#keyword_patterns = {}
let g:deoplete#omni#input_patterns = {}

let g:deoplete#sources['javascript'] = ['file', 'ultisnips', 'ternjs']
" Use tern_for_vim.
let g:tern#command = ["tern"]
let g:tern#arguments = ["--persistent"]

" snippets
autocmd FileType javascript UltiSnipsAddFiletypes javascript-es6
autocmd FileType javascript UltiSnipsAddFiletypes javascript-jasmine

" checking
let g:ale_javascript_eslint_use_global = 1
let g:ale_javascript_eslint_executable = 'eslint_d'
let g:ale_linters = {
      \'javascript': ['eslint'],
      \'typescript': ['tslint', 'tsserver'],
      \}
" reload nvimrc
noremap <silent> <leader>V :source ~/.config/nvim/init.vim<CR>:filetype detect<CR>:exe ":echo 'vimrc reloaded'"<CR>

" set the status line
" component_visible_condition - so that fugitive's arrow doesn't appear all the time
let g:lightline = {
      \ 'colorscheme': 'solarized',
      \ 'active': {
      \ 'left': [ ['mode', 'paste'],
      \ [ 'fugitive', 'readonly', 'filename', 'modified' ] ]
      \ },
      \ 'component_function': {
      \   'filename': 'LightlineFilename',
      \   'fugitive': 'MyFugitive',
      \   'filetype': 'MyFiletype',
      \   'fileformat': 'MyFileformat'
      \ },
      \ 'separator': { 'left': '', 'right': '' },
      \ 'subseparator': { 'left': '', 'right': '' }
      \ }
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
" https://github.com/itchyny/lightline.vim/issues/293#issuecomment-373710096
function! LightlineFilename()
  let root = fnamemodify(get(b:, 'git_dir'), ':h')
  let path = expand('%:p')
  if path[:len(root)-1] ==# root
    return path[len(root)+1:]
  endif
  return expand('%')
endfunction
let g:tmuxline_theme = 'lightline'

" vim test
let test#strategy = 'dispatch'
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
nnoremap <leader>gfm :exec ':Gpull origin ' . fugitive#head()<CR>
nnoremap <leader>gp :exec ':Gpush origin ' . fugitive#head() . ' -u'<CR>
nnoremap <leader>gb :Gblame<CR>
" have fugitive status patch y/n work normally
augroup nvim_term
  au!
  au TermOpen * startinsert
  au TermClose * stopinsert
augroup END

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
