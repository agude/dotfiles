" Autoinstall install Plug.vim if doesn't exist
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif


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
if !has("patch-8.1.0360")
    Plug 'chrisbra/vim-diff-enhanced'
endif
" PEP8 compliant indenting
Plug 'Vimjas/vim-python-pep8-indent'
" Jekyll Liquid syntax
Plug 'tpope/vim-liquid'
" Conky Syntax
Plug 'smancill/conky-syntax.vim'
" Mediawiki Syntax
Plug 'chikamichi/mediawiki.vim'
" Rust
Plug 'rust-lang/rust.vim'

" Neovim only
if has('nvim')
    " Autocomplete
    function! DoRemote(arg)
        UpdateRemotePlugins
    endfunction
    Plug 'Shougo/deoplete.nvim', { 'do': function('DoRemote') }
    " Jedi autocomplete for Python
    Plug 'zchee/deoplete-jedi'
    " Asynchronous linting
    Plug 'dense-analysis/ale'
endif

call plug#end()
