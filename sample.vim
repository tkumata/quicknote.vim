" Quick Note Root Directory, Default is ~/Documents/QuickNote
let g:quicknote_root = '~/Documents/QuickNote'

" Vimwiki
let g:vimwiki_list = [{
  \ 'path': g:quicknote_root . '/',
  \ 'syntax': 'markdown',
  \ 'ext': '.md'
  \}]
let g:vimwiki_key_mappings = { 'all_maps': 0 }

" Copilot model, default is 'gpt-4o-copilot'
let g:copilot_settings = { 'selectedCompletionModel': 'gpt-41-copilot' }

" Plugins
call plug#begin('~/.vim/plugged')
  Plug 'preservim/nerdtree'
  Plug 'vim-airline/vim-airline'
  Plug 'vim-airline/vim-airline-themes'
  Plug 'tpope/vim-commentary'
  Plug 'rust-lang/rust.vim'
  Plug 'pangloss/vim-javascript'
  Plug 'leafgarland/typescript-vim'
  Plug 'plasticboy/vim-markdown'
  Plug 'tpope/vim-fugitive'
  Plug 'vimwiki/vimwiki'
  Plug 'junegunn/fzf'
  Plug 'junegunn/fzf.vim'
  Plug 'rbtnn/vim-ambiwidth'
  Plug 'joshdick/onedark.vim'
  Plug 'tkumata/quicknote.vim'
call plug#end()

" Basic settings
set cursorline
set number
set showmatch
set history=50
set showcmd
set backspace=indent,eol,start
set termencoding=utf-8
set fileformats=unix,dos,mac
set smartcase
syntax on

" Define <Leader>, Default is backslash (\)
let mapleader = " "

" Color scheme
set t_Co=256
set termguicolors
set background=light
colorscheme onedark

" Visual mode
set mouse=a
if has('win32') || has('win64')
  set clipboard=unnamed
elseif has('macunix')
  set clipboard+=unnamed
else
  set clipboard=unnamedplus
endif

" Mouse works when Alacritty
if $TERM ==# 'alacritty'
  set ttymouse=sgr
endif

" Disable folding
set nofoldenable
set foldmethod=manual

" Status line
set laststatus=2
set ruler

" Tab settings
set expandtab
set tabstop=4
set shiftwidth=4

" Completion
set wildmenu
set wildmode=list:longest,full

" Search settings
set incsearch
set hlsearch

" Ambiguous width
if exists('&ambiwidth')
  set ambiwidth=single
endif

" OneDark
let g:onedark_termcolors = 256

" Ambiwidth
let g:ambiwidth_cica_enabled = v:false

" AirLine
let g:airline_powerline_fonts = 1
let g:airline_theme = 'light'

" lightline
let g:lightline = { 'colorscheme': 'light', }

" Restore the last cursor position when reopening a file.
augroup private_restore_cursor
  autocmd!
  autocmd BufReadPost *
    \ if line("'\"") > 1 && line("'\"") <= line('$') |
    \   execute "normal! g`\"" |
    \ endif
augroup END

" Open NERDTree on startup when Vim starts without a file argument.
autocmd StdinReadPre * let s:std_in = 1
function! s:open_nerdtree_root_children() abort
  let l:tree = g:NERDTree.ForCurrentTab()

  for l:node in l:tree.root.children
    if l:node.path.isDirectory
      call l:node.open()
    endif
  endfor

  call l:tree.render()
endfunction
autocmd VimEnter * if argc() == 0 && !exists('s:std_in') |
  \ NERDTree |
  \ call s:open_nerdtree_root_children() |
  \ endif

" Key maps
nnoremap j gj
nnoremap gj j
nnoremap k gk
nnoremap gk k
nnoremap <Leader>n :NERDTreeToggle<CR>
nnoremap <Leader>e <C-w>p
nnoremap <Leader>w :w<CR>
nnoremap <Leader>q :q<CR>
nnoremap <Leader>gs :G<CR>
nnoremap <Leader>gd :Gdiffsplit<CR>
nnoremap <Leader>gb :Gblame<CR>
nnoremap <Leader>gc :Gcommit<CR>
nnoremap <Leader>gp :Gpush<CR>
