" enable syntax highlighting
syntax enable

" Plugins
let mapleader=','

" configure plug
call plug#begin('~/.vim/plugged')
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
Plug 'zweifisch/pipe2eval'
Plug 'wincent/ferret'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
" vim-snippets depends on ultisnips
Plug 'sirver/ultisnips' | Plug 'honza/vim-snippets'
Plug 'scrooloose/syntastic'
Plug 'vim-scripts/SyntaxRange'
" language syntax
Plug 'kylef/apiblueprint.vim'
Plug 'rust-lang/rust.vim'
Plug 'kchmck/vim-coffee-script'
" don't forget to `npm i -g livedown`
Plug 'shime/vim-livedown', { 'for': ['markdown'] }
Plug 'bkad/CamelCaseMotion'
Plug 'michaeljsmith/vim-indent-object'
Plug 'tpope/vim-commentary'
Plug 'neilagabriel/vim-geeknote'
Plug 'lervag/vimtex'
Plug 'radenling/vim-dispatch-neovim'
Plug 'tpope/vim-dispatch'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-unimpaired'
Plug 'tpope/vim-speeddating'
Plug 'tpope/vim-repeat'
call plug#end()

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
" do not change to the file dir on vim-startify
let g:startify_change_to_dir=0
" refer to files from the vcs root
let g:startify_change_to_vcs_root=1

" Indenting
set autoindent
" how many columns text is indented with the reindent operations
set shiftwidth=2
" expand tabs to spaces
set expandtab
" insert mode tab and backspace use 2 spaces
set softtabstop=2
" how much actual tabs occupy
set tabstop=2
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

" enable hard mode on all buffers
let g:hardtime_default_on = 1

" Spelling
" check spelling on markdown
autocmd BufRead,BufNewFile *.md set filetype=markdown
autocmd BufRead,BufNewFile *.md set spell
" check spelling on LaTex
autocmd BufRead,BufNewFile *.tex set spell
" check spelling on git commits
autocmd BufRead,BufNewFile COMMIT_EDITMSG set spell
" http://vi.stackexchange.com/questions/68/autocorrect-spelling-mistakes
" go back to last misspelled word and pick first suggestion
" this corresponds to <A-l>
nnoremap ¬ <C-g>u<Esc>[s1z=`]a<C-g>u
" select last misspelled word (typing will edit)
" this corresponds to <A-k>
nnoremap ˚ <Esc>[sve<C-g>

" Syntax
" snippets
autocmd FileType javascript UltiSnipsAddFiletypes javascript-es6
autocmd FileType javascript UltiSnipsAddFiletypes javascript-jasmine

" recommended Syntastic settings
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*
" let syntastic use loclists (vim-unimpaired ]l [l)
let g:syntastic_always_populate_loc_list=1
let g:syntastic_auto_loc_list=0
let g:syntastic_check_on_open=1
let g:syntastic_check_on_wq=0
" don't forget to `npm i -g eslint`
let g:syntastic_javascript_checkers=['eslint']

" reload nvimrc
noremap <silent> <leader>V :source ~/.nvimrc<CR>:filetype detect<CR>:exe ":echo 'vimrc reloaded'"<CR>

" set the status line
" component_visible_condition - so that fugitive's arrow doesn't appear all the time
let g:lightline = {
      \ 'colorscheme': 'solarized',
      \ 'active': {
      \ 'left': [ ['mode', 'paste'],
      \ [ 'fugitive', 'readonly', 'filename', 'modified' ] ]
      \ },
      \ 'component_function': {
      \   'fugitive': 'MyFugitive'
      \ },
      \ 'separator': { 'left': '⮀', 'right': '⮂' },
      \ 'subseparator': { 'left': '⮁', 'right': '⮃'  }
      \ }
function! MyFugitive()
  if exists('*fugitive#head')
    let _ = fugitive#head()
    return strlen(_) ? '⭠ '._ : ''
  endif
  return ''
endfunction
let g:tmuxline_theme = 'lightline'

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

" preview markdown with livedown
autocmd BufRead,BufNewFile *.md nnoremap <localleader>ll :LivedownToggle<CR>

" geeknote
" https://github.com/neilagabriel/vim-geeknote#geeknote-autocommands
autocmd FileType geeknote setlocal nonumber
" http://stackoverflow.com/questions/5017009/confusion-about-vim-folding-how-to-disable
autocmd FileType geeknote setlocal nofoldenable
let g:GeeknoteFormat = 'markdown'
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
" use ag
nnoremap <leader>a :Ack<space>
" use fzf
nnoremap <leader>t :FZF<CR>
