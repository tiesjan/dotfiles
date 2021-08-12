""" Plug
"install Plug if not found
if empty(glob('~/.vim/autoload/plug.vim'))
  silent execute '!curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/plugged')
    Plug 'airblade/vim-gitgutter'
    Plug 'cormacrelf/vim-colors-github'
    Plug 'dense-analysis/ale'
    Plug 'diepm/vim-rest-console', {'for': 'rest'}
    Plug 'itchyny/lightline.vim'
    Plug 'jeffkreeftmeijer/vim-dim'
    Plug 'preservim/nerdtree', {'on': 'NERDTree'}
    Plug 'ycm-core/YouCompleteMe', {'do': './install.py'}
call plug#end()


""" Autocommands
augroup Autocommands
    autocmd!

    "color scheme overrides
    autocmd ColorScheme github highlight! link EndOfBuffer Normal

    "hide signcolumn for NERDTree
    autocmd FileType nerdtree setlocal signcolumn=no

    "override filetype based on file names
    autocmd BufRead,BufNewFile Vagrantfile set filetype=ruby

    if (&diff)
        "switch to merge view on startup if one or more views have been opened
        autocmd VimEnter * if argc() > 0 | wincmd j | endif
    else
        "open NERDTree on startup and switch cursor to buffer on the right
        "if one or more files have been opened
        autocmd VimEnter * NERDTree
        autocmd VimEnter * if argc() > 0 | wincmd l | endif

        "workaround for Lightline not updating after executing `wincmd l` above
        if !has('patch-8.2.2596')
            autocmd VimEnter * call lightline#update()
        endif
    endif
augroup END


""" General settings
colorscheme github
set autochdir
set autoindent
set background=dark
set clipboard^=unnamedplus
set colorcolumn=+1
set completeopt=menu
set cursorline
set encoding=utf-8
set expandtab shiftwidth=4 softtabstop=4 tabstop=4
set formatoptions+=j
set hlsearch ignorecase incsearch smartcase
set laststatus=2 noshowmode
set list listchars=tab:›⋅,trail:⋅,nbsp:~
set mouse=a
set number
set scrolloff=4
set signcolumn=yes
set termguicolors
set textwidth=79
set ttimeoutlen=10
set ttyfast
set updatetime=500


""" Key mapping
let mapleader = ','
"remove trailing whitespace
nnoremap <leader>rtw :%s/\s\+$//e<CR>


""" Plugin - ALE
let g:ale_python_flake8_options = '--ignore=E12,E13,E24,E501,W503,W504'
let g:ale_python_flake8_use_global = 1


""" Plugin - GitGutter
let g:gitgutter_sign_added = "\u25B6"
let g:gitgutter_sign_modified = "\u25C6"
let g:gitgutter_sign_modified_removed = "\u25C6"
let g:gitgutter_sign_removed = "\u2581"
let g:gitgutter_sign_removed_first_line = "\u2580"


""" Plugins - Lightline
let g:lightline = {'colorscheme': 'github'}


""" Plugins - NERDTree
let g:NERDTreeDirArrowExpandable = "\u002B"
let g:NERDTreeDirArrowCollapsible = "\u2212"
let g:NERDTreeIgnore = ['^__pycache__$', '^node_modules$', '\.orig$', '\.pyc$', '\.sw[op]$']
let g:NERDTreeMinimalMenu = 1
let g:NERDTreeWinSize = 35


""" Plugins - Vim REST Console
let g:vrc_curl_opts = {'--include': '', '--silent': ''}
let g:vrc_header_content_type = 'application/json; charset=utf-8'


""" Plugins - YouCompleteMe
let g:ycm_complete_in_comments = 1
let g:ycm_auto_hover = ''
