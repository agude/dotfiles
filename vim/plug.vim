call plug#begin('~/.vim/plugged')

"My color scheme
Plug 'agude/vim-eldar'
"VimCompletesMe
Plug 'ajh17/VimCompletesMe'
"Surround
Plug 'tpope/vim-surround'
"Repeat (lets you use . with surround)
Plug 'tpope/vim-repeat'
"Tagbar
Plug 'majutsushi/tagbar'
"ctrlp
Plug 'ctrlpvim/ctrlp.vim'
"Python Syntax Highlighting
Plug 'hdima/python-syntax'
"Git support
Plug 'tpope/vim-fugitive'
" Better Diffing using git 1.8
Plug 'chrisbra/vim-diff-enhanced'
" PEP8 compliant indenting
Plug 'Vimjas/vim-python-pep8-indent'
" Jekyll Liquid syntax
Plug 'tpope/vim-liquid'

" Neovim only

if has("nvim")
    " Autocomplete
    function! DoRemote(arg)
        UpdateRemotePlugins
    endfunction
    Plug 'Shougo/deoplete.nvim', { 'do': function('DoRemote') }
    " Jedi autocomplete
    Plug 'zchee/deoplete-jedi'
endif

call plug#end()
