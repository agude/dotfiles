call plug#begin('~/.vim/plugged')

"My color scheme
Plug 'agude/vim-eldar'
"VimCompletesMe
Plug 'ajh17/VimCompletesMe'
"Surround
Plug 'machakann/vim-sandwich'
"Repeat (lets you use . with surround)
Plug 'tpope/vim-repeat'
"Tagbar
Plug 'majutsushi/tagbar'
"ctrlp
Plug 'ctrlpvim/ctrlp.vim'
"Python Syntax Highlighting
Plug 'vim-python/python-syntax'
"Git support
Plug 'tpope/vim-fugitive'
" Better Diffing using git 1.8
Plug 'chrisbra/vim-diff-enhanced'
" PEP8 compliant indenting
Plug 'Vimjas/vim-python-pep8-indent'
" Jekyll Liquid syntax
Plug 'tpope/vim-liquid'
" Conky Syntax
Plug 'smancill/conky-syntax.vim'
" Mediawiki Syntax
Plug 'chikamichi/mediawiki.vim'

" Neovim only
if has("nvim")
    " Autocomplete
    function! DoRemote(arg)
        UpdateRemotePlugins
    endfunction
    Plug 'Shougo/deoplete.nvim', { 'do': function('DoRemote') }
    " Jedi autocomplete for Python
    Plug 'zchee/deoplete-jedi'
    " Asynchronous linting
    Plug 'w0rp/ale'
endif

call plug#end()
